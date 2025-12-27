# Jitsi Video Platform - Complete Deployment Guide

This guide provides step-by-step instructions for deploying the Jitsi Meet video conferencing platform on AWS using domain-agnostic configuration.

## Prerequisites

### Required Tools

```bash
# Install required tools (macOS)
brew install terraform awscli perl cpanminus jq

# Install Perl dependencies
cpanm JSON Term::ANSIColor
```

### AWS Requirements

1. **AWS Account**: Active AWS account with billing enabled
2. **Domain Name**: Registered domain (e.g., `meet.yourdomain.com`)
3. **SSL Certificate**: Valid certificate in AWS Certificate Manager for your domain
4. **IAM Identity Center**: Configured AWS SSO profile (see [IAM_IDENTITY_CENTER_SETUP.md](IAM_IDENTITY_CENTER_SETUP.md))

## Step 1: Repository Setup

### Clone Public Repository

```bash
cd ~/Code/Projects/  # or your preferred location
git clone https://github.com/BryanChasko/jitsi-video-hosting.git
cd jitsi-video-hosting
```

### Create Private Operations Repository

**Important**: Create your own private repository for sensitive configuration.

```bash
# On GitHub, create a private repository (e.g., "jitsi-ops")

cd ~/Code/Projects/
git clone https://github.com/your-username/jitsi-ops.git
```

**Verify structure** (repos must be siblings):
```bash
ls -la ~/Code/Projects/
  jitsi-video-hosting/    # Public repo
  jitsi-ops/              # Your private repo
```

## Step 2: Configure AWS Authentication

### Set Up IAM Identity Center Profile

Follow [IAM_IDENTITY_CENTER_SETUP.md](IAM_IDENTITY_CENTER_SETUP.md) to:
1. Configure AWS SSO profile in `~/.aws/config`
2. Get permission set assigned by admin
3. Authenticate via `aws sso login`

**Example profile** (`~/.aws/config`):
```ini
[profile your-aws-profile]
sso_session = your-sso-session
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
region = us-west-2
output = json

[sso-session your-sso-session]
sso_start_url = https://d-xxxxxxxxxx.awsapps.com/start
sso_region = us-west-2
sso_registration_scopes = sso:account:access
```

### Authenticate

```bash
aws sso login --profile your-aws-profile
aws sts get-caller-identity --profile your-aws-profile
```

**Expected Output**:
```json
{
  "UserId": "AROA...:username",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_AdministratorAccess_.../username"
}
```

**If you see "ForbiddenException: No access"**: Your user is not assigned to the AdministratorAccess permission set. See [IAM_IDENTITY_CENTER_SETUP.md](IAM_IDENTITY_CENTER_SETUP.md) for resolution steps.

## Step 3: Create Configuration File

### Copy Template and Customize

```bash
cd ~/Code/Projects/jitsi-ops/

# Copy template from public repo
cp ../jitsi-video-hosting/config.json.template config.json

# Edit with YOUR values
vim config.json
```

**Your `config.json`**:
```json
{
  "domain": "meet.yourdomain.com",
  "aws_profile": "your-aws-profile",
  "aws_region": "us-west-2",
  "project_name": "jitsi-video-platform",
  "environment": "prod",
  "cluster_name": "jitsi-video-platform-cluster",
  "service_name": "jitsi-video-platform-service",
  "nlb_name": "jitsi-video-platform-nlb"
}
```

**Save sensitive details** in your private repo:
```bash
cd ~/Code/Projects/jitsi-ops/

# Create IAM config reference
cat > IAM_IDENTITY_CENTER_CONFIG.md << 'EOF'
# IAM Identity Center Configuration

**SSO Start URL**: https://d-xxxxxxxxxx.awsapps.com/start
**AWS Account ID**: 123456789012
**Permission Set**: AdministratorAccess
**Profile Name**: your-aws-profile

See public repo for generic setup guide.
EOF

# Commit to private repo
git add .
git commit -m "Initial Jitsi platform configuration"
git push origin main
```

### Verify Configuration Loading

```bash
cd ~/Code/Projects/jitsi-video-hosting

# Test config loads correctly
perl -I lib -e "use JitsiConfig; my \$config = JitsiConfig->new(); print \$config->domain() . \"\n\";"
# Should output: meet.yourdomain.com

perl -I lib -e "use JitsiConfig; my \$config = JitsiConfig->new(); print \$config->aws_profile() . \"\n\";"
# Should output: your-aws-profile
```

## Step 4: Configure Domain and SSL Certificate

Edit `main.tf` - Update certificate ARN:

```hcl
resource "aws_lb_listener" "jitsi_https_tls" {
  # ... other config ...
  certificate_arn = "arn:aws:acm:us-west-2:YOUR-ACCOUNT:certificate/YOUR-CERT-ID"
}
```

### DNS Configuration

Create DNS A record pointing your domain to the load balancer:
- **Type**: A (Alias)
- **Name**: meet.yourdomain.com
- **Target**: Load balancer DNS name (from Terraform output)

