#!/bin/bash

# Jitsi Platform Status Script
# Displays comprehensive platform status information

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
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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
        HEADER) echo -e "${BOLD}${CYAN}$message${NC}" ;;
    esac
}

# Function to display section header
section_header() {
    echo
    log HEADER "═══ $1 ═══"
}

# Function to get service information
get_service_info() {
    aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'services[0]' \
        --output json 2>/dev/null || echo "{}"
}

# Function to display ECS service status
display_ecs_status() {
    section_header "ECS Service Status"
    
    local service_info
    service_info=$(get_service_info)
    
    if [ "$service_info" = "{}" ] || [ "$(echo "$service_info" | jq -r '.serviceName // ""')" = "" ]; then
        log ERROR "Service '$SERVICE_NAME' not found in cluster '$CLUSTER_NAME'"
        return 1
    fi
    
    local service_name
    service_name=$(echo "$service_info" | jq -r '.serviceName')
    local running_count
    running_count=$(echo "$service_info" | jq -r '.runningCount')
    local desired_count
    desired_count=$(echo "$service_info" | jq -r '.desiredCount')
    local pending_count
    pending_count=$(echo "$service_info" | jq -r '.pendingCount')
    local task_definition
    task_definition=$(echo "$service_info" | jq -r '.taskDefinition' | sed 's/.*\///')
    local platform_version
    platform_version=$(echo "$service_info" | jq -r '.platformVersion // "N/A"')
    local created_at
    created_at=$(echo "$service_info" | jq -r '.createdAt')
    
    echo "  Service Name: $service_name"
    echo "  Running Tasks: $running_count"
    echo "  Desired Tasks: $desired_count"
    echo "  Pending Tasks: $pending_count"
    echo "  Task Definition: $task_definition"
    echo "  Platform Version: $platform_version"
    echo "  Created: $created_at"
    
    # Service status indicator
    if [ "$running_count" -eq "$desired_count" ] && [ "$running_count" -gt 0 ]; then
        log SUCCESS "Service is running normally"
    elif [ "$running_count" -eq 0 ] && [ "$desired_count" -eq 0 ]; then
        log INFO "Service is scaled to zero (cost-optimized state)"
    else
        log WARN "Service is in transitional state"
    fi
}

# Function to display task details
display_task_details() {
    section_header "Task Details"
    
    local task_arns
    task_arns=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'taskArns' \
        --output json 2>/dev/null || echo "[]")
    
    local task_count
    task_count=$(echo "$task_arns" | jq '. | length')
    
    if [ "$task_count" -eq 0 ]; then
        echo "  No running tasks"
        return 0
    fi
    
    local tasks_info
    tasks_info=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks $(echo "$task_arns" | jq -r '.[]' | tr '\n' ' ') \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json)
    
    for i in $(seq 0 $((task_count - 1))); do
        local task_arn
        task_arn=$(echo "$tasks_info" | jq -r ".tasks[$i].taskArn")
        local task_id
        task_id=$(basename "$task_arn")
        local last_status
        last_status=$(echo "$tasks_info" | jq -r ".tasks[$i].lastStatus")
        local health_status
        health_status=$(echo "$tasks_info" | jq -r ".tasks[$i].healthStatus // \"UNKNOWN\"")
        local created_at
        created_at=$(echo "$tasks_info" | jq -r ".tasks[$i].createdAt")
        local started_at
        started_at=$(echo "$tasks_info" | jq -r ".tasks[$i].startedAt // \"N/A\"")
        
        echo "  Task $((i + 1)): $task_id"
        echo "    Status: $last_status"
        echo "    Health: $health_status"
        echo "    Created: $created_at"
        echo "    Started: $started_at"
        
        # Container status
        local containers
        containers=$(echo "$tasks_info" | jq -r ".tasks[$i].containers[]")
        echo "$containers" | jq -r '. | "    Container: \(.name) - \(.lastStatus)"' 2>/dev/null || echo "    Container info unavailable"
    done
}

