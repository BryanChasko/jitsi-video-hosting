#!/bin/bash

# Jitsi Platform Health Check Script
# Comprehensive health verification for ECS service, load balancers, and application

set -euo pipefail

# Configuration
PROJECT_NAME="jitsi-video-platform"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
SERVICE_NAME="${PROJECT_NAME}-service"
DOMAIN_NAME="meet.awsaerospace.org"
AWS_PROFILE="jitsi-dev"
AWS_REGION="us-west-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Health check results
HEALTH_CHECKS_PASSED=0
HEALTH_CHECKS_TOTAL=0

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    
    case $level in
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
    esac
}

# Function to run a health check
run_health_check() {
    local check_name=$1
    local check_function=$2
    
    ((HEALTH_CHECKS_TOTAL++))
    log INFO "Running health check: $check_name"
    
    if $check_function; then
        log SUCCESS "✓ $check_name: PASSED"
        ((HEALTH_CHECKS_PASSED++))
        return 0
    else
        log ERROR "✗ $check_name: FAILED"
        return 1
    fi
}

# Health check: ECS Service Status
check_ecs_service_status() {
    local service_info
    service_info=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'services[0]' \
        --output json 2>/dev/null)
    
    if [ "$service_info" = "null" ] || [ -z "$service_info" ]; then
        log ERROR "Service not found"
        return 1
    fi
    
    local running_count
    running_count=$(echo "$service_info" | jq -r '.runningCount // 0')
    local desired_count
    desired_count=$(echo "$service_info" | jq -r '.desiredCount // 0')
    
    if [ "$running_count" -eq "$desired_count" ] && [ "$running_count" -gt 0 ]; then
        log INFO "Service running: $running_count/$desired_count tasks"
        return 0
    else
        log ERROR "Service not healthy: $running_count/$desired_count tasks running"
        return 1
    fi
}

# Health check: Task Health Status
check_task_health() {
    local task_arns
    task_arns=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'taskArns' \
        --output json)
    
    local task_count
    task_count=$(echo "$task_arns" | jq '. | length')
    
    if [ "$task_count" -eq 0 ]; then
        log ERROR "No tasks found"
        return 1
    fi
    
    local tasks_info
    tasks_info=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks $(echo "$task_arns" | jq -r '.[]' | tr '\n' ' ') \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json)
    
    local healthy_tasks=0
    
    for i in $(seq 0 $((task_count - 1))); do
        local last_status
        last_status=$(echo "$tasks_info" | jq -r ".tasks[$i].lastStatus")
        local health_status
        health_status=$(echo "$tasks_info" | jq -r ".tasks[$i].healthStatus // \"UNKNOWN\"")
        
        if [ "$last_status" = "RUNNING" ] && [ "$health_status" = "HEALTHY" ]; then
            ((healthy_tasks++))
        fi
    done
    
    if [ $healthy_tasks -eq $task_count ]; then
        log INFO "All $task_count task(s) are healthy"
        return 0
    else
        log ERROR "Only $healthy_tasks out of $task_count task(s) are healthy"
        return 1
    fi
}

# Health check: Load Balancer Target Health
check_load_balancer_targets() {
    local service_info
    service_info=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'services[0]' \
        --output json)
    
    local target_groups
    target_groups=$(echo "$service_info" | jq -r '.loadBalancers[].targetGroupArn // empty')
    
    if [ -z "$target_groups" ]; then
        log WARN "No load balancer target groups found"
        return 0
    fi
    
    local all_healthy=true
    
    while IFS= read -r tg_arn; do
        if [ -n "$tg_arn" ]; then
            local target_health
            target_health=$(aws elbv2 describe-target-health \
                --target-group-arn "$tg_arn" \
                --profile "$AWS_PROFILE" \
                --region "$AWS_REGION" \
                --output json 2>/dev/null)
            
            local healthy_targets
            healthy_targets=$(echo "$target_health" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
            local total_targets
            total_targets=$(echo "$target_health" | jq '.TargetHealthDescriptions | length')
            
            if [ "$healthy_targets" -eq "$total_targets" ] && [ "$total_targets" -gt 0 ]; then
                log INFO "Target group $(basename "$tg_arn"): $healthy_targets/$total_targets healthy"
            else
                log ERROR "Target group $(basename "$tg_arn"): $healthy_targets/$total_targets healthy"
                all_healthy=false
            fi
        fi
    done <<< "$target_groups"
    
    if [ "$all_healthy" = true ]; then
        return 0
    else
        return 1
    fi
}

