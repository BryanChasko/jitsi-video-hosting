# Operational Scripts

This directory contains operational scripts for managing the Jitsi platform.

## Available Scripts:

### Core Operations (Perl)
- `scale-up.pl` - Scale ECS service from 0 to 1 with health verification
- `scale-down.pl` - Scale ECS service from current count to 0 with verification
- `status.pl` - Display detailed current platform status
- `check-health.pl` - Comprehensive platform health verification
- `test-platform.pl` - Complete platform testing workflow

### Power Management (Perl)
- `power-down.pl` - **Full infrastructure teardown** - Deletes VPC, networking, ECS (keeps S3 + Secrets)
- `verify-power-down.pl` - Verify power-down completed successfully
- `cost-analysis.pl` - Calculate cost savings from power-down
- `test-idempotency.pl` - Test that power-down can run multiple times safely
- `fully-destroy.pl` - **DANGEROUS** - Destroy ALL resources including data

### Utility Scripts
- `setup.pl` - Make all scripts executable
- `project-status.pl` - Quick project status overview

## Usage:

### Daily Operations
```bash
# Check current status
./status.pl

# Scale up platform (start)
./scale-up.pl

# Verify health
./check-health.pl

# Scale down platform (stop, keep infrastructure)
./scale-down.pl
```

### Power Management (Cost Optimization)
```bash
# Full power-down (85% cost reduction: $16.62 → $2-5/month)
./power-down.pl

# Verify power-down succeeded
./verify-power-down.pl

# Analyze cost impact
./cost-analysis.pl

# Test idempotency (runs power-down twice)
./test-idempotency.pl

# Restore infrastructure
cd .. && terraform apply
```

### Complete Testing
```bash
# Run complete testing workflow
./test-platform.pl
```

## Requirements:
- AWS CLI with SSO configured (`jitsi-hosting` profile)
- JitsiConfig module (in `../lib/JitsiConfig.pm`)
- Proper IAM permissions for ECS, VPC, CloudWatch, S3, Secrets Manager
- For AWS operations: `eval $(aws configure export-credentials --profile jitsi-hosting --format env)`

## Power Management Features:
- ✅ **Resource Detection**: Checks existence before deletion
- ✅ **Error Handling**: Skips missing resources, doesn't fail
- ✅ **Idempotency**: Safe to run multiple times
- ✅ **Detailed Reporting**: Shows before/after state
- ✅ **CloudWatch Export**: Exports logs to S3 before deletion
- ✅ **Cost Analysis**: Reports estimated savings

## Resources Managed:

### Deleted on Power-Down:
- VPC + networking (subnets, route tables, internet gateway)
- Security groups
- ECS cluster and service
- CloudWatch log groups

### Preserved:
- S3 bucket: `jitsi-video-platform-recordings-*`
- Secrets Manager: `jitsi-video-platform-jitsi-secrets`

## Cost Impact:
| State | Monthly Cost |
|-------|--------------|
| Full Infrastructure | ~$16.62 |
| After Power-Down | ~$2-5 |
| Savings | 85% reduction |

All scripts include detailed logging and proper exit codes for automation integration.