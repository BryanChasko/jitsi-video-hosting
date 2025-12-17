#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use lib '../lib';
use JitsiConfig;

# Send email notification when new domain is created
# Usage: ./notify-domain.pl <domain-name>

my $domain = $ARGV[0] or die "Usage: $0 <domain-name>\n";
my $config = JitsiConfig->new();
my $profile = $config->aws_profile();
my $region = $config->aws_region();

# Email configuration
my $email_to = "bryanj\@abstractspacecraft.com";
my $sns_topic_name = "jitsi-domain-notifications";

print "[INFO] Sending domain notification for: $domain\n";

# Check if SNS topic exists
my $topic_arn = `aws sns list-topics --profile $profile --region $region --query 'Topics[?contains(TopicArn, \`$sns_topic_name\`)].TopicArn' --output text 2>&1`;
chomp($topic_arn);

if ($topic_arn eq "" || $topic_arn =~ /error/i) {
    print "[INFO] Creating SNS topic: $sns_topic_name\n";
    
    # Create SNS topic
    my $create_output = `aws sns create-topic --name $sns_topic_name --profile $profile --region $region --output json 2>&1`;
    
    if ($? != 0) {
        print "[ERROR] Failed to create SNS topic\n";
        print $create_output;
        exit 1;
    }
    
    my $create_data = decode_json($create_output);
    $topic_arn = $create_data->{TopicArn};
    print "[INFO] Created SNS topic: $topic_arn\n";
    
    # Subscribe email
    print "[INFO] Subscribing email: $email_to\n";
    my $subscribe_output = `aws sns subscribe --topic-arn $topic_arn --protocol email --notification-endpoint $email_to --profile $profile --region $region 2>&1`;
    
    if ($? != 0) {
        print "[ERROR] Failed to subscribe email\n";
        print $subscribe_output;
    } else {
        print "[INFO] Subscription request sent - check email to confirm\n";
    }
}

# Send notification
my $timestamp = localtime();
my $message = <<EOF;
New Jitsi Video Platform Domain Created

Domain: $domain
Timestamp: $timestamp
Region: $region
Profile: $profile

Access your Jitsi instance at:
https://$domain

This domain will remain active until the platform is scaled down.

Note: This is an automated notification from the Jitsi video hosting platform.
EOF

my $subject = "New Jitsi Domain: $domain";

# Publish to SNS
print "[INFO] Publishing notification to SNS...\n";
my $publish_output = `aws sns publish --topic-arn $topic_arn --subject "$subject" --message "$message" --profile $profile --region $region 2>&1`;

if ($? != 0) {
    print "[ERROR] Failed to publish notification\n";
    print $publish_output;
    exit 1;
}

print "[SUCCESS] Domain notification sent to $email_to\n";