# Function to display load balancer status
display_load_balancer_status() {
    section_header "Load Balancer Status"
    
    local service_info
    service_info=$(get_service_info)
    local load_balancers
    load_balancers=$(echo "$service_info" | jq -r '.loadBalancers[]?' 2>/dev/null || echo "")
    
    if [ -z "$load_balancers" ]; then
        echo "  No load balancers configured"
        return 0
    fi
    
    echo "$service_info" | jq -r '.loadBalancers[]' | while read -r lb_info; do
        local tg_arn
        tg_arn=$(echo "$lb_info" | jq -r '.targetGroupArn')
        local container_name
        container_name=$(echo "$lb_info" | jq -r '.containerName')
        local container_port
        container_port=$(echo "$lb_info" | jq -r '.containerPort')
        
        echo "  Target Group: $(basename "$tg_arn")"
        echo "    Container: $container_name:$container_port"
        
        # Get target health
        local target_health
        target_health=$(aws elbv2 describe-target-health \
            --target-group-arn "$tg_arn" \
            --profile "$AWS_PROFILE" \
            --region "$AWS_REGION" \
            --output json 2>/dev/null || echo '{"TargetHealthDescriptions":[]}')
        
        local healthy_count
        healthy_count=$(echo "$target_health" | jq '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
        local total_count
        total_count=$(echo "$target_health" | jq '.TargetHealthDescriptions | length')
        
        echo "    Healthy Targets: $healthy_count/$total_count"
        
        if [ "$total_count" -gt 0 ]; then
            echo "$target_health" | jq -r '.TargetHealthDescriptions[] | "      \(.Target.Id): \(.TargetHealth.State)"'
        fi
    done
}

# Function to display network status
display_network_status() {
    section_header "Network Status"
    
    echo "  Domain: $DOMAIN_NAME"
    
    # DNS resolution
    if nslookup "$DOMAIN_NAME" >/dev/null 2>&1; then
        local ip_address
        ip_address=$(nslookup "$DOMAIN_NAME" | grep -A1 "Name:" | tail -1 | awk '{print $2}' 2>/dev/null || echo "unknown")
        echo "  DNS Resolution: ✓ ($ip_address)"
    else
        echo "  DNS Resolution: ✗ (failed)"
    fi
    
    # HTTPS connectivity
    local http_code
    if http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$DOMAIN_NAME/" 2>/dev/null); then
        echo "  HTTPS Access: ✓ (HTTP $http_code)"
    else
        echo "  HTTPS Access: ✗ (failed)"
    fi
    
    # SSL certificate
    local ssl_expiry
    if ssl_expiry=$(echo | openssl s_client -servername "$DOMAIN_NAME" -connect "$DOMAIN_NAME:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2); then
        echo "  SSL Certificate: ✓ (expires $ssl_expiry)"
    else
        echo "  SSL Certificate: ✗ (check failed)"
    fi
}

# Function to display resource utilization
display_resource_utilization() {
    section_header "Resource Utilization"
    
    local service_info
    service_info=$(get_service_info)
    local running_count
    running_count=$(echo "$service_info" | jq -r '.runningCount // 0')
    
    if [ "$running_count" -eq 0 ]; then
        echo "  No running tasks - Zero cost state"
        echo "  CPU: 0 vCPU allocated"
        echo "  Memory: 0 GB allocated"
        echo "  Estimated Cost: $0.00/hour"
        return 0
    fi
    
    # Get task definition details
    local task_def_arn
    task_def_arn=$(echo "$service_info" | jq -r '.taskDefinition')
    
    local task_def_info
    task_def_info=$(aws ecs describe-task-definition \
        --task-definition "$task_def_arn" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'taskDefinition' \
        --output json 2>/dev/null || echo "{}")
    
    local cpu_units
    cpu_units=$(echo "$task_def_info" | jq -r '.cpu // "0"')
    local memory_mb
    memory_mb=$(echo "$task_def_info" | jq -r '.memory // "0"')
    
    # Convert CPU units to vCPUs (1024 units = 1 vCPU)
    local vcpus
    vcpus=$(echo "scale=2; $cpu_units / 1024" | bc 2>/dev/null || echo "0")
    local total_vcpus
    total_vcpus=$(echo "scale=2; $vcpus * $running_count" | bc 2>/dev/null || echo "0")
    
    # Convert memory to GB
    local memory_gb
    memory_gb=$(echo "scale=2; $memory_mb / 1024" | bc 2>/dev/null || echo "0")
    local total_memory_gb
    total_memory_gb=$(echo "scale=2; $memory_gb * $running_count" | bc 2>/dev/null || echo "0")
    
    echo "  Running Tasks: $running_count"
    echo "  CPU per Task: ${vcpus} vCPU"
    echo "  Memory per Task: ${memory_gb} GB"
    echo "  Total CPU: ${total_vcpus} vCPU"
    echo "  Total Memory: ${total_memory_gb} GB"
    
    # Rough cost estimation (Fargate pricing varies by region)
    # This is approximate - actual costs may vary
    local estimated_hourly_cost
    estimated_hourly_cost=$(echo "scale=4; ($total_vcpus * 0.04048) + ($total_memory_gb * 0.004445)" | bc 2>/dev/null || echo "0.0000")
    echo "  Estimated Cost: \$${estimated_hourly_cost}/hour (approximate)"
}

# Main function
main() {
    log HEADER "Jitsi Platform Status Report"
    echo "Generated: $(date)"
    echo "Region: $AWS_REGION"
    echo "Profile: $AWS_PROFILE"
    
    display_ecs_status
    display_task_details
    display_load_balancer_status
    display_network_status
    display_resource_utilization
    
    echo
    log HEADER "Status Summary"
    
    local service_info
    service_info=$(get_service_info)
    local running_count
    running_count=$(echo "$service_info" | jq -r '.runningCount // 0')
    local desired_count
    desired_count=$(echo "$service_info" | jq -r '.desiredCount // 0')
    
    if [ "$running_count" -eq "$desired_count" ] && [ "$running_count" -gt 0 ]; then
        log SUCCESS "Platform is ACTIVE and running normally"
    elif [ "$running_count" -eq 0 ] && [ "$desired_count" -eq 0 ]; then
        log INFO "Platform is in STANDBY mode (scaled to zero)"
    else
        log WARN "Platform is in TRANSITIONAL state"
    fi
    
    echo
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi