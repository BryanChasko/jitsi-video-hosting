# Dynamic Domain Rotation for Jitsi

## Overview

This platform uses **dynamic domain rotation** for enhanced security. Each deployment generates a new random subdomain under `bryanchasko.com` and sends an email notification to `bryanj@abstractspacecraft.com`.

## Domain Format

```
meet.<8-char-hash>.bryanchasko.com
```

Examples:
- `meet.a7c3f8d2.bryanchasko.com`
- `meet.f4e9b1c6.bryanchasko.com`

## Workflow

### Automated Dynamic Deployment

```bash
cd scripts/
./dynamic-deploy.pl
```

**Process**:
1. ✅ Generates random 8-character hash subdomain
2. ✅ Updates private config.json with new domain
3. ✅ Requests ACM certificate for new domain
4. ✅ Provides DNS validation records (you add to Route 53)
5. ✅ Waits for certificate validation
6. ✅ Sends email notification to bryanj@abstractspacecraft.com
7. ✅ Prepares infrastructure for deployment

### Manual Step Required

After script generates DNS validation records, you must:

1. Log into AWS account hosting `bryanchasko.com`
2. Add CNAME records to Route 53 hosted zone
3. Wait for certificate validation (typically 5-10 minutes)
4. Press Enter in script to continue

### Email Notification

When domain is created, you receive email:

```
Subject: New Jitsi Domain: meet.a7c3f8d2.bryanchasko.com

New Jitsi Video Platform Domain Created

Domain: meet.a7c3f8d2.bryanchasko.com
Timestamp: Mon Dec 16 14:30:00 2025
Region: us-west-2

Access your Jitsi instance at:
https://meet.a7c3f8d2.bryanchasko.com
```

## Security Benefits

1. **Obscurity**: Random subdomains harder to discover
2. **Rotation**: New domain each deployment prevents persistent targeting
3. **Alerting**: Email notification tracks all domain creations
4. **Ephemeral**: Domain only exists while platform is running

## Individual Scripts

### Generate Domain Only

```bash
./generate-domain.pl
# Output: meet.a7c3f8d2.bryanchasko.com
```

### Send Notification Only

```bash
./notify-domain.pl meet.a7c3f8d2.bryanchasko.com
```

## SNS Setup (First Run Only)

On first notification, the script:
1. Creates SNS topic: `jitsi-domain-notifications`
2. Subscribes email: `bryanj@abstractspacecraft.com`
3. Sends confirmation email (click to confirm subscription)

**One-time action**: Check email and confirm SNS subscription.

## Deployment After Domain Creation

Once `dynamic-deploy.pl` completes:

```bash
# Get certificate ARN from output or file
cat ../../jitsi-video-hosting-ops/current_certificate_arn.txt

# Update main.tf with certificate ARN
# Then deploy:
cd ..
terraform plan -var="domain_name=$(perl -I lib -e 'use JitsiConfig; print JitsiConfig->new()->domain()')"
terraform apply

# Scale up platform
./scripts/scale-up.pl
```

## Route 53 Requirements

### DNS Account Access ✅ CONFIRMED

**Profile**: `aerospaceug-admin`  
**Account**: `211125425201`  
**Status**: AdministratorAccess working

**Available Hosted Zones**:
- `bryanchasko.com` (Zone ID: Z09216723VDB0N04DM9LL)
- `awsaerospace.org` (Zone ID: Z0850894B7N88RYS1UGO)

You have access to add:
1. ACM validation CNAME records
2. A/CNAME records pointing to NLB

### Two-Profile Workflow

**DNS Operations** (aerospaceug-admin):
```bash
# Add ACM validation records
aws route53 change-resource-record-sets \
  --hosted-zone-id Z09216723VDB0N04DM9LL \
  --profile aerospaceug-admin \
  --change-batch file://dns-changes.json

# Add A record for Jitsi domain
aws route53 change-resource-record-sets \
  --hosted-zone-id Z09216723VDB0N04DM9LL \
  --profile aerospaceug-admin \
  --change-batch file://jitsi-a-record.json
```

**Infrastructure Operations** (jitsi-hosting):
```bash
# Deploy ECS, VPC, NLB, S3
terraform apply -var="aws_profile=jitsi-hosting"
./scripts/scale-up.pl
```

## Troubleshooting

### Certificate Validation Fails

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:... \
  --profile jitsi-hosting \
  --region us-west-2
```

### Email Not Received

```bash
# Check SNS subscription status
aws sns list-subscriptions \
  --profile jitsi-hosting \
  --region us-west-2 \
  --query 'Subscriptions[?Protocol==`email`]'
```

### Domain Generation Issues

```bash
# Test domain generation
./generate-domain.pl
# Should output: meet.[8-hex-chars].bryanchasko.com
```

## Cost Impact

**Additional Costs**:
- SNS: $0 (within free tier for email notifications)
- Route 53: $0.50/month per hosted zone (if delegating subdomain)
- ACM Certificates: $0 (free for public certificates)

**No impact** on core idle cost target of $0.24/month.

## Security Considerations

✅ **Pros**:
- Harder to discover/target
- Domain rotation prevents persistent attacks
- Email audit trail of all deployments

⚠️ **Cons**:
- Manual DNS validation step required
- Users must receive new URL each deployment
- Certificate rotation complexity

**Recommendation**: For production, consider:
1. Automating DNS via Route 53 API
2. Using wildcard certificate: `*.meet.bryanchasko.com`
3. Storing domains in DynamoDB for history/rotation tracking