# Health check: DNS Resolution
check_dns_resolution() {
    if nslookup "$DOMAIN_NAME" >/dev/null 2>&1; then
        local ip_address
        ip_address=$(nslookup "$DOMAIN_NAME" | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "unknown")
        log INFO "DNS resolution successful: $DOMAIN_NAME -> $ip_address"
        return 0
    else
        log ERROR "DNS resolution failed for $DOMAIN_NAME"
        return 1
    fi
}

# Health check: HTTPS Connectivity
check_https_connectivity() {
    local http_code
    if http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$DOMAIN_NAME/" 2>/dev/null); then
        if [ "$http_code" = "200" ]; then
            log INFO "HTTPS connectivity successful (HTTP $http_code)"
            return 0
        else
            log ERROR "HTTPS connectivity failed (HTTP $http_code)"
            return 1
        fi
    else
        log ERROR "HTTPS connectivity failed (connection error)"
        return 1
    fi
}

# Health check: SSL Certificate
check_ssl_certificate() {
    local ssl_check
    if ssl_check=$(echo | openssl s_client -servername "$DOMAIN_NAME" -connect "$DOMAIN_NAME:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null); then
        local not_after
        not_after=$(echo "$ssl_check" | grep "notAfter" | cut -d= -f2)
        log INFO "SSL certificate valid until: $not_after"
        return 0
    else
        log ERROR "SSL certificate check failed"
        return 1
    fi
}

# Health check: Application Response
check_application_response() {
    local response
    if response=$(curl -s --max-time 10 "https://$DOMAIN_NAME/" 2>/dev/null); then
        if echo "$response" | grep -q "Jitsi Meet"; then
            log INFO "Application responding correctly (Jitsi Meet detected)"
            return 0
        else
            log ERROR "Application not responding correctly (Jitsi Meet not detected)"
            return 1
        fi
    else
        log ERROR "Application not responding"
        return 1
    fi
}

# Main function
main() {
    log INFO "Starting Jitsi Platform Health Check"
    log INFO "Target: $DOMAIN_NAME"
    log INFO "Cluster: $CLUSTER_NAME"
    log INFO "Service: $SERVICE_NAME"
    echo
    
    # Run all health checks
    run_health_check "ECS Service Status" "check_ecs_service_status"
    run_health_check "Task Health Status" "check_task_health"
    run_health_check "Load Balancer Targets" "check_load_balancer_targets"
    run_health_check "DNS Resolution" "check_dns_resolution"
    run_health_check "HTTPS Connectivity" "check_https_connectivity"
    run_health_check "SSL Certificate" "check_ssl_certificate"
    run_health_check "Application Response" "check_application_response"
    
    echo
    log INFO "Health Check Summary:"
    log INFO "Passed: $HEALTH_CHECKS_PASSED/$HEALTH_CHECKS_TOTAL checks"
    
    if [ $HEALTH_CHECKS_PASSED -eq $HEALTH_CHECKS_TOTAL ]; then
        log SUCCESS "All health checks passed - Platform is healthy!"
        exit 0
    else
        local failed_checks=$((HEALTH_CHECKS_TOTAL - HEALTH_CHECKS_PASSED))
        log ERROR "$failed_checks health check(s) failed - Platform needs attention"
        exit 1
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi