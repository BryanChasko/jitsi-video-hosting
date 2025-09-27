#!/bin/bash

# Jitsi Platform Scale-Up Script
# Scales ECS service from 0 to 1 with health verification

set -euo pipefail

# Configuration
PROJECT_NAME="jitsi-video-platform"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
SERVICE_NAME="${PROJECT_NAME}-service"
AWS_PROFILE="jitsi-dev"
AWS_REGION="us-west-2"
DESIRED_COUNT=1
TIMEOUT_MINUTES=10

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
        INFO)  echo -e "${BLUE}[INFO]${NC} $message" ;;
        WARN)  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR) echo -e "${RED}[ERROR]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
    esac
}

# Function to get current service status
get_service_status() {
    aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'services[0]' \
        --output json 2>/dev/null || echo "{}"
}

# Function to get current running count
get_running_count() {
    local service_info
    service_info=$(get_service_status)
    echo "$service_info" | jq -r '.runningCount // 0'
}

# Function to get current desired count
get_desired_count() {
    local service_info
    service_info=$(get_service_status)
    echo "$service_info" | jq -r '.desiredCount // 0'
}

# Function to get service status
get_service_deployment_status() {
    local service_info
    service_info=$(get_service_status)
    echo "$service_info" | jq -r '.deployments[0].status // "UNKNOWN"'
}

# Function to check if service exists
check_service_exists() {
    local service_info
    service_info=$(get_service_status)
    local service_name
    service_name=$(echo "$service_info" | jq -r '.serviceName // ""')
    
    if [ "$service_name" = "$SERVICE_NAME" ]; then
        return 0
    else
        return 1
    fi
}

# Function to scale up the service
scale_up_service() {
    log INFO "Scaling up ECS service '$SERVICE_NAME' to $DESIRED_COUNT instance(s)..."
    
    local update_result
    if update_result=$(aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count "$DESIRED_COUNT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json 2>&1); then
        
        log SUCCESS "Scale-up command executed successfully"
        return 0
    else
        log ERROR "Failed to execute scale-up command: $update_result"
        return 1
    fi
}

# Function to wait for service to be stable
wait_for_service_stable() {
    log INFO "Waiting for service to reach stable state (timeout: ${TIMEOUT_MINUTES} minutes)..."
    
    local start_time
    start_time=$(date +%s)
    local timeout_seconds=$((TIMEOUT_MINUTES * 60))
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $timeout_seconds ]; then
            log ERROR "Timeout reached waiting for service to stabilize"
            return 1
        fi
        
        local running_count
        running_count=$(get_running_count)
        local desired_count
        desired_count=$(get_desired_count)
        local deployment_status
        deployment_status=$(get_service_deployment_status)
        
        log INFO "Status: Running=$running_count, Desired=$desired_count, Deployment=$deployment_status (${elapsed}s elapsed)"
        
        if [ "$running_count" = "$DESIRED_COUNT" ] && [ "$deployment_status" = "PRIMARY" ]; then
            log SUCCESS "Service has reached stable state with $running_count running instance(s)"
            return 0
        fi
        
        if [ "$deployment_status" = "FAILED" ]; then
            log ERROR "Service deployment failed"
            return 1
        fi
        
        log INFO "Waiting 15 seconds before next check..."
        sleep 15
    done
}

# Function to verify task health
verify_task_health() {
    log INFO "Verifying task health..."
    
    # Get task ARNs
    local task_arns
    task_arns=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'taskArns' \
        --output json)
    
    if [ "$(echo "$task_arns" | jq '. | length')" -eq 0 ]; then
        log ERROR "No tasks found for service"
        return 1
    fi
    
    # Get task details
    local tasks_info
    tasks_info=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks $(echo "$task_arns" | jq -r '.[]' | tr '\n' ' ') \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json)
    
    # Check each task
    local healthy_tasks=0
    local total_tasks
    total_tasks=$(echo "$tasks_info" | jq '.tasks | length')
    
    for i in $(seq 0 $((total_tasks - 1))); do
        local task_arn
        task_arn=$(echo "$tasks_info" | jq -r ".tasks[$i].taskArn")
        local last_status
        last_status=$(echo "$tasks_info" | jq -r ".tasks[$i].lastStatus")
        local health_status
        health_status=$(echo "$tasks_info" | jq -r ".tasks[$i].healthStatus // \"UNKNOWN\"")
        
        log INFO "Task $(basename "$task_arn"): Status=$last_status, Health=$health_status"
        
        if [ "$last_status" = "RUNNING" ] && [ "$health_status" = "HEALTHY" ]; then
            ((healthy_tasks++))
        fi
    done
    
    if [ $healthy_tasks -eq $total_tasks ]; then
        log SUCCESS "All $total_tasks task(s) are running and healthy"
        return 0
    else
        log WARN "$healthy_tasks out of $total_tasks task(s) are healthy"
        return 1
    fi
}

