#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use lib '../lib';
use JitsiConfig;

# Load configuration from JitsiConfig
my $config = JitsiConfig->new();
my $project_name = "Jitsi Video Platform";
my $cluster_name = $config->cluster_name();
my $service_name = $config->service_name();
my $nlb_name = $config->nlb_name();
my $aws_profile = $config->aws_profile();

# Function to execute AWS CLI command and return JSON result
sub aws_cli_json {
    my ($command) = @_;
    my $full_command = "aws $command --profile $aws_profile --output json 2>/dev/null";
    my $output = `$full_command`;
    
    if ($? != 0) {
        return undef;
    }
    
    eval {
        return decode_json($output);
    };
    
    if ($@) {
        return undef;
    }
}

# Function to get ECS service status
sub get_ecs_service_status {
    my $result = aws_cli_json("ecs describe-services --cluster $cluster_name --services $service_name");
    
    if (!$result || !$result->{services} || @{$result->{services}} == 0) {
        return (0, 0, "Service not found");
    }
    
    my $service = $result->{services}->[0];
    my $desired_count = $service->{desiredCount} || 0;
    my $running_count = $service->{runningCount} || 0;
    
    return ($desired_count, $running_count, "OK");
}

# Function to get load balancer DNS name
sub get_load_balancer_dns {
    my $result = aws_cli_json("elbv2 describe-load-balancers");
    
    if (!$result || !$result->{LoadBalancers}) {
        return "Load balancer not found";
    }
    
    # Find the NLB by name pattern
    for my $lb (@{$result->{LoadBalancers}}) {
        if ($lb->{LoadBalancerName} && $lb->{LoadBalancerName} =~ /^$nlb_name/) {
            return $lb->{DNSName} || "DNS name not available";
        }
    }
    
    return "Load balancer not found";
}

# Function to determine status based on service counts
sub get_status_message {
    my ($desired, $running) = @_;
    
    if ($desired == 0 && $running == 0) {
        return "Scaled to zero";
    } elsif ($desired > 0 && $running == 0) {
        return "Starting up";
    } elsif ($desired > 0 && $running < $desired) {
        return "Scaling up";
    } elsif ($desired > 0 && $running == $desired) {
        return "Running";
    } elsif ($running > $desired) {
        return "Scaling down";
    } else {
        return "Unknown";
    }
}

# Main execution
print "Project: $project_name\n";

# Get ECS service status
my ($desired_count, $running_count, $service_status) = get_ecs_service_status();

if ($service_status ne "OK") {
    print "ECS Service: $service_name (Error: $service_status)\n";
    print "Load Balancer: Unable to retrieve\n";
    print "Status: Service unavailable\n";
    exit 1;
}

print "ECS Service: $service_name ($running_count/$desired_count running)\n";

# Get load balancer DNS name
my $lb_dns = get_load_balancer_dns();
print "Load Balancer: $lb_dns\n";

# Determine and display status
my $status = get_status_message($desired_count, $running_count);
print "Status: $status\n";

exit 0;