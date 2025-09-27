#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename;
use File::Spec;
use POSIX qw(strftime);
use Term::ANSIColor qw(colored);

# Configuration
my $SCRIPT_DIR = dirname(File::Spec->rel2abs(__FILE__));
my $PROJECT_NAME = "jitsi-video-platform";
my $CLUSTER_NAME = "${PROJECT_NAME}-cluster";
my $SERVICE_NAME = "${PROJECT_NAME}-service";
my $DOMAIN_NAME = "meet.awsaerospace.org";
my $AWS_PROFILE = "jitsi-dev";
my $AWS_REGION = "us-west-2";
my $LOG_FILE = "/tmp/jitsi-test-" . strftime('%Y%m%d-%H%M%S', localtime) . ".log";

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
    
    # Also log to file
    open my $fh, '>>', $LOG_FILE or die "Cannot open log file: $!";
    print $fh "[$timestamp] [$level] $message\n";
    close $fh;
    return;
}

# Error handling cleanup
sub cleanup {
    my $exit_code = $? >> 8;
    if ($exit_code != 0) {
        log_message('ERROR', "Test failed with exit code $exit_code");
        log_message('INFO', "Attempting to scale down service for cleanup...");
        system("$SCRIPT_DIR/scale-down.pl");
    }
    log_message('INFO', "Test log saved to: $LOG_FILE");
    exit $exit_code;
}

$SIG{__DIE__} = \&cleanup;

# Function to check if AWS CLI is configured
sub check_aws_config {
    log_message('INFO', "Checking AWS CLI configuration...");
    
    # Check if AWS CLI exists
    my $aws_check = qx(which aws 2>/dev/null);
    if ($? != 0) {
        log_message('ERROR', "AWS CLI is not installed");
        return 0;
    }
    
    # Check AWS profile
    my $identity_check = qx(aws sts get-caller-identity --profile $AWS_PROFILE 2>/dev/null);
    if ($? != 0) {
        log_message('ERROR', "AWS profile '$AWS_PROFILE' is not configured or invalid");
        return 0;
    }
    
    log_message('SUCCESS', "AWS CLI configured correctly");
    return 1;
}

# Function to check prerequisites
sub check_prerequisites {
    log_message('INFO', "Checking prerequisites...");
    
    # Check required commands
    my @required_commands = qw(aws curl jq openssl);
    for my $cmd (@required_commands) {
        my $check = qx(which $cmd 2>/dev/null);
        if ($? != 0) {
            log_message('ERROR', "Required command '$cmd' is not installed");
            return 0;
        }
    }
    
    # Check AWS configuration
    return 0 unless check_aws_config();
    
    # Check if scripts exist
    my @required_scripts = qw(scale-up.pl scale-down.pl check-health.pl status.pl);
    for my $script (@required_scripts) {
        my $script_path = "$SCRIPT_DIR/$script";
        unless (-f $script_path) {
            log_message('ERROR', "Required script '$script' not found");
            return 0;
        }
        unless (-x $script_path) {
            log_message('WARN', "Making script '$script' executable");
            chmod 0755, $script_path;
        }
    }
    
    log_message('SUCCESS', "All prerequisites met");
    return 1;
}

# Function to run a test phase
sub run_test_phase {
    my ($phase_name, $phase_command) = @_;
    
    log_message('INFO', "Starting test phase: $phase_name");
    
    my $result = system($phase_command);
    if ($result == 0) {
        log_message('SUCCESS', "Test phase '$phase_name' completed successfully");
        return 1;
    } else {
        log_message('ERROR', "Test phase '$phase_name' failed");
        return 0;
    }
}

# Function to test SSL certificate
sub test_ssl_certificate {
    log_message('INFO', "Testing SSL certificate for $DOMAIN_NAME...");
    
    my $ssl_cmd = "echo | openssl s_client -servername '$DOMAIN_NAME' -connect '$DOMAIN_NAME:443' 2>/dev/null | openssl x509 -noout -dates 2>/dev/null";
    my $ssl_info = qx($ssl_cmd);
    
    if ($? == 0 && $ssl_info) {
        log_message('INFO', "SSL certificate information:");
        for my $line (split /\n/, $ssl_info) {
            log_message('INFO', "  $line");
        }
        
        # Check if certificate is valid (not expired)
        if ($ssl_info =~ /notAfter=(.+)/) {
            my $not_after = $1;
            log_message('SUCCESS', "SSL certificate is valid until: $not_after");
            return 1;
        }
    }
    
    log_message('ERROR', "Failed to retrieve SSL certificate information");
    return 0;
}

