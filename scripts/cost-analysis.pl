#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use lib '../lib';
use JitsiConfig;

my $config = JitsiConfig->new();
my $region = $config->aws_region();

print "\033[34m[INFO]\033[0m Jitsi Platform Cost Analysis\n";
print "=" x 60 . "\n";

# Cost breakdown (monthly estimates for us-west-2)
my %costs_before = (
    "ECS Fargate (4 vCPU, 8GB RAM)" => {
        cost => 0.198,  # per hour
        unit => "hour",
        monthly => 0.198 * 24 * 30,
        description => "When running (scale-to-zero when not used)"
    },
    "Network Load Balancer" => {
        cost => 0.0225,  # per hour
        unit => "hour", 
        monthly => 0.0225 * 24 * 30,
        description => "On-demand creation (only when platform is running)"
    },
    "CloudWatch Logs" => {
        cost => 0.50,
        unit => "GB/month",
        monthly => 0.50 * 1,  # Estimate 1GB/month
        description => "Log ingestion and storage"
    },
    "S3 Storage" => {
        cost => 0.023,
        unit => "GB/month", 
        monthly => 0.023 * 10,  # Estimate 10GB recordings
        description => "Recording storage"
    },
    "SSM Parameter Store" => {
        cost => 0.00,
        unit => "parameter/month",
        monthly => 0.00,
        description => "Jitsi configuration secrets (free tier)"
    },
    "Data Transfer" => {
        cost => 0.09,
        unit => "GB",
        monthly => 0.09 * 5,  # Estimate 5GB/month
        description => "Outbound data transfer"
    }
);

my %costs_after = (
    "S3 Storage" => {
        cost => 0.023,
        unit => "GB/month",
        monthly => 0.023 * 10,  # Same storage
        description => "Recording storage (preserved)"
    },
    "SSM Parameter Store" => {
        cost => 0.00,
        unit => "parameter/month", 
        monthly => 0.00,
        description => "Jitsi configuration secrets (free tier, preserved)"
    },
    "S3 Log Archive" => {
        cost => 0.004,
        unit => "GB/month",
        monthly => 0.004 * 2,  # Estimate 2GB archived logs
        description => "Archived CloudWatch logs in S3 IA"
    }
);

print "\033[34m[BEFORE POWER-DOWN]\033[0m (Full Infrastructure)\n";
my $total_before = 0;
for my $service (sort keys %costs_before) {
    my $cost = $costs_before{$service};
    printf "  %-35s \$%6.2f/%-8s (\$%6.2f/month) - %s\n", 
           $service, $cost->{cost}, $cost->{unit}, $cost->{monthly}, $cost->{description};
    $total_before += $cost->{monthly};
}
printf "\n  \033[1mTOTAL MONTHLY (when running):\033[0m \$%.2f\n", $total_before;
printf "  \033[1mTOTAL MONTHLY (scaled to zero):\033[0m \$%.2f\n", $total_before - $costs_before{"ECS Fargate (4 vCPU, 8GB RAM)"}{monthly};

print "\n\033[34m[AFTER POWER-DOWN]\033[0m (Minimal Infrastructure)\n";
my $total_after = 0;
for my $service (sort keys %costs_after) {
    my $cost = $costs_after{$service};
    printf "  %-35s \$%6.2f/%-8s (\$%6.2f/month) - %s\n",
           $service, $cost->{cost}, $cost->{unit}, $cost->{monthly}, $cost->{description};
    $total_after += $cost->{monthly};
}
printf "\n  \033[1mTOTAL MONTHLY:\033[0m \$%.2f\n", $total_after;

print "\n\033[34m[SAVINGS ANALYSIS]\033[0m\n";
my $compute_costs = $costs_before{"ECS Fargate (4 vCPU, 8GB RAM)"}{monthly} + $costs_before{"Network Load Balancer"}{monthly};
my $fixed_before = $total_before - $compute_costs;
my $savings = $fixed_before - $total_after;
my $savings_percent = ($savings / $fixed_before) * 100 if $fixed_before > 0;

printf "  Fixed costs before: \$%.2f/month\n", $fixed_before;
printf "  Fixed costs after:  \$%.2f/month\n", $total_after;
printf "  Monthly savings:    \$%.2f (%.0f%% reduction)\n", $savings, $savings_percent || 0;
printf "  Annual savings:     \$%.2f\n", $savings * 12;

print "\n\033[34m[ON-DEMAND USAGE SCENARIOS]\033[0m\n";
my $fargate_hourly = $costs_before{"ECS Fargate (4 vCPU, 8GB RAM)"}{cost};
my $nlb_hourly = $costs_before{"Network Load Balancer"}{cost};
my $combined_hourly = $fargate_hourly + $nlb_hourly;

printf "  Idle (powered down):           \$%.2f/month\n", $total_after;
printf "  Light usage (10 hours/month):  \$%.2f + \$%.2f = \$%.2f/month\n", 
       $total_after, $combined_hourly * 10, $total_after + ($combined_hourly * 10);
printf "  Medium usage (50 hours/month): \$%.2f + \$%.2f = \$%.2f/month\n",
       $total_after, $combined_hourly * 50, $total_after + ($combined_hourly * 50);
printf "  Heavy usage (200 hours/month): \$%.2f + \$%.2f = \$%.2f/month\n",
       $total_after, $combined_hourly * 200, $total_after + ($combined_hourly * 200);

print "\n\033[34m[ON-DEMAND MODEL BENEFITS]\033[0m\n";
printf "  Hourly compute cost: \$%.4f (ECS + NLB)\n", $combined_hourly;
printf "  Break-even point: %.0f hours/month vs always-on ALB\n", 16.20 / $combined_hourly;
printf "  Idle cost target: \$%.2f/month (achieved: \$%.2f)\n", 0.73, $total_after;

print "\n\033[34m[RESTORATION COST]\033[0m\n";
print "  Infrastructure restoration: \$0.00 (Terraform managed)\n";
print "  Scale-up time: 2-3 minutes (NLB + ECS)\n";
print "  Scale-down time: 1-2 minutes (ECS + NLB cleanup)\n";
print "  Data loss: None (S3 and SSM preserved)\n";

print "\n" . "=" x 60 . "\n";
print "\033[32m[RECOMMENDATION]\033[0m\n";
print "Power-down provides significant cost savings with minimal operational impact.\n";
print "Ideal for development/testing environments or infrequently used platforms.\n";
print "Quick restoration capability maintains operational flexibility.\n";