# Function to display final status
display_final_status() {
    log INFO "Final service status:"
    
    local service_info
    service_info=$(get_service_status)
    
    local running_count
    running_count=$(echo "$service_info" | jq -r '.runningCount')
    local desired_count
    desired_count=$(echo "$service_info" | jq -r '.desiredCount')
    local pending_count
    pending_count=$(echo "$service_info" | jq -r '.pendingCount')
    
    log INFO "  Running: $running_count"
    log INFO "  Desired: $desired_count"
    log INFO "  Pending: $pending_count"
    
    # Display load balancer target health if available
    local target_groups
    target_groups=$(echo "$service_info" | jq -r '.loadBalancers[].targetGroupArn // empty')
    
    if [ -n "$target_groups" ]; then
        log INFO "Load balancer target health:"
        while IFS= read -r tg_arn; do
            if [ -n "$tg_arn" ]; then
                local tg_name
                tg_name=$(basename "$tg_arn")
                log INFO "  Target Group: $tg_name"
                
                local target_health
                target_health=$(aws elbv2 describe-target-health \
                    --target-group-arn "$tg_arn" \
                    --profile "$AWS_PROFILE" \
                    --region "$AWS_REGION" \
                    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
                    --output text 2>/dev/null || echo "Unable to retrieve")
                
                if [ "$target_health" != "Unable to retrieve" ]; then
                    echo "$target_health" | while read -r target_id health_state; do
                        log INFO "    Target $target_id: $health_state"
                    done
                else
                    log WARN "    Unable to retrieve target health"
                fi
            fi
        done <<< "$target_groups"
    fi
}

# Main function
main() {
    log INFO "Starting Jitsi Platform Scale-Up Process"
    
    # Check if service exists
    if ! check_service_exists; then
        log ERROR "ECS service '$SERVICE_NAME' not found in cluster '$CLUSTER_NAME'"
        exit 1
    fi
    
    # Check current status
    local current_running
    current_running=$(get_running_count)
    local current_desired
    current_desired=$(get_desired_count)
    
    log INFO "Current service status: Running=$current_running, Desired=$current_desired"
    
    # Check if already scaled up
    if [ "$current_running" -ge "$DESIRED_COUNT" ] && [ "$current_desired" -ge "$DESIRED_COUNT" ]; then
        log WARN "Service is already scaled up (Running=$current_running, Desired=$current_desired)"
        log INFO "Verifying current task health..."
        if verify_task_health; then
            log SUCCESS "Service is already running and healthy"
            display_final_status
            exit 0
        else
            log WARN "Service is running but not all tasks are healthy"
        fi
    fi
    
    # Scale up the service
    if ! scale_up_service; then
        log ERROR "Failed to scale up service"
        exit 1
    fi
    
    # Wait for service to stabilize
    if ! wait_for_service_stable; then
        log ERROR "Service failed to reach stable state"
        display_final_status
        exit 1
    fi
    
    # Verify task health
    if ! verify_task_health; then
        log WARN "Service is running but not all tasks are healthy"
        log INFO "This may be temporary - tasks might still be starting up"
    fi
    
    # Display final status
    display_final_status
    
    log SUCCESS "Scale-up process completed successfully"
    log INFO "Service '$SERVICE_NAME' is now running with $DESIRED_COUNT instance(s)"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi