#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Term::ANSIColor qw(colored);
use POSIX qw(strftime);

# Configuration
my $PROJECT_NAME = "jitsi-video-platform";
my $CLUSTER_NAME = "${PROJECT_NAME}-cluster";
my $SERVICE_NAME = "${PROJECT_NAME}-service";
my $DOMAIN_NAME = "meet.awsaerospace.org";
my $AWS_PROFILE = "jitsi-dev";
my $AWS_REGION = "us-west-2";

# Logging function
sub log_message {
    my ($level, $message) = @_;
    
    my %colors = (
        'INFO'    => 'blue',
        'WARN'    => 'yellow', 
        'ERROR'   => 'red',
        'SUCCESS' => 'green',
        'HEADER'  => 'bold cyan'
    );
    
    my $color = $colors{$level} || 'white';
    
    if ($level eq 'HEADER') {
        print colored($message, $color) . "\n";
    } else {
        my $colored_message = colored("[$level]", $color) . " $message";
        print "$colored_message\n";
    }
    return;
}

# Function to display section header
sub section_header {
    my ($title) = @_;
    print "\n";
    log_message('HEADER', "═══ $title ═══");
    return;
}

# Function to get service information
sub get_service_info {
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

# Function to display ECS service status
sub display_ecs_status {
    section_header("ECS Service Status");
    
    my $service_info = get_service_info();
    my $data = decode_json($service_info);
    
    if (!$data->{serviceName}) {
        log_message('ERROR', "Service '$SERVICE_NAME' not found in cluster '$CLUSTER_NAME'");
        return 0;
    }
    
    my $service_name = $data->{serviceName};
    my $running_count = $data->{runningCount} // 0;
    my $desired_count = $data->{desiredCount} // 0;
    my $pending_count = $data->{pendingCount} // 0;
    my $task_definition = $data->{taskDefinition};
    $task_definition =~ s/.*\///;
    my $platform_version = $data->{platformVersion} // "N/A";
    my $created_at = $data->{createdAt};
    
    print "  Service Name: $service_name\n";
    print "  Running Tasks: $running_count\n";
    print "  Desired Tasks: $desired_count\n";
    print "  Pending Tasks: $pending_count\n";
    print "  Task Definition: $task_definition\n";
    print "  Platform Version: $platform_version\n";
    print "  Created: $created_at\n";
    
    # Service status indicator
    if ($running_count == $desired_count && $running_count > 0) {
        log_message('SUCCESS', "Service is running normally");
    } elsif ($running_count == 0 && $desired_count == 0) {
        log_message('INFO', "Service is scaled to zero (cost-optimized state)");
    } else {
        log_message('WARN', "Service is in transitional state");
    }
    
    return 1;
}

# Function to display task details
sub display_task_details {
    section_header("Task Details");
    
    my $task_cmd = "aws ecs list-tasks " .
                   "--cluster '$CLUSTER_NAME' " .
                   "--service-name '$SERVICE_NAME' " .
                   "--profile '$AWS_PROFILE' " .
                   "--region '$AWS_REGION' " .
                   "--query 'taskArns' " .
                   "--output json 2>/dev/null";
    
    my $task_arns_json = qx($task_cmd);
    return unless $? == 0;
    
    my $task_arns = decode_json($task_arns_json);
    my $task_count = @$task_arns;
    
    if ($task_count == 0) {
        print "  No running tasks\n";
        return;
    }
    
    my $tasks_cmd = "aws ecs describe-tasks " .
                    "--cluster '$CLUSTER_NAME' " .
                    "--tasks " . join(' ', @$task_arns) . " " .
                    "--profile '$AWS_PROFILE' " .
                    "--region '$AWS_REGION' " .
                    "--output json";
    
    my $tasks_json = qx($tasks_cmd);
    return unless $? == 0;
    
    my $tasks_info = decode_json($tasks_json);
    
    for my $i (0 .. $task_count - 1) {
        my $task = $tasks_info->{tasks}->[$i];
        my $task_arn = $task->{taskArn};
        my $task_id = (split '/', $task_arn)[-1];
        my $last_status = $task->{lastStatus};
        my $health_status = $task->{healthStatus} // "UNKNOWN";
        my $created_at = $task->{createdAt};
        my $started_at = $task->{startedAt} // "N/A";
        
        print "  Task " . ($i + 1) . ": $task_id\n";
        print "    Status: $last_status\n";
        print "    Health: $health_status\n";
        print "    Created: $created_at\n";
        print "    Started: $started_at\n";
        
        # Container status
        if ($task->{containers}) {
            for my $container (@{$task->{containers}}) {
                my $name = $container->{name};
                my $status = $container->{lastStatus};
                print "    Container: $name - $status\n";
            }
        }
    }
    return;
}

# Function to display load balancer status
sub display_load_balancer_status {
    section_header("Load Balancer Status");
    
    my $service_info = get_service_info();
    my $data = decode_json($service_info);
    
    if (!$data->{loadBalancers} || @{$data->{loadBalancers}} == 0) {
        print "  No load balancers configured\n";
        return;
    }
    
    for my $lb (@{$data->{loadBalancers}}) {
        my $tg_arn = $lb->{targetGroupArn};
        my $container_name = $lb->{containerName};
        my $container_port = $lb->{containerPort};
        
        my $tg_name = (split '/', $tg_arn)[-1];
        print "  Target Group: $tg_name\n";
        print "    Container: $container_name:$container_port\n";
        
        # Get target health
        my $health_cmd = "aws elbv2 describe-target-health " .
                         "--target-group-arn '$tg_arn' " .
                         "--profile '$AWS_PROFILE' " .
                         "--region '$AWS_REGION' " .
                         "--output json 2>/dev/null";
        
        my $target_health_json = qx($health_cmd);
        if ($? == 0) {
            my $target_health = decode_json($target_health_json);
            my $descriptions = $target_health->{TargetHealthDescriptions} // [];
            
            my $healthy_count = grep { $_->{TargetHealth}->{State} eq 'healthy' } @$descriptions;
            my $total_count = @$descriptions;
            
            print "    Healthy Targets: $healthy_count/$total_count\n";
            
            for my $desc (@$descriptions) {
                my $target_id = $desc->{Target}->{Id};
                my $state = $desc->{TargetHealth}->{State};
                print "      $target_id: $state\n";
            }
        }
    }
    return;
}

# Function to display network status
sub display_network_status {
    section_header("Network Status");
    
    print "  Domain: $DOMAIN_NAME\n";
    
    # DNS resolution
    my $dns_result = qx(nslookup $DOMAIN_NAME 2>/dev/null);
    if ($? == 0) {
        my ($ip) = $dns_result =~ /Address: (\S+)/;
        $ip //= "unknown";
        print "  DNS Resolution: ✓ ($ip)\n";
    } else {
        print "  DNS Resolution: ✗ (failed)\n";
    }
    
    # HTTPS connectivity
    my $http_code = qx(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://$DOMAIN_NAME/" 2>/dev/null);
    chomp $http_code;
    if ($? == 0 && $http_code) {
        print "  HTTPS Access: ✓ (HTTP $http_code)\n";
    } else {
        print "  HTTPS Access: ✗ (failed)\n";
    }
    
    # SSL certificate
    my $ssl_cmd = "echo | openssl s_client -servername '$DOMAIN_NAME' -connect '$DOMAIN_NAME:443' 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null";
    my $ssl_result = qx($ssl_cmd);
    if ($? == 0 && $ssl_result =~ /notAfter=(.+)/) {
        print "  SSL Certificate: ✓ (expires $1)\n";
    } else {
        print "  SSL Certificate: ✗ (check failed)\n";
    }
    return;
}

# Function to display resource utilization
sub display_resource_utilization {
    section_header("Resource Utilization");
    
    my $service_info = get_service_info();
    my $data = decode_json($service_info);
    my $running_count = $data->{runningCount} // 0;
    
    if ($running_count == 0) {
        print "  No running tasks - Zero cost state\n";
        print "  CPU: 0 vCPU allocated\n";
        print "  Memory: 0 GB allocated\n";
        print "  Estimated Cost: \$0.00/hour\n";
        return;
    }
    
    # Get task definition details
    my $task_def_arn = $data->{taskDefinition};
    my $task_def_cmd = "aws ecs describe-task-definition " .
                       "--task-definition '$task_def_arn' " .
                       "--profile '$AWS_PROFILE' " .
                       "--region '$AWS_REGION' " .
                       "--query 'taskDefinition' " .
                       "--output json 2>/dev/null";
    
    my $task_def_json = qx($task_def_cmd);
    return unless $? == 0;
    
    my $task_def_info = decode_json($task_def_json);
    my $cpu_units = $task_def_info->{cpu} // 0;
    my $memory_mb = $task_def_info->{memory} // 0;
    
    # Convert CPU units to vCPUs (1024 units = 1 vCPU)
    my $vcpus = $cpu_units / 1024;
    my $total_vcpus = $vcpus * $running_count;
    
    # Convert memory to GB
    my $memory_gb = $memory_mb / 1024;
    my $total_memory_gb = $memory_gb * $running_count;
    
    printf "  Running Tasks: %d\n", $running_count;
    printf "  CPU per Task: %.2f vCPU\n", $vcpus;
    printf "  Memory per Task: %.2f GB\n", $memory_gb;
    printf "  Total CPU: %.2f vCPU\n", $total_vcpus;
    printf "  Total Memory: %.2f GB\n", $total_memory_gb;
    
    # Rough cost estimation (Fargate pricing varies by region)
    my $estimated_hourly_cost = ($total_vcpus * 0.04048) + ($total_memory_gb * 0.004445);
    printf "  Estimated Cost: \$%.4f/hour (approximate)\n", $estimated_hourly_cost;
    return;
}

# Main function
sub main {
    log_message('HEADER', "Jitsi Platform Status Report");
    my $timestamp = strftime('%Y-%m-%d %H:%M:%S %Z', localtime);
    print "Generated: $timestamp\n";
    print "Region: $AWS_REGION\n";
    print "Profile: $AWS_PROFILE\n";
    
    display_ecs_status();
    display_task_details();
    display_load_balancer_status();
    display_network_status();
    display_resource_utilization();
    
    print "\n";
    log_message('HEADER', "Status Summary");
    
    my $service_info = get_service_info();
    my $data = decode_json($service_info);
    my $running_count = $data->{runningCount} // 0;
    my $desired_count = $data->{desiredCount} // 0;
    
    if ($running_count == $desired_count && $running_count > 0) {
        log_message('SUCCESS', "Platform is ACTIVE and running normally");
    } elsif ($running_count == 0 && $desired_count == 0) {
        log_message('INFO', "Platform is in STANDBY mode (scaled to zero)");
    } else {
        log_message('WARN', "Platform is in TRANSITIONAL state");
    }
    
    print "\n";
    return;
}

# Script entry point
main() if __FILE__ eq $0;