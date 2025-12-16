#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use lib '../lib';
use JitsiConfig;

# Load configuration
my $config = JitsiConfig->new();
my $region = $config->aws_region();
my $profile = $config->aws_profile();
my $project_name = $config->project_name();

print "\033[34m[INFO]\033[0m Verifying Jitsi Platform Power-Down Status\n";
print "=" x 60 . "\n";

# Check what should be deleted
my %checks = (
    "ECS Cluster" => {
        cmd => "aws ecs describe-clusters --clusters " . $config->cluster_name() . " --region $region --profile $profile --query 'clusters[0].status' --output text 2>/dev/null",
        expect => "not_found"
    },
    "ECS Service" => {
        cmd => "aws ecs describe-services --cluster " . $config->cluster_name() . " --services " . $config->service_name() . " --region $region --profile $profile --query 'services[0].status' --output text 2>/dev/null", 
        expect => "not_found"
    },
    "CloudWatch Log Group" => {
        cmd => "aws logs describe-log-groups --log-group-name-prefix '/ecs/$project_name' --region $region --profile $profile --query 'logGroups[0].logGroupName' --output text 2>/dev/null",
        expect => "not_found"
    },
    "VPC" => {
        cmd => "aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=$project_name-vpc' --region $region --profile $profile --query 'Vpcs[0].VpcId' --output text 2>/dev/null",
        expect => "not_found"
    },
    "Security Groups" => {
        cmd => "aws ec2 describe-security-groups --filters 'Name=tag:Project,Values=$project_name' --region $region --profile $profile --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null",
        expect => "not_found"
    }
);

# Check what should be preserved
my %preserve_checks = (
    "S3 Bucket" => {
        cmd => "aws s3api head-bucket --bucket jitsi-video-platform-recordings-c098795f --region $region --profile $profile 2>/dev/null && echo 'exists'",
        expect => "exists"
    },
    "Secrets Manager" => {
        cmd => "aws secretsmanager describe-secret --secret-id $project_name-jitsi-secrets --region $region --profile $profile --query 'Name' --output text 2>/dev/null",
        expect => "exists"
    }
);

print "\033[34m[DELETED RESOURCES]\033[0m (should not exist)\n";
my $all_deleted = 1;
for my $resource (sort keys %checks) {
    my $result = `$checks{$resource}{cmd}`;
    chomp($result) if $result;
    
    if (!$result || $result eq "None" || $result eq "" || $? != 0) {
        print "  \033[32m✓\033[0m $resource: DELETED\n";
    } else {
        print "  \033[31m✗\033[0m $resource: STILL EXISTS ($result)\n";
        $all_deleted = 0;
    }
}

print "\n\033[34m[PRESERVED RESOURCES]\033[0m (should exist)\n";
my $all_preserved = 1;
for my $resource (sort keys %preserve_checks) {
    my $result = `$preserve_checks{$resource}{cmd}`;
    chomp($result) if $result;
    
    if ($result && $result ne "None" && $result ne "" && $? == 0) {
        print "  \033[32m✓\033[0m $resource: PRESERVED\n";
    } else {
        print "  \033[31m✗\033[0m $resource: MISSING\n";
        $all_preserved = 0;
    }
}

print "\n" . "=" x 60 . "\n";

if ($all_deleted && $all_preserved) {
    print "\033[32m[SUCCESS]\033[0m Power-down verification PASSED\n";
    print "\033[34m[INFO]\033[0m All resources in expected state\n";
    print "\033[34m[INFO]\033[0m Monthly cost reduced to ~\$2-5 (S3 + Secrets only)\n";
    exit 0;
} else {
    print "\033[31m[FAILURE]\033[0m Power-down verification FAILED\n";
    if (!$all_deleted) {
        print "\033[31m[ERROR]\033[0m Some resources still exist that should be deleted\n";
    }
    if (!$all_preserved) {
        print "\033[31m[ERROR]\033[0m Some resources missing that should be preserved\n";
    }
    exit 1;
}
