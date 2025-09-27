#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Term::ANSIColor qw(colored);

# Configuration
my $PROJECT_NAME = "jitsi-video-platform";
my $CLUSTER_NAME = "${PROJECT_NAME}-cluster";
my $SERVICE_NAME = "${PROJECT_NAME}-service";
my $DOMAIN_NAME = "meet.awsaerospace.org";
my $AWS_PROFILE = "jitsi-dev";
my $AWS_REGION = "us-west-2";

# Health check results
my $HEALTH_CHECKS_PASSED = 0;
my $HEALTH_CHECKS_TOTAL = 0;

# Logging function
sub log_message {
    my ($level, $message) = @_;
    
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

# Function to run a health check
sub run_health_check {
    my ($check_name, $check_function) = @_;
    
    $HEALTH_CHECKS_TOTAL++;
    log_message('INFO', "Running health check: $check_name");
    
    if ($check_function->()) {
        log_message('SUCCESS', "✓ $check_name: PASSED");
        $HEALTH_CHECKS_PASSED++;
        return 1;
    } else {
        log_message('ERROR', "✗ $check_name: FAILED");
        return 0;
    }
}

# Health check: ECS Service Status
sub check_ecs_service_status {
    my $cmd = "aws ecs describe-services " .
              "--cluster '$CLUSTER_NAME' " .
              "--services '$SERVICE_NAME' " .
              "--profile '$AWS_PROFILE' " .
              "--region '$AWS_REGION' " .
              "--query 'services[0]' " .
              "--output json 2>/dev/null";
    
    my $service_info = qx($cmd);
    return 0 if $? != 0;
    
    my $data = decode_json($service_info);
    return 0 unless $data->{serviceName};
    
    my $running_count = $data->{runningCount} // 0;
    my $desired_count = $data->{desiredCount} // 0;
    
    if ($running_count == $desired_count && $running_count > 0) {
        log_message('INFO', "Service running: $running_count/$desired_count tasks");
        return 1;
    } else {
        log_message('ERROR', "Service not healthy: $running_count/$desired_count tasks running");
        return 0;
    }
}

# Health check: Task Health Status
sub check_task_health {
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
    my $task_count = @$task_arns;
    
    if ($task_count == 0) {
        log_message('ERROR', "No tasks found");
        return 0;
    }
    
    my $tasks_cmd = "aws ecs describe-tasks " .
                    "--cluster '$CLUSTER_NAME' " .
                    "--tasks " . join(' ', @$task_arns) . " " .
                    "--profile '$AWS_PROFILE' " .
                    "--region '$AWS_REGION' " .
                    "--output json";
    
    my $tasks_json = qx($tasks_cmd);
    return 0 if $? != 0;
    
    my $tasks_info = decode_json($tasks_json);
    my $healthy_tasks = 0;
    
    for my $task (@{$tasks_info->{tasks}}) {
        my $last_status = $task->{lastStatus};
        my $health_status = $task->{healthStatus} // "UNKNOWN";
        
        if ($last_status eq "RUNNING" && $health_status eq "HEALTHY") {
            $healthy_tasks++;
        }
    }
    
    if ($healthy_tasks == $task_count) {
        log_message('INFO', "All $task_count task(s) are healthy");
        return 1;
    } else {
        log_message('ERROR', "Only $healthy_tasks out of $task_count task(s) are healthy");
        return 0;
    }
}

# Health check: Load Balancer Target Health
sub check_load_balancer_targets {
    my $service_cmd = "aws ecs describe-services " .
                      "--cluster '$CLUSTER_NAME' " .
                      "--services '$SERVICE_NAME' " .
                      "--profile '$AWS_PROFILE' " .
                      "--region '$AWS_REGION' " .
                      "--query 'services[0]' " .
                      "--output json";
    
    my $service_info = qx($service_cmd);
    return 0 if $? != 0;
    
    my $data = decode_json($service_info);
    
    if (!$data->{loadBalancers} || @{$data->{loadBalancers}} == 0) {
        log_message('WARN', "No load balancer target groups found");
        return 1;
    }
    
    my $all_healthy = 1;
    
    for my $lb (@{$data->{loadBalancers}}) {
        my $tg_arn = $lb->{targetGroupArn};
        
        my $health_cmd = "aws elbv2 describe-target-health " .
                         "--target-group-arn '$tg_arn' " .
                         "--profile '$AWS_PROFILE' " .
                         "--region '$AWS_REGION' " .
                         "--output json 2>/dev/null";
        
        my $target_health_json = qx($health_cmd);
        next if $? != 0;
        
        my $target_health = decode_json($target_health_json);
        my $descriptions = $target_health->{TargetHealthDescriptions} // [];
        
        my $healthy_targets = grep { $_->{TargetHealth}->{State} eq 'healthy' } @$descriptions;
        my $total_targets = @$descriptions;
        
        my $tg_name = (split '/', $tg_arn)[-1];
        
        if ($healthy_targets == $total_targets && $total_targets > 0) {
            log_message('INFO', "Target group $tg_name: $healthy_targets/$total_targets healthy");
        } else {
            log_message('ERROR', "Target group $tg_name: $healthy_targets/$total_targets healthy");
            $all_healthy = 0;
        }
    }
    
    return $all_healthy;
}

# Health check: DNS Resolution
sub check_dns_resolution {
    my $dns_result = qx(nslookup $DOMAIN_NAME 2>/dev/null);
    
    if ($? == 0) {
        my ($ip) = $dns_result =~ /Address: (\S+)/;
        $ip //= "unknown";
        log_message('INFO', "DNS resolution successful: $DOMAIN_NAME -> $ip");
        return 1;
    } else {
        log_message('ERROR', "DNS resolution failed for $DOMAIN_NAME");
        return 0;
    }
}

# Health check: HTTPS Connectivity
sub check_https_connectivity {
    my $http_code = qx(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$DOMAIN_NAME/" 2>/dev/null);
    chomp $http_code;
    
    if ($? == 0 && $http_code eq "200") {
        log_message('INFO', "HTTPS connectivity successful (HTTP $http_code)");
        return 1;
    } elsif ($http_code) {
        log_message('ERROR', "HTTPS connectivity failed (HTTP $http_code)");
        return 0;
    } else {
        log_message('ERROR', "HTTPS connectivity failed (connection error)");
        return 0;
    }
}

# Health check: SSL Certificate
sub check_ssl_certificate {
    my $ssl_cmd = "echo | openssl s_client -servername '$DOMAIN_NAME' -connect '$DOMAIN_NAME:443' 2>/dev/null | openssl x509 -noout -dates 2>/dev/null";
    my $ssl_result = qx($ssl_cmd);
    
    if ($? == 0 && $ssl_result =~ /notAfter=(.+)/) {
        log_message('INFO', "SSL certificate valid until: $1");
        return 1;
    } else {
        log_message('ERROR', "SSL certificate check failed");
        return 0;
    }
}

# Health check: Application Response
sub check_application_response {
    my $response = qx(curl -s --max-time 10 "https://$DOMAIN_NAME/" 2>/dev/null);
    
    if ($? == 0) {
        if ($response =~ /Jitsi Meet/i) {
            log_message('INFO', "Application responding correctly (Jitsi Meet detected)");
            return 1;
        } else {
            log_message('ERROR', "Application not responding correctly (Jitsi Meet not detected)");
            return 0;
        }
    } else {
        log_message('ERROR', "Application not responding");
        return 0;
    }
}

# Main function
sub main {
    log_message('INFO', "Starting Jitsi Platform Health Check");
    log_message('INFO', "Target: $DOMAIN_NAME");
    log_message('INFO', "Cluster: $CLUSTER_NAME");
    log_message('INFO', "Service: $SERVICE_NAME");
    print "\n";
    
    # Run all health checks
    run_health_check("ECS Service Status", \&check_ecs_service_status);
    run_health_check("Task Health Status", \&check_task_health);
    run_health_check("Load Balancer Targets", \&check_load_balancer_targets);
    run_health_check("DNS Resolution", \&check_dns_resolution);
    run_health_check("HTTPS Connectivity", \&check_https_connectivity);
    run_health_check("SSL Certificate", \&check_ssl_certificate);
    run_health_check("Application Response", \&check_application_response);
    
    print "\n";
    log_message('INFO', "Health Check Summary:");
    log_message('INFO', "Passed: $HEALTH_CHECKS_PASSED/$HEALTH_CHECKS_TOTAL checks");
    
    if ($HEALTH_CHECKS_PASSED == $HEALTH_CHECKS_TOTAL) {
        log_message('SUCCESS', "All health checks passed - Platform is healthy!");
        exit 0;
    } else {
        my $failed_checks = $HEALTH_CHECKS_TOTAL - $HEALTH_CHECKS_PASSED;
        log_message('ERROR', "$failed_checks health check(s) failed - Platform needs attention");
        exit 1;
    }
}

# Script entry point
main() if __FILE__ eq $0;