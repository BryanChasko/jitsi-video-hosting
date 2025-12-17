#!/usr/bin/env perl
use strict;
use warnings;
use JSON;
use Term::ANSIColor qw(colored);
use lib '../lib';
use JitsiConfig;

# Dynamic Jitsi Deployment with Rotating Domains
# 
# This script:
# 1. Generates a new random subdomain
# 2. Requests ACM certificate for the domain
# 3. Updates DNS records
# 4. Deploys Jitsi infrastructure
# 5. Sends email notification with new URL

print colored("[INFO] Jitsi Dynamic Domain Deployment\n", 'cyan');
print "=" x 60 . "\n";

my $config = JitsiConfig->new();
my $profile = $config->aws_profile();
my $region = $config->aws_region();

# Step 1: Generate new random domain
print colored("[STEP 1] Generating random subdomain...\n", 'yellow');
my $new_domain = `perl -I lib scripts/generate-domain.pl`;
chomp($new_domain);

if ($new_domain eq "" || $new_domain !~ /^meet\.[a-f0-9]{8}\.bryanchasko\.com$/) {
    print colored("[ERROR] Failed to generate valid domain\n", 'red');
    exit 1;
}

print colored("[SUCCESS] Generated domain: $new_domain\n", 'green');

# Step 2: Update configuration
print colored("\n[STEP 2] Updating configuration...\n", 'yellow');

my $ops_dir = "../jitsi-video-hosting-ops";
my $config_file = "$ops_dir/config.json";

if (! -f $config_file) {
    print colored("[ERROR] Config file not found: $config_file\n", 'red');
    exit 1;
}

# Read current config
open(my $fh, '<', $config_file) or die "Cannot read $config_file: $!\n";
my $config_json = do { local $/; <$fh> };
close($fh);

my $config_data = decode_json($config_json);
my $old_domain = $config_data->{domain};

# Update domain
$config_data->{domain} = $new_domain;

# Write updated config
open($fh, '>', $config_file) or die "Cannot write $config_file: $!\n";
print $fh JSON->new->pretty->encode($config_data);
close($fh);

print colored("[SUCCESS] Updated config: $old_domain -> $new_domain\n", 'green');

# Step 3: Request ACM certificate
print colored("\n[STEP 3] Requesting ACM certificate...\n", 'yellow');
print colored("[INFO] This requires manual DNS validation\n", 'cyan');
print colored("[INFO] You will need to add CNAME records to validate the certificate\n", 'cyan');

my $cert_output = `aws acm request-certificate --domain-name $new_domain --validation-method DNS --profile $profile --region $region --output json 2>&1`;

if ($? != 0) {
    print colored("[ERROR] Failed to request certificate\n", 'red');
    print $cert_output;
    exit 1;
}

my $cert_data = decode_json($cert_output);
my $cert_arn = $cert_data->{CertificateArn};

print colored("[SUCCESS] Certificate requested: $cert_arn\n", 'green');
print colored("[INFO] Waiting 10 seconds for certificate to be created...\n", 'cyan');
sleep(10);

# Get validation records
my $describe_output = `aws acm describe-certificate --certificate-arn $cert_arn --profile $profile --region $region --output json 2>&1`;

if ($? == 0) {
    my $describe_data = decode_json($describe_output);
    my $validation_options = $describe_data->{Certificate}->{DomainValidationOptions};
    
    if ($validation_options && @$validation_options > 0) {
        print colored("\n[ACTION REQUIRED] Add these DNS records to validate certificate:\n", 'yellow');
        print "=" x 60 . "\n";
        
        foreach my $option (@$validation_options) {
            if ($option->{ResourceRecord}) {
                print "Name:  " . $option->{ResourceRecord}->{Name} . "\n";
                print "Type:  " . $option->{ResourceRecord}->{Type} . "\n";
                print "Value: " . $option->{ResourceRecord}->{Value} . "\n";
                print "-" x 60 . "\n";
            }
        }
        
        print colored("\n[INFO] Add these records to Route 53 in the account hosting bryanchasko.com\n", 'cyan');
        print colored("[INFO] Certificate ARN saved for deployment: $cert_arn\n", 'cyan');
    }
}

# Save certificate ARN for deployment
my $cert_file = "$ops_dir/current_certificate_arn.txt";
open($fh, '>', $cert_file) or die "Cannot write $cert_file: $!\n";
print $fh $cert_arn;
close($fh);

# Step 4: Wait for certificate validation
print colored("\n[STEP 4] Waiting for certificate validation...\n", 'yellow');
print colored("[INFO] Press Enter after you've added the DNS validation records...\n", 'cyan');
<STDIN>;

print colored("[INFO] Checking certificate status...\n", 'cyan');

my $max_attempts = 30;
my $attempt = 0;
my $validated = 0;

while ($attempt < $max_attempts && !$validated) {
    $attempt++;
    print colored("[INFO] Attempt $attempt/$max_attempts - Checking validation status...\n", 'cyan');
    
    my $status_output = `aws acm describe-certificate --certificate-arn $cert_arn --profile $profile --region $region --query 'Certificate.Status' --output text 2>&1`;
    chomp($status_output);
    
    if ($status_output eq "ISSUED") {
        $validated = 1;
        print colored("[SUCCESS] Certificate validated!\n", 'green');
    } elsif ($status_output =~ /error/i) {
        print colored("[ERROR] Failed to check certificate status\n", 'red');
        print $status_output;
        exit 1;
    } else {
        print colored("[INFO] Status: $status_output (waiting...)\n", 'yellow');
        sleep(10);
    }
}

if (!$validated) {
    print colored("[ERROR] Certificate validation timed out\n", 'red');
    print colored("[INFO] You can complete deployment manually once validated\n", 'cyan');
    print colored("[INFO] Certificate ARN: $cert_arn\n", 'cyan');
    exit 1;
}

# Step 5: Send notification
print colored("\n[STEP 5] Sending email notification...\n", 'yellow');
system("perl -I lib scripts/notify-domain.pl $new_domain");

# Step 6: Deploy infrastructure
print colored("\n[STEP 6] Ready to deploy infrastructure\n", 'yellow');
print colored("[INFO] Certificate: $cert_arn\n", 'cyan');
print colored("[INFO] Domain: $new_domain\n", 'cyan');
print colored("\n[NEXT STEPS]\n", 'yellow');
print "1. Update main.tf with certificate ARN: $cert_arn\n";
print "2. Run: terraform plan -var=\"domain_name=$new_domain\"\n";
print "3. Run: terraform apply\n";
print "4. Run: ./scripts/scale-up.pl\n";
print "\n";
print colored("[SUCCESS] Dynamic domain deployment prepared!\n", 'green');