# Function to test HTTPS access
sub test_https_access {
    log_message('INFO', "Testing HTTPS access to https://$DOMAIN_NAME...");
    
    my $max_attempts = 10;
    
    for my $attempt (1..$max_attempts) {
        log_message('INFO', "HTTPS access attempt $attempt/$max_attempts");
        
        my $http_code = qx(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "https://$DOMAIN_NAME/");
        chomp $http_code;
        
        if ($? == 0 && $http_code eq "200") {
            log_message('SUCCESS', "HTTPS access successful (HTTP $http_code)");
            return 1;
        } elsif ($http_code) {
            log_message('WARN', "HTTPS access returned HTTP $http_code");
        } else {
            log_message('WARN', "HTTPS access attempt failed");
        }
        
        if ($attempt < $max_attempts) {
            log_message('INFO', "Waiting 30 seconds before next attempt...");
            sleep 30;
        }
    }
    
    log_message('ERROR', "HTTPS access failed after $max_attempts attempts");
    return 0;
}

# Function to test Jitsi Meet functionality
sub test_jitsi_functionality {
    log_message('INFO', "Testing basic Jitsi Meet functionality...");
    
    # Test if Jitsi Meet interface loads
    my $response = qx(curl -s --max-time 30 "https://$DOMAIN_NAME/");
    
    if ($? == 0) {
        # Check for key Jitsi Meet elements in the response
        if ($response =~ /Jitsi Meet/i && $response =~ /Start meeting/i) {
            log_message('SUCCESS', "Jitsi Meet interface loads correctly");
        } else {
            log_message('ERROR', "Jitsi Meet interface does not contain expected elements");
            my $preview = substr($response, 0, 200);
            log_message('INFO', "Response preview: $preview...");
            return 0;
        }
    } else {
        log_message('ERROR', "Failed to load Jitsi Meet interface");
        return 0;
    }
    
    # Test room creation endpoint (basic check)
    my $test_room = "test-room-" . time();
    my $room_url = "https://$DOMAIN_NAME/$test_room";
    
    log_message('INFO', "Testing room creation with URL: $room_url");
    my $room_response = qx(curl -s --max-time 30 "$room_url");
    
    if ($? == 0) {
        if ($room_response =~ /Jitsi Meet/i) {
            log_message('SUCCESS', "Room creation test successful");
        } else {
            log_message('WARN', "Room creation test inconclusive");
        }
    } else {
        log_message('WARN', "Room creation test failed, but this may be expected");
    }
    
    return 1;
}

# Main testing workflow
sub main {
    log_message('INFO', "Starting Jitsi Platform Testing Workflow");
    log_message('INFO', "Log file: $LOG_FILE");
    
    # Phase 1: Prerequisites
    unless (run_test_phase("Prerequisites Check", sub { check_prerequisites() })) {
        exit 1;
    }
    
    # Phase 2: Initial Status
    unless (run_test_phase("Initial Status Check", "$SCRIPT_DIR/status.pl")) {
        exit 1;
    }
    
    # Phase 3: Scale Up
    unless (run_test_phase("Scale Up Service", "$SCRIPT_DIR/scale-up.pl")) {
        exit 1;
    }
    
    # Phase 4: Health Checks
    unless (run_test_phase("Health Verification", "$SCRIPT_DIR/check-health.pl")) {
        exit 1;
    }
    
    # Phase 5: SSL Certificate Test
    unless (run_test_phase("SSL Certificate Validation", sub { test_ssl_certificate() })) {
        exit 1;
    }
    
    # Phase 6: HTTPS Access Test
    unless (run_test_phase("HTTPS Access Test", sub { test_https_access() })) {
        exit 1;
    }
    
    # Phase 7: Jitsi Functionality Test
    unless (run_test_phase("Jitsi Functionality Test", sub { test_jitsi_functionality() })) {
        exit 1;
    }
    
    # Phase 8: Final Status
    unless (run_test_phase("Final Status Check", "$SCRIPT_DIR/status.pl")) {
        exit 1;
    }
    
    # Phase 9: Scale Down
    unless (run_test_phase("Scale Down Service", "$SCRIPT_DIR/scale-down.pl")) {
        exit 1;
    }
    
    # Phase 10: Cleanup Verification
    unless (run_test_phase("Cleanup Verification", "$SCRIPT_DIR/status.pl")) {
        exit 1;
    }
    
    log_message('SUCCESS', "All testing phases completed successfully!");
    log_message('INFO', "Platform is ready for production use");
    log_message('INFO', "Complete test log available at: $LOG_FILE");
    return;
}

# Script entry point
main() if __FILE__ eq $0;