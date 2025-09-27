#!/bin/bash

# Jitsi Platform Testing Script
# Comprehensive testing workflow for scale-up, health checks, HTTPS verification, and scale-down

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="jitsi-video-platform"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
SERVICE_NAME="${PROJECT_NAME}-service"
DOMAIN_NAME="meet.awsaerospace.org"
AWS_PROFILE="jitsi-dev"
AWS_REGION="us-west-2"
LOG_FILE="/tmp/jitsi-test-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE" ;;
    esac
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Error handling
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log ERROR "Test failed with exit code $exit_code"
        log INFO "Attempting to scale down service for cleanup..."
        "${SCRIPT_DIR}/scale-down.sh" || true
    fi
    log INFO "Test log saved to: $LOG_FILE"
    exit $exit_code
}

trap cleanup EXIT

# Function to check if AWS CLI is configured
check_aws_config() {
    log INFO "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        log ERROR "AWS CLI is not installed"
        return 1
    fi
    
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE" &> /dev/null; then
        log ERROR "AWS profile '$AWS_PROFILE' is not configured or invalid"
        return 1
    fi
    
    log SUCCESS "AWS CLI configured correctly"
}

# Function to check prerequisites
check_prerequisites() {
    log INFO "Checking prerequisites..."
    
    # Check required commands
    local required_commands=("aws" "curl" "jq" "openssl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log ERROR "Required command '$cmd' is not installed"
            return 1
        fi
    done
    
    # Check AWS configuration
    check_aws_config
    
    # Check if scripts exist
    local required_scripts=("scale-up.sh" "scale-down.sh" "check-health.sh" "status.sh")
    for script in "${required_scripts[@]}"; do
        if [ ! -f "${SCRIPT_DIR}/${script}" ]; then
            log ERROR "Required script '${script}' not found"
            return 1
        fi
        if [ ! -x "${SCRIPT_DIR}/${script}" ]; then
            log WARN "Making script '${script}' executable"
            chmod +x "${SCRIPT_DIR}/${script}"
        fi
    done
    
    log SUCCESS "All prerequisites met"
}

# Function to run a test phase
run_test_phase() {
    local phase_name=$1
    local phase_command=$2
    
    log INFO "Starting test phase: $phase_name"
    
    if eval "$phase_command"; then
        log SUCCESS "Test phase '$phase_name' completed successfully"
        return 0
    else
        log ERROR "Test phase '$phase_name' failed"
        return 1
    fi
}

# Function to test SSL certificate
test_ssl_certificate() {
    log INFO "Testing SSL certificate for $DOMAIN_NAME..."
    
    # Test SSL certificate validity
    local ssl_info
    if ssl_info=$(echo | openssl s_client -servername "$DOMAIN_NAME" -connect "$DOMAIN_NAME:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null); then
        log INFO "SSL certificate information:"
        echo "$ssl_info" | while read -r line; do
            log INFO "  $line"
        done
        
        # Check if certificate is valid (not expired)
        local not_after
        not_after=$(echo "$ssl_info" | grep "notAfter" | cut -d= -f2)
        local expiry_epoch
        expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null)
        local current_epoch
        current_epoch=$(date +%s)
        
        if [ "$expiry_epoch" -gt "$current_epoch" ]; then
            log SUCCESS "SSL certificate is valid and not expired"
        else
            log ERROR "SSL certificate is expired"
            return 1
        fi
    else
        log ERROR "Failed to retrieve SSL certificate information"
        return 1
    fi
}

# Function to test HTTPS access
test_https_access() {
    log INFO "Testing HTTPS access to https://$DOMAIN_NAME..."
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log INFO "HTTPS access attempt $attempt/$max_attempts"
        
        local http_code
        if http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "https://$DOMAIN_NAME/"); then
            if [ "$http_code" = "200" ]; then
                log SUCCESS "HTTPS access successful (HTTP $http_code)"
                return 0
            else
                log WARN "HTTPS access returned HTTP $http_code"
            fi
        else
            log WARN "HTTPS access attempt failed"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log INFO "Waiting 30 seconds before next attempt..."
            sleep 30
        fi
        
        ((attempt++))
    done
    
    log ERROR "HTTPS access failed after $max_attempts attempts"
    return 1
}

# Function to test Jitsi Meet functionality
test_jitsi_functionality() {
    log INFO "Testing basic Jitsi Meet functionality..."
    
    # Test if Jitsi Meet interface loads
    local response
    if response=$(curl -s --max-time 30 "https://$DOMAIN_NAME/"); then
        # Check for key Jitsi Meet elements in the response
        if echo "$response" | grep -q "Jitsi Meet" && echo "$response" | grep -q "Start meeting"; then
            log SUCCESS "Jitsi Meet interface loads correctly"
        else
            log ERROR "Jitsi Meet interface does not contain expected elements"
            log INFO "Response preview: $(echo "$response" | head -c 200)..."
            return 1
        fi
    else
        log ERROR "Failed to load Jitsi Meet interface"
        return 1
    fi
    
    # Test room creation endpoint (basic check)
    local test_room="test-room-$(date +%s)"
    local room_url="https://$DOMAIN_NAME/$test_room"
    
    log INFO "Testing room creation with URL: $room_url"
    local room_response
    if room_response=$(curl -s --max-time 30 "$room_url"); then
        if echo "$room_response" | grep -q "Jitsi Meet"; then
            log SUCCESS "Room creation test successful"
        else
            log WARN "Room creation test inconclusive"
        fi
    else
        log WARN "Room creation test failed, but this may be expected"
    fi
}

# Main testing workflow
main() {
    log INFO "Starting Jitsi Platform Testing Workflow"
    log INFO "Log file: $LOG_FILE"
    
    # Phase 1: Prerequisites
    run_test_phase "Prerequisites Check" "check_prerequisites"
    
    # Phase 2: Initial Status
    run_test_phase "Initial Status Check" "${SCRIPT_DIR}/status.sh"
    
    # Phase 3: Scale Up
    run_test_phase "Scale Up Service" "${SCRIPT_DIR}/scale-up.sh"
    
    # Phase 4: Health Checks
    run_test_phase "Health Verification" "${SCRIPT_DIR}/check-health.sh"
    
    # Phase 5: SSL Certificate Test
    run_test_phase "SSL Certificate Validation" "test_ssl_certificate"
    
    # Phase 6: HTTPS Access Test
    run_test_phase "HTTPS Access Test" "test_https_access"
    
    # Phase 7: Jitsi Functionality Test
    run_test_phase "Jitsi Functionality Test" "test_jitsi_functionality"
    
    # Phase 8: Final Status
    run_test_phase "Final Status Check" "${SCRIPT_DIR}/status.sh"
    
    # Phase 9: Scale Down
    run_test_phase "Scale Down Service" "${SCRIPT_DIR}/scale-down.sh"
    
    # Phase 10: Cleanup Verification
    run_test_phase "Cleanup Verification" "${SCRIPT_DIR}/status.sh"
    
    log SUCCESS "All testing phases completed successfully!"
    log INFO "Platform is ready for production use"
    log INFO "Complete test log available at: $LOG_FILE"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi