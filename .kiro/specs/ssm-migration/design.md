# SSM Parameter Store Migration Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    BEFORE (Secrets Manager)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ECS Task ──► Secrets Manager ──► KMS (AWS-managed)             │
│              ($0.40/secret/mo)                                   │
│                                                                  │
│  Cost: $0.40/month (fixed, even at zero scale)                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    AFTER (SSM Parameter Store)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ECS Task ──► SSM Parameter Store ──► KMS (AWS-managed)         │
│               (Free tier)             (Free default key)         │
│                                                                  │
│  Cost: $0.00/month + $0.05/10K API calls                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Changes

### 1. Terraform Resources

#### Remove:
- `aws_secretsmanager_secret.jitsi_secrets`
- `aws_secretsmanager_secret_version.jitsi_secrets`

#### Add:
- `aws_ssm_parameter.jicofo_component_secret`
- `aws_ssm_parameter.jicofo_auth_password`
- `aws_ssm_parameter.jvb_component_secret`
- `aws_ssm_parameter.jvb_auth_password`
- `aws_ssm_parameter.jigasi_auth_password`

#### Modify:
- `aws_iam_role_policy.ecs_task_execution_secrets` → SSM permissions
- `aws_iam_role_policy.ecs_task_policy` → SSM permissions
- `aws_ecs_task_definition.jitsi` → SSM valueFrom format

### 2. Parameter Naming Convention

```
/${project_name}/jitsi/jicofo_component_secret
/${project_name}/jitsi/jicofo_auth_password
/${project_name}/jitsi/jvb_component_secret
/${project_name}/jitsi/jvb_auth_password
/${project_name}/jitsi/jigasi_auth_password
```

### 3. ECS Secret Reference Format

**Before (Secrets Manager):**
```hcl
secrets = [
  {
    name      = "JICOFO_AUTH_PASSWORD"
    valueFrom = "${aws_secretsmanager_secret.jitsi_secrets.arn}:jicofo_auth_password::"
  }
]
```

**After (SSM Parameter Store):**
```hcl
secrets = [
  {
    name      = "JICOFO_AUTH_PASSWORD"
    valueFrom = aws_ssm_parameter.jicofo_auth_password.arn
  }
]
```

### 4. IAM Policy Changes

**Before:**
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "${secrets_manager_arn}"
}
```

**After:**
```json
{
  "Effect": "Allow",
  "Action": [
    "ssm:GetParameter",
    "ssm:GetParameters"
  ],
  "Resource": "arn:aws:ssm:${region}:${account_id}:parameter/${project_name}/*"
}
```

## Migration Strategy

### Phase 1: Create SSM Parameters (Non-destructive)
1. Add new SSM parameter resources to main.tf
2. Run `terraform plan` to verify
3. Run `terraform apply` to create SSM parameters

### Phase 2: Update ECS Task Definition
1. Update IAM policies to include SSM permissions (keep Secrets Manager temporarily)
2. Update ECS task definition to use SSM parameters
3. Run `terraform apply`
4. Verify containers start correctly

### Phase 3: Remove Secrets Manager
1. Remove Secrets Manager permissions from IAM
2. Remove `aws_secretsmanager_secret` resources
3. Run `terraform apply`
4. Verify no orphaned resources

### Rollback Plan
If issues occur after Phase 2:
1. Revert ECS task definition to use Secrets Manager ARN
2. Run `terraform apply`
3. Containers will use existing Secrets Manager values

## Security Considerations

| Aspect | Secrets Manager | SSM SecureString |
|--------|-----------------|------------------|
| Encryption | KMS | KMS |
| Access Control | IAM | IAM |
| Audit | CloudTrail | CloudTrail |
| Rotation | Built-in | Manual/Lambda |
| Cross-Region | Replication | Manual |

**Note**: For this use case (randomly generated passwords at deploy time), automatic rotation is not needed. Passwords are regenerated on infrastructure recreation.

## Testing Plan

1. **Pre-migration**: Verify current state with `./scripts/status.pl`
2. **Post-Phase 1**: Verify SSM parameters created in AWS Console
3. **Post-Phase 2**: Scale up and verify Jitsi containers start
4. **Post-Phase 3**: Verify Secrets Manager resources removed
5. **Full test**: Run `./scripts/test-platform.pl`
