# Jitsi Video Platform - Complete Deployment Guide

This guide provides step-by-step instructions for deploying the Jitsi Meet video conferencing platform on AWS.

## Prerequisites

### Required Tools

```bash
# Install required tools (macOS)
brew install terraform awscli perl cpanminus

# Install Perl dependencies
cpanm JSON Term::ANSIColor Perl::Critic
```

### AWS Setup

1. **AWS Account**: Active AWS account with billing enabled
2. **Domain**: Registered domain name (e.g., `meet.yourdomain.com`)
3. **SSL Certificate**: Valid SSL certificate in AWS Certificate Manager
4. **IAM Permissions**: Administrator access or specific permissions for:
   - ECS, VPC, Load Balancer, Route53, Secrets Manager, S3, CloudWatch

## Step 1: Clone and Configure

```bash
# Clone repository
git clone <repository-url>
cd jitsi-video-hosting

# Configure AWS profile
aws configure --profile jitsi-dev
# Enter your AWS Access Key ID, Secret, Region (us-west-2), Output format (json)
```

## Step 2: Update Configuration

### Update Domain and Certificate

Edit `variables.tf`:

```hcl
variable "domain_name" {
  description = "Domain name for Jitsi Meet"
  type        = string
  default     = "meet.yourdomain.com"  # Change this
}
```

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