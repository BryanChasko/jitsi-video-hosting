# AWS Profile Configuration for Jitsi ECS Project

## Required Profile
**Always use profile**: `jitsi-hosting`

## Authentication Setup
Before running any AWS operations, ensure the jitsi-hosting profile is authenticated:

```bash
# Check current authentication status
aws sts get-caller-identity --profile jitsi-hosting

# If authentication is needed, configure SSO
aws configure sso --profile jitsi-hosting

# Or login to existing SSO session
aws sso login --profile jitsi-hosting
```

## Project Commands
All Terraform and AWS CLI commands in this project should use the jitsi-hosting profile:

```bash
# Terraform operations
terraform plan -var="aws_profile=jitsi-hosting"
terraform apply -var="aws_profile=jitsi-hosting"

# AWS CLI operations
aws ecs describe-clusters --profile jitsi-hosting
aws elbv2 describe-load-balancers --profile jitsi-hosting

# Script operations (automatically use profile from JitsiConfig)
./scripts/scale-up.pl
./scripts/scale-down.pl
./scripts/cost-analysis.pl
```

## Environment Variables
Alternatively, set the profile as an environment variable:

```bash
export AWS_PROFILE=jitsi-hosting
export JITSI_AWS_PROFILE=jitsi-hosting
```

## Verification
Always verify you're using the correct profile before deployment:

```bash
aws sts get-caller-identity --profile jitsi-hosting
echo "Current AWS Profile: $AWS_PROFILE"
```
