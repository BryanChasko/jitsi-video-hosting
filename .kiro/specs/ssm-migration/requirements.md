# SSM Parameter Store Migration Specification

## Overview
Migrate Jitsi authentication secrets from AWS Secrets Manager ($0.40/month) to SSM Parameter Store SecureString (free tier) to achieve true scale-to-zero costs.

## Current State
- **Resource**: `aws_secretsmanager_secret.jitsi_secrets`
- **Cost**: $0.40/secret/month (fixed, even at zero scale)
- **Secrets stored**:
  - `jicofo_component_secret`
  - `jicofo_auth_password`
  - `jvb_component_secret`
  - `jvb_auth_password`
  - `jigasi_auth_password`

## Target State
- **Resource**: `aws_ssm_parameter` (SecureString type)
- **Cost**: $0.00/month (free tier: 10,000 standard parameters)
- **API Cost**: $0.05 per 10,000 API calls (only when running)

## Requirements

### REQ-1: Create SSM Parameters
- [ ] Create 5 SSM SecureString parameters for each Jitsi secret
- [ ] Use naming convention: `/${var.project_name}/jitsi/{secret_name}`
- [ ] Use AWS-managed KMS key (alias/aws/ssm) for encryption (free)
- [ ] Apply standard tags: Project, Environment

### REQ-2: Update IAM Policies
- [ ] Update `aws_iam_role_policy.ecs_task_execution_secrets` for SSM access
- [ ] Update `aws_iam_role_policy.ecs_task_policy` for SSM access
- [ ] Add permissions: `ssm:GetParameter`, `ssm:GetParameters`
- [ ] Scope to parameter path: `arn:aws:ssm:${region}:${account}:parameter/${project}/*`

### REQ-3: Update ECS Task Definition
- [ ] Change container secrets from `secretsmanager` to `ssm` valueFrom format
- [ ] Update all 5 secret references in Jitsi containers (prosody, jicofo, jvb)
- [ ] Verify container environment variable mapping unchanged

### REQ-4: Remove Secrets Manager Resources
- [ ] Remove `aws_secretsmanager_secret.jitsi_secrets`
- [ ] Remove `aws_secretsmanager_secret_version.jitsi_secrets`
- [ ] Remove Secrets Manager permissions from IAM policies

### REQ-5: Update Cost Analysis Script
- [ ] Update `scripts/cost-analysis.pl` to reflect $0 secrets cost
- [ ] Update cost comparison documentation

### REQ-6: Migration Safety
- [ ] Ensure existing secrets can be recreated (using random_password resources)
- [ ] Provide rollback instructions
- [ ] Test with `terraform plan` before apply

## Acceptance Criteria
1. All Jitsi containers start successfully with SSM-sourced secrets
2. Secrets Manager resources fully removed from Terraform state
3. Monthly fixed cost reduced from $0.40 to $0.00 for secrets
4. No changes to Jitsi functionality or security posture

## Cost Impact
| Component | Before | After |
|-----------|--------|-------|
| Secrets Manager | $0.40/month | $0.00 |
| SSM Parameter Store | $0.00 | $0.00 (free tier) |
| SSM API Calls | N/A | ~$0.001/month (est. 200 calls) |
| **Total Savings** | | **$0.40/month** |

## Technical Notes

### SSM Parameter ValueFrom Format
```hcl
secrets = [
  {
    name      = "JICOFO_AUTH_PASSWORD"
    valueFrom = "arn:aws:ssm:${region}:${account}:parameter/${project}/jitsi/jicofo_auth_password"
  }
]
```

### SSM Parameter Resource
```hcl
resource "aws_ssm_parameter" "jicofo_auth_password" {
  name        = "/${var.project_name}/jitsi/jicofo_auth_password"
  description = "Jicofo authentication password"
  type        = "SecureString"
  value       = random_password.jicofo_auth_password.result
  
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
```

### IAM Policy for SSM
```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:GetParameter",
    "ssm:GetParameters"
  ],
  "Resource": "arn:aws:ssm:*:*:parameter/${project_name}/*"
}
```
