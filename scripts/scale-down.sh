#!/bin/bash

# Jitsi Platform Scale-Down Script
# Scales ECS service from current count to 0 with verification

set -euo pipefail

# Configuration
PROJECT_NAME="jitsi-video-platform"
CLUSTER_NAME="${PROJECT_NAME}-cluster"
SERVICE_NAME="${PROJECT_NAME}-service"
AWS_PROFILE="jitsi-dev"
AWS_REGION="us-west-2"
DESIRED_COUNT=0
TIMEOUT_MINUTES=5

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

# Function to get current pending count
get_pending_count() {
    local service_info
    service_info=$(get_service_status)
    echo "$service_info" | jq -r '.pendingCount // 0'
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

# Function to get running task ARNs
get_running_tasks() {
    aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$SERVICE_NAME" \
        --desired-status "RUNNING" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --query 'taskArns' \
        --output json 2>/dev/null || echo "[]"
}

# Function to scale down the service
scale_down_service() {
    log INFO "Scaling down ECS service '$SERVICE_NAME' to $DESIRED_COUNT instances..."
    
    local update_result
    if update_result=$(aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count "$DESIRED_COUNT" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json 2>&1); then
        
        log SUCCESS "Scale-down command executed successfully"
        return 0
    else
        log ERROR "Failed to execute scale-down command: $update_result"
        return 1
    fi
}

# Function to wait for tasks to stop
wait_for_tasks_to_stop() {
    log INFO "Waiting for all tasks to stop (timeout: ${TIMEOUT_MINUTES} minutes)..."
    
    local start_time
    start_time=$(date +%s)
    local timeout_seconds=$((TIMEOUT_MINUTES * 60))
    
    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $timeout_seconds ]; then
            log ERROR "Timeout reached waiting for tasks to stop"
            return 1
        fi
        
        local running_count
        running_count=$(get_running_count)
        local pending_count
        pending_count=$(get_pending_count)
        local desired_count
        desired_count=$(get_desired_count)
        
        log INFO "Status: Running=$running_count, Pending=$pending_count, Desired=$desired_count (${elapsed}s elapsed)"
        
        if [ "$running_count" -eq 0 ] && [ "$pending_count" -eq 0 ] && [ "$desired_count" -eq 0 ]; then
            log SUCCESS "All tasks have stopped successfully"
            return 0
        fi
        
        # List remaining tasks for debugging
        local running_tasks
        running_tasks=$(get_running_tasks)
        local task_count
        task_count=$(echo "$running_tasks" | jq '. | length')
        
        if [ "$task_count" -gt 0 ]; then
            log INFO "Remaining tasks:"
            echo "$running_tasks" | jq -r '.[]' | while read -r task_arn; do
                local task_id
                task_id=$(basename "$task_arn")
                log INFO "  Task: $task_id"
            done
        fi
        
        log INFO "Waiting 10 seconds before next check..."
        sleep 10
    done
}

# Function to verify scale-down completion
verify_scale_down() {
    log INFO "Verifying scale-down completion..."
    
    local running_count
    running_count=$(get_running_count)
    local pending_count
    pending_count=$(get_pending_count)
    local desired_count
    desired_count=$(get_desired_count)
    
    if [ "$running_count" -eq 0 ] && [ "$pending_count" -eq 0 ] && [ "$desired_count" -eq 0 ]; then
        log SUCCESS "Scale-down verification passed"
        return 0
    else
        log ERROR "Scale-down verification failed: Running=$running_count, Pending=$pending_count, Desired=$desired_count"
        return 1
    fi
}

# Function to check load balancer target health
check_target_health() {
    log INFO "Checking load balancer target health..."
    
    local service_info
    service_info=$(get_service_status)
    local target_groups
    target_groups=$(echo "$service_info" | jq -r '.loadBalancers[].targetGroupArn // empty')
    
    if [ -z "$target_groups" ]; then
        log INFO "No load balancer target groups configured"
        return 0
    fi
    
    local all_targets_drained=true
    
    while IFS= read -r tg_arn; do
        if [ -n "$tg_arn" ]; then
            local tg_name
            tg_name=$(basename "$tg_arn")
            log INFO "Checking target group: $tg_name"
            
            local target_health
            target_health=$(aws elbv2 describe-target-health \
                --target-group-arn "$tg_arn" \
                --profile "$AWS_PROFILE" \
                --region "$AWS_REGION" \
                --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$target_health" ]; then
                echo "$target_health" | while read -r target_id health_state; do
                    log INFO "  Target $target_id: $health_state"
                    if [ "$health_state" != "draining" ] && [ "$health_state" != "unused" ]; then
                        all_targets_drained=false
                    fi
                done
            else
                log INFO "  No targets found in target group"
            fi
        fi
    done <<< "$target_groups"
    
    if [ "$all_targets_drained" = true ]; then
        log SUCCESS "All load balancer targets are drained or unused"
    else
        log WARN "Some load balancer targets may still be active"
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
    
    # Check for any remaining tasks
    local running_tasks
    running_tasks=$(get_running_tasks)
    local task_count
    task_count=$(echo "$running_tasks" | jq '. | length')
    
    if [ "$task_count" -eq 0 ]; then
        log SUCCESS "No running tasks remaining"
    else
        log WARN "$task_count task(s) still running:"
        echo "$running_tasks" | jq -r '.[]' | while read -r task_arn; do
            local task_id
            task_id=$(basename "$task_arn")
            log WARN "  Task: $task_id"
        done
    fi
}

# Main function
main() {
    log INFO "Starting Jitsi Platform Scale-Down Process"
    
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
    local current_pending
    current_pending=$(get_pending_count)
    
    log INFO "Current service status: Running=$current_running, Desired=$current_desired, Pending=$current_pending"
    
    # Check if already scaled down
    if [ "$current_running" -eq 0 ] && [ "$current_desired" -eq 0 ] && [ "$current_pending" -eq 0 ]; then
        log SUCCESS "Service is already scaled down to zero"
        display_final_status
        check_target_health
        exit 0
    fi
    
    # Scale down the service
    if ! scale_down_service; then
        log ERROR "Failed to scale down service"
        exit 1
    fi
    
    # Wait for tasks to stop
    if ! wait_for_tasks_to_stop; then
        log ERROR "Failed to wait for all tasks to stop"
        display_final_status
        exit 1
    fi
    
    # Verify scale-down completion
    if ! verify_scale_down; then
        log ERROR "Scale-down verification failed"
        display_final_status
        exit 1
    fi
    
    # Check load balancer target health
    check_target_health
    
    # Display final status
    display_final_status
    
    log SUCCESS "Scale-down process completed successfully"
    log INFO "Service '$SERVICE_NAME' is now scaled to zero instances"
    log INFO "Platform is in cost-optimized state with no running compute resources"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi