#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Term::ANSIColor qw(colored);
use POSIX qw(strftime);
use lib '../lib';
use JitsiConfig;

# Load configuration from JitsiConfig
my $config = JitsiConfig->new();
my $PROJECT_NAME = $config->project_name();
my $CLUSTER_NAME = $config->cluster_name();
my $SERVICE_NAME = $config->service_name();
my $AWS_PROFILE = $config->aws_profile();
my $AWS_REGION = $config->aws_region();
my $DESIRED_COUNT = 1;
my $TIMEOUT_MINUTES = 10;

# Logging function
sub log_message {
    my ($level, $message) = @_;
    my $timestamp = strftime('%Y-%m-%d %H:%M:%S', localtime);
    
    my %colors = (
        'INFO'    => 'blue',
        'WARN'    => 'yellow', 
        'ERROR'   => 'red',
        'SUCCESS' => 'green'
    );
    
    my $color = $colors{$level} || 'white';
    my $colored_message = colored("[$level]", $color) . " $message";
    
    print "$colored_message\n";
    return;
}

# Function to get current service status
sub get_service_status {
    my $cmd = "aws ecs describe-services " .
              "--cluster '$CLUSTER_NAME' " .
              "--services '$SERVICE_NAME' " .
              "--profile '$AWS_PROFILE' " .
              "--region '$AWS_REGION' " .
              "--query 'services[0]' " .
              "--output json 2>/dev/null";
    
    my $output = qx($cmd);
    return $? == 0 ? $output : "{}";
}

# Function to get current running count
sub get_running_count {
    my $service_info = get_service_status();
    my $data = decode_json($service_info);
    return $data->{runningCount} // 0;
}

# Function to get current desired count
sub get_desired_count {
    my $service_info = get_service_status();
    my $data = decode_json($service_info);
    return $data->{desiredCount} // 0;
}

# Function to get service deployment status
sub get_service_deployment_status {
    my $service_info = get_service_status();
    my $data = decode_json($service_info);
    return $data->{deployments}->[0]->{status} // "UNKNOWN";
}

# Function to check if service exists
sub check_service_exists {
    my $service_info = get_service_status();
    my $data = decode_json($service_info);
    my $service_name = $data->{serviceName} // "";
    
    return $service_name eq $SERVICE_NAME;
}

# Function to create NLB
sub create_nlb {
    log_message('INFO', 'Creating Network Load Balancer for JVB...');
    
    my $cmd = "cd .. && terraform apply -var='nlb_enabled=true' -target=module.jvb_nlb -auto-approve";
    my $result = system($cmd);
    
    if ($result != 0) {
        log_message('ERROR', 'Failed to create NLB');
        return 0;
    }
    
    log_message('SUCCESS', 'NLB created successfully');
    return 1;
}

# Function to wait for NLB to be active
sub wait_for_nlb_active {
    log_message('INFO', 'Waiting for NLB to become active...');
    
    my $max_attempts = 30;
    my $attempt = 0;
    
    while ($attempt < $max_attempts) {
        my $cmd = "aws elbv2 describe-load-balancers " .
                  "--names '$PROJECT_NAME-jvb-nlb' " .
                  "--profile '$AWS_PROFILE' " .
                  "--region '$AWS_REGION' " .
                  "--query 'LoadBalancers[0].State.Code' " .
                  "--output text 2>/dev/null";
        
        my $state = qx($cmd);
        chomp($state) if $state;
        
        if ($state eq 'active') {
            log_message('SUCCESS', 'NLB is now active');
            return 1;
        }
        
        $attempt++;
        log_message('INFO', "NLB state: $state (attempt $attempt/$max_attempts)");
        sleep(10);
    }
    
    log_message('ERROR', 'NLB failed to become active within timeout');
    return 0;
}

