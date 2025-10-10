#!/usr/bin/env perl
use strict;
use warnings;

# Fully Destroy - Complete infrastructure teardown (equivalent to terraform destroy)
# WARNING: This removes EVERYTHING including S3 buckets, secrets, IAM roles, etc.

my $region = "us-west-2";
my $profile = "jitsi-dev";

print "\033[31m[WARNING]\033[0m This will COMPLETELY DESTROY all Jitsi platform infrastructure\n";
print "\033[31m[WARNING]\033[0m Including S3 buckets, secrets, IAM roles, and all data\n";
print "\033[33m[CONFIRM]\033[0m Type 'DESTROY' to confirm complete destruction: ";

my $confirmation = <STDIN>;
chomp($confirmation);

if ($confirmation ne "DESTROY") {
    print "\033[34m[INFO]\033[0m Operation cancelled\n";
    exit(0);
}

print "\n\033[34m[INFO]\033[0m Starting complete infrastructure destruction...\n\n";

# Run terraform destroy
print "\033[34m[INFO]\033[0m Running terraform destroy...\n";
my $result = system("terraform destroy -auto-approve");

if ($result == 0) {
    print "\n\033[32m[SUCCESS]\033[0m Complete infrastructure destruction completed\n";
    print "\033[34m[INFO]\033[0m All AWS resources have been removed\n";
    print "\033[34m[INFO]\033[0m Monthly cost: \$0.00\n";
    print "\033[34m[INFO]\033[0m Use 'terraform apply' to recreate from scratch\n";
} else {
    print "\n\033[31m[ERROR]\033[0m Terraform destroy failed\n";
    print "\033[34m[INFO]\033[0m Check terraform state and AWS console for remaining resources\n";
    exit(1);
}