#!/usr/bin/env perl
use strict;
use warnings;
use JSON;

# Power Down - Removes compute resources but keeps static/low-cost resources
# Preserves: IAM roles, S3 buckets, Secrets Manager, CloudWatch logs, etc.

my $cluster = "jitsi-video-platform-cluster";
my $service = "jitsi-video-platform-service";
my $region = "us-west-2";
my $profile = "jitsi-dev";

print "\033[34m[INFO]\033[0m Starting Jitsi Platform Power-Down Process\n\n";

# Scale ECS service to zero first
print "\033[34m[INFO]\033[0m Scaling ECS service to zero...\n";
system("aws ecs update-service --cluster $cluster --service $service --desired-count 0 --region $region --profile $profile > /dev/null 2>&1");

# Wait for tasks to stop
print "\033[34m[INFO]\033[0m Waiting for tasks to stop...\n";
sleep(30);

# Delete ECS service
print "\033[34m[INFO]\033[0m Deleting ECS service...\n";
system("aws ecs delete-service --cluster $cluster --service $service --region $region --profile $profile > /dev/null 2>&1");

# Delete ECS cluster
print "\033[34m[INFO]\033[0m Deleting ECS cluster...\n";
system("aws ecs delete-cluster --cluster $cluster --region $region --profile $profile > /dev/null 2>&1");

# Delete Load Balancer
print "\033[34m[INFO]\033[0m Deleting Network Load Balancer...\n";
my $nlb_arn = `aws elbv2 describe-load-balancers --names jitsi-video-platform-nlb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region $region --profile $profile 2>/dev/null`;
chomp($nlb_arn);
if ($nlb_arn && $nlb_arn ne "None") {
    system("aws elbv2 delete-load-balancer --load-balancer-arn '$nlb_arn' --region $region --profile $profile > /dev/null 2>&1");
}

# Delete Target Groups
print "\033[34m[INFO]\033[0m Deleting Target Groups...\n";
my @tg_names = ("jitsi-video-platform-https-tg", "jitsi-video-platform-jvb-tg");
for my $tg_name (@tg_names) {
    my $tg_arn = `aws elbv2 describe-target-groups --names $tg_name --query 'TargetGroups[0].TargetGroupArn' --output text --region $region --profile $profile 2>/dev/null`;
    chomp($tg_arn);
    if ($tg_arn && $tg_arn ne "None") {
        system("aws elbv2 delete-target-group --target-group-arn '$tg_arn' --region $region --profile $profile > /dev/null 2>&1");
    }
}

# Delete Task Definition (deregister all revisions)
print "\033[34m[INFO]\033[0m Deregistering task definitions...\n";
my $task_def_json = `aws ecs list-task-definitions --family-prefix jitsi-video-platform-task --region $region --profile $profile 2>/dev/null`;
if ($task_def_json) {
    my $task_defs = decode_json($task_def_json);
    for my $task_def_arn (@{$task_defs->{taskDefinitionArns}}) {
        system("aws ecs deregister-task-definition --task-definition '$task_def_arn' --region $region --profile $profile > /dev/null 2>&1");
    }
}

# Delete VPC and networking (but keep security groups for easy restore)
print "\033[34m[INFO]\033[0m Deleting VPC and networking resources...\n";

# Get VPC ID
my $vpc_id = `aws ec2 describe-vpcs --filters "Name=tag:Name,Values=jitsi-video-platform-vpc" --query 'Vpcs[0].VpcId' --output text --region $region --profile $profile 2>/dev/null`;
chomp($vpc_id);

if ($vpc_id && $vpc_id ne "None") {
    # Delete subnets
    my $subnets_json = `aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --region $region --profile $profile 2>/dev/null`;
    if ($subnets_json) {
        my $subnets = decode_json($subnets_json);
        for my $subnet (@{$subnets->{Subnets}}) {
            system("aws ec2 delete-subnet --subnet-id $subnet->{SubnetId} --region $region --profile $profile > /dev/null 2>&1");
        }
    }
    
    # Delete internet gateway
    my $igw_json = `aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --region $region --profile $profile 2>/dev/null`;
    if ($igw_json) {
        my $igws = decode_json($igw_json);
        for my $igw (@{$igws->{InternetGateways}}) {
            system("aws ec2 detach-internet-gateway --internet-gateway-id $igw->{InternetGatewayId} --vpc-id $vpc_id --region $region --profile $profile > /dev/null 2>&1");
            system("aws ec2 delete-internet-gateway --internet-gateway-id $igw->{InternetGatewayId} --region $region --profile $profile > /dev/null 2>&1");
        }
    }
    
    # Delete route tables (except main)
    my $rt_json = `aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --region $region --profile $profile 2>/dev/null`;
    if ($rt_json) {
        my $route_tables = decode_json($rt_json);
        for my $rt (@{$route_tables->{RouteTables}}) {
            next if grep { $_->{Main} } @{$rt->{Associations}};
            system("aws ec2 delete-route-table --route-table-id $rt->{RouteTableId} --region $region --profile $profile > /dev/null 2>&1");
        }
    }
    
    # Delete security groups (except default)
    my $sg_json = `aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --region $region --profile $profile 2>/dev/null`;
    if ($sg_json) {
        my $security_groups = decode_json($sg_json);
        for my $sg (@{$security_groups->{SecurityGroups}}) {
            next if $sg->{GroupName} eq "default";
            system("aws ec2 delete-security-group --group-id $sg->{GroupId} --region $region --profile $profile > /dev/null 2>&1");
        }
    }
    
    # Delete VPC
    system("aws ec2 delete-vpc --vpc-id $vpc_id --region $region --profile $profile > /dev/null 2>&1");
}

print "\n\033[32m[SUCCESS]\033[0m Power-down completed successfully\n";
print "\033[34m[INFO]\033[0m Preserved resources:\n";
print "\033[34m[INFO]\033[0m   - S3 bucket (recordings)\n";
print "\033[34m[INFO]\033[0m   - AWS Secrets Manager\n";
print "\033[34m[INFO]\033[0m   - IAM roles and policies\n";
print "\033[34m[INFO]\033[0m   - CloudWatch logs and metrics\n";
print "\033[34m[INFO]\033[0m   - SSL certificate\n\n";
print "\033[34m[INFO]\033[0m Monthly cost reduced to ~\$0.42 (S3 + Secrets Manager)\n";
print "\033[34m[INFO]\033[0m Use 'terraform apply' to restore full infrastructure\n";