# Function to register ECS tasks with NLB target groups
sub register_nlb_targets {
    log_message('INFO', 'Registering ECS task IPs with NLB target groups...');
    
    # Get task IPs
    my $cmd = "aws ecs list-tasks " .
              "--cluster '$CLUSTER_NAME' " .
              "--service-name '$SERVICE_NAME' " .
              "--profile '$AWS_PROFILE' " .
              "--region '$AWS_REGION' " .
              "--query 'taskArns' " .
              "--output text 2>/dev/null";
    
    my $task_arns = qx($cmd);
    chomp($task_arns) if $task_arns;
    
    if (!$task_arns || $task_arns eq 'None') {
        log_message('WARN', 'No running tasks found for target registration');
        return 1;
    }
    
    # Get task details for IP addresses
    $cmd = "aws ecs describe-tasks " .
           "--cluster '$CLUSTER_NAME' " .
           "--tasks $task_arns " .
           "--profile '$AWS_PROFILE' " .
           "--region '$AWS_REGION' " .
           "--query 'tasks[].attachments[].details[?name==\`privateIPv4Address\`].value' " .
           "--output text 2>/dev/null";
    
    my $task_ips = qx($cmd);
    chomp($task_ips) if $task_ips;
    
    if (!$task_ips) {
        log_message('WARN', 'Could not retrieve task IP addresses');
        return 1;
    }
    
    # Get target group ARNs
    my $udp_tg_cmd = "cd .. && terraform output -raw jvb_nlb_target_group_udp_arn 2>/dev/null";
    my $tcp_tg_cmd = "cd .. && terraform output -raw jvb_nlb_target_group_tcp_arn 2>/dev/null";
    
    my $udp_tg_arn = qx($udp_tg_cmd);
    my $tcp_tg_arn = qx($tcp_tg_cmd);
    chomp($udp_tg_arn) if $udp_tg_arn;
    chomp($tcp_tg_arn) if $tcp_tg_arn;
    
    if (!$udp_tg_arn || !$tcp_tg_arn) {
        log_message('WARN', 'Could not retrieve target group ARNs');
        return 1;
    }
    
    # Register targets
    for my $ip (split(/\s+/, $task_ips)) {
        next unless $ip;
        
        # Register UDP target
        my $udp_cmd = "aws elbv2 register-targets " .
                      "--target-group-arn '$udp_tg_arn' " .
                      "--targets Id=$ip,Port=10000 " .
                      "--profile '$AWS_PROFILE' " .
                      "--region '$AWS_REGION' 2>/dev/null";
        
        # Register TCP target  
        my $tcp_cmd = "aws elbv2 register-targets " .
                      "--target-group-arn '$tcp_tg_arn' " .
                      "--targets Id=$ip,Port=4443 " .
                      "--profile '$AWS_PROFILE' " .
                      "--region '$AWS_REGION' 2>/dev/null";
        
        system($udp_cmd);
        system($tcp_cmd);
        
        log_message('INFO', "Registered task IP $ip with NLB target groups");
    }
    
    log_message('SUCCESS', 'Target registration completed');
    return 1;
}

# Function to scale up the service
sub scale_up_service {
    log_message('INFO', "Scaling up ECS service '$SERVICE_NAME' to $DESIRED_COUNT instance(s)...");
    
    my $cmd = "aws ecs update-service " .
              "--cluster '$CLUSTER_NAME' " .
              "--service '$SERVICE_NAME' " .
              "--desired-count $DESIRED_COUNT " .
              "--profile '$AWS_PROFILE' " .
              "--region '$AWS_REGION' " .
              "--output json 2>&1";
    
    my $result = qx($cmd);
    my $exit_code = $? >> 8;
    
    if ($exit_code == 0) {
        log_message('SUCCESS', "Scale-up command executed successfully");
        return 1;
    } else {
        log_message('ERROR', "Failed to execute scale-up command: $result");
        return 0;
    }
}

# Function to wait for service to be stable
sub wait_for_service_stable {
    log_message('INFO', "Waiting for service to reach stable state (timeout: ${TIMEOUT_MINUTES} minutes)...");
    
    my $start_time = time();
    my $timeout_seconds = $TIMEOUT_MINUTES * 60;
    
    while (1) {
        my $current_time = time();
        my $elapsed = $current_time - $start_time;
        
        if ($elapsed >= $timeout_seconds) {
            log_message('ERROR', "Timeout reached waiting for service to stabilize");
            return 0;
        }
        
        my $running_count = get_running_count();
        my $desired_count = get_desired_count();
        my $deployment_status = get_service_deployment_status();
        
        log_message('INFO', "Status: Running=$running_count, Desired=$desired_count, Deployment=$deployment_status (${elapsed}s elapsed)");
        
        if ($running_count == $DESIRED_COUNT && $deployment_status eq "PRIMARY") {
            log_message('SUCCESS', "Service has reached stable state with $running_count running instance(s)");
            return 1;
        }
        
        if ($deployment_status eq "FAILED") {
            log_message('ERROR', "Service deployment failed");
            return 0;
        }
        
        log_message('INFO', "Waiting 15 seconds before next check...");
        sleep 15;
    }
    return;
}