## Step 3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

**Expected Output**: Infrastructure deployment takes 5-10 minutes.

## Step 4: Verify Deployment

```bash
# Setup operational scripts
cd scripts/
./setup.pl

# Run comprehensive test
./test-platform.pl
```

## Step 5: Test Video Calls

1. **Scale Up**: `./scripts/scale-up.pl`
2. **Open Browser**: Navigate to `https://meet.yourdomain.com`
3. **Create Room**: Enter room name (e.g., "test-meeting")
4. **Join Call**: Click "Join" - should see video interface
5. **Test Features**: Enable camera/microphone, test audio/video
6. **Scale Down**: `./scripts/scale-down.pl` (saves costs)

## Architecture Overview

### AWS Resources Created

- **VPC**: Custom VPC with public subnets
- **ECS Cluster**: Fargate cluster for containers
- **Load Balancer**: Network Load Balancer with SSL termination
- **Security Groups**: Ports 443/TCP, 10000/UDP, 80/TCP
- **S3 Bucket**: Video recording storage (encrypted)
- **Secrets Manager**: Secure credential storage
- **CloudWatch**: Logging and monitoring

### Container Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   jitsi-web     │    │     prosody     │
│   (nginx)       │    │   (XMPP server) │
│   Port: 80,443  │    │   Port: 5222    │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
┌─────────────────┐  │  ┌─────────────────┐
│     jicofo      │  │  │      jvb        │
│  (conference    │  │  │ (video bridge)  │
│   focus)        │  │  │  Port: 10000    │
└─────────────────┘  │  └─────────────────┘
                     │
              ┌─────────────┐
              │ Load Balancer│
              │   (NLB)      │
              └─────────────┘
```

## Operational Commands

### Daily Operations

```bash
# Start platform for meeting
./scripts/scale-up.pl

# Check platform status
./scripts/status.pl

# Verify health
./scripts/check-health.pl

# Stop platform (cost savings)
./scripts/scale-down.pl
```

### Monitoring

```bash
# View logs
aws logs describe-log-groups --profile jitsi-dev

# Check service status
aws ecs describe-services --cluster jitsi-video-platform-cluster \
  --services jitsi-video-platform-service --profile jitsi-dev

# Monitor costs
aws ce get-cost-and-usage --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY --metrics BlendedCost --profile jitsi-dev
```

## Troubleshooting

### Common Issues

#### "You have been disconnected"
- **Cause**: WebSocket connectivity issues
- **Solution**: Already fixed in current deployment (task definition revision 4+)
- **Verify**: Check JVB logs for WebSocket errors

#### Container startup failures
- **Cause**: Secrets Manager permissions
- **Solution**: Verify IAM role has `secretsmanager:GetSecretValue` permission
- **Check**: `aws iam get-role-policy --role-name jitsi-video-platform-ecs-task-execution-role`

#### SSL certificate errors
- **Cause**: Invalid or expired certificate
- **Solution**: Update certificate ARN in `main.tf`
- **Verify**: Certificate must be in same region (us-west-2)

### Debug Commands

```bash
# Check container logs
aws logs get-log-events --log-group-name /ecs/jitsi-video-platform \
  --log-stream-name "jvb/jvb/TASK-ID" --profile jitsi-dev

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn TARGET-GROUP-ARN --profile jitsi-dev

# Force new deployment
aws ecs update-service --cluster jitsi-video-platform-cluster \
  --service jitsi-video-platform-service --force-new-deployment --profile jitsi-dev
```

## Security Considerations

### Production Hardening

1. **Authentication**: Implement secure domain setup (see PRODUCTION_OPTIMIZATION.md)
2. **Network**: Restrict security group access to known IPs
3. **Secrets**: Rotate secrets regularly
4. **Monitoring**: Enable CloudTrail and GuardDuty
5. **Backup**: Regular S3 bucket backups

### Cost Optimization

- **Scale-to-Zero**: Use operational scripts to stop when not needed
- **Reserved Instances**: Consider for consistent usage
- **S3 Lifecycle**: Configure automatic deletion of old recordings
- **CloudWatch**: Set up billing alerts

## Next Steps

1. **Test with Multiple Users**: Invite colleagues to test video calls
2. **Implement Authentication**: Follow PRODUCTION_OPTIMIZATION.md
3. **Set Up Monitoring**: Configure CloudWatch dashboards
4. **Automate Scaling**: Consider scheduled scaling based on usage patterns
5. **Backup Strategy**: Implement configuration and data backup procedures

## Support

- **Documentation**: See README.md and other guides in this repository
- **Logs**: Check CloudWatch logs for detailed error information
- **AWS Support**: Use AWS Support for infrastructure issues
- **Jitsi Community**: Jitsi Meet documentation and forums for application issues

---

**Deployment Status**: ✅ Fully Operational  
**Last Updated**: September 2025  
**Platform URL**: https://meet.awsaerospace.org (example)