# Function to verify task health
sub verify_task_health {
    log_message('INFO', "Verifying task health...");
    
    # Get task ARNs
    my $task_cmd = "aws ecs list-tasks " .
                   "--cluster '$CLUSTER_NAME' " .
                   "--service-name '$SERVICE_NAME' " .
                   "--profile '$AWS_PROFILE' " .
                   "--region '$AWS_REGION' " .
                   "--query 'taskArns' " .
                   "--output json";
    
    my $task_arns_json = qx($task_cmd);
    return 0 if $? != 0;
    
    my $task_arns = decode_json($task_arns_json);
    
    if (@$task_arns == 0) {
        log_message('ERROR', "No tasks found for service");
        return 0;
    }
    
    # Get task details
    my $tasks_cmd = "aws ecs describe-tasks " .
                    "--cluster '$CLUSTER_NAME' " .
                    "--tasks " . join(' ', @$task_arns) . " " .
                    "--profile '$AWS_PROFILE' " .
                    "--region '$AWS_REGION' " .
                    "--output json";
    
    my $tasks_json = qx($tasks_cmd);
    return 0 if $? != 0;
    
    my $tasks_info = decode_json($tasks_json);
    
    # Check each task
    my $healthy_tasks = 0;
    my $total_tasks = @{$tasks_info->{tasks}};
    
    for my $task (@{$tasks_info->{tasks}}) {
        my $task_arn = $task->{taskArn};
        my $last_status = $task->{lastStatus};
        my $health_status = $task->{healthStatus} // "UNKNOWN";
        
        my $task_id = (split '/', $task_arn)[-1];
        log_message('INFO', "Task $task_id: Status=$last_status, Health=$health_status");
        
        if ($last_status eq "RUNNING" && $health_status eq "HEALTHY") {
            $healthy_tasks++;
        }
    }
    
    if ($healthy_tasks == $total_tasks) {
        log_message('SUCCESS', "All $total_tasks task(s) are running and healthy");
        return 1;
    } else {
        log_message('WARN', "$healthy_tasks out of $total_tasks task(s) are healthy");
        return 0;
    }
}

# Function to display final status
sub display_final_status {
    log_message('INFO', "Final service status:");
    
    my $service_info = get_service_status();
    my $data = decode_json($service_info);
    
    my $running_count = $data->{runningCount};
    my $desired_count = $data->{desiredCount};
    my $pending_count = $data->{pendingCount};
    
    log_message('INFO', "  Running: $running_count");
    log_message('INFO', "  Desired: $desired_count");
    log_message('INFO', "  Pending: $pending_count");
    return;
}

# Main function
sub main {
    log_message('INFO', "Starting Jitsi Platform Scale-Up Process");
    
    # Step 1: Create NLB first
    unless (create_nlb()) {
        log_message('ERROR', 'Failed to create NLB');
        exit 1;
    }
    
    unless (wait_for_nlb_active()) {
        log_message('ERROR', 'NLB failed to become active');
        exit 1;
    }
    
    # Check if service exists
    unless (check_service_exists()) {
        log_message('ERROR', "ECS service '$SERVICE_NAME' not found in cluster '$CLUSTER_NAME'");
        exit 1;
    }
    
    # Check current status
    my $current_running = get_running_count();
    my $current_desired = get_desired_count();
    
    log_message('INFO', "Current service status: Running=$current_running, Desired=$current_desired");
    
    # Check if already scaled up
    if ($current_running >= $DESIRED_COUNT && $current_desired >= $DESIRED_COUNT) {
        log_message('WARN', "Service is already scaled up (Running=$current_running, Desired=$current_desired)");
        log_message('INFO', "Verifying current task health...");
        if (verify_task_health()) {
            log_message('SUCCESS', "Service is already running and healthy");
            display_final_status();
            exit 0;
        } else {
            log_message('WARN', "Service is running but not all tasks are healthy");
        }
    }
    
    # Scale up the service
    unless (scale_up_service()) {
        log_message('ERROR', "Failed to scale up service");
        exit 1;
    }
    
    # Wait for service to stabilize
    unless (wait_for_service_stable()) {
        log_message('ERROR', "Service failed to reach stable state");
        display_final_status();
        exit 1;
    }
    
    # Register tasks with NLB target groups
    unless (register_nlb_targets()) {
        log_message('WARN', 'Failed to register some targets with NLB');
    }
    
    # Verify task health
    unless (verify_task_health()) {
        log_message('WARN', "Service is running but not all tasks are healthy");
        log_message('INFO', "This may be temporary - tasks might still be starting up");
    }
    
    # Display final status
    display_final_status();
    
    log_message('SUCCESS', "Scale-up process completed successfully");
    log_message('INFO', "Service '$SERVICE_NAME' is now running with $DESIRED_COUNT instance(s)");
    return;
}

# Script entry point
main() if __FILE__ eq $0;