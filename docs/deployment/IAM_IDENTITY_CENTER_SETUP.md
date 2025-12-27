# IAM Identity Center Setup for Jitsi Hosting

## Overview

This guide explains how to configure AWS IAM Identity Center (formerly AWS SSO) for the Jitsi video hosting platform. This is a **generic guide** - see your private ops repository for environment-specific configuration details.

## Common Issue: ForbiddenException After SSO Login

If `aws sso login` succeeds but you get "ForbiddenException: No access" when running AWS commands:

**Root Cause**: Your IAM Identity Center user/group is not assigned to the required permission set for your AWS account. The SSO login succeeds (authentication works) but GetRoleCredentials fails (authorization missing).

## Fix Required in IAM Identity Center

### Step 1: Access IAM Identity Center Console

Navigate to: `https://console.aws.amazon.com/singlesignon/home?region=<your-region>`

**Important**: You'll need to log in with an account that has administrative access to IAM Identity Center (typically the management/root account).

### Step 2: Assign Permission Set to User/Group

1. **Navigate to AWS Accounts**:
   - Click "AWS accounts" in left navigation
   - Find your target AWS account (infrastructure account)
   - Click on the account number

2. **Check Current Assignments**:
   - Go to "Permission sets" tab
   - Look for your required permission set (e.g., "AdministratorAccess")
   - Check if your user/group is listed under "Users and groups"

3. **Assign Permission Set**:
   - Click "Assign users or groups" button
   - Select your IAM Identity Center user or group
   - Choose appropriate permission set (AdministratorAccess or custom)
   - Click "Next" → "Submit"

4. **Wait for Propagation**:
   - Allow 1-2 minutes for assignment to propagate
   - AWS will send confirmation when complete

## Permission Set Requirements

The `AdministratorAccess` permission set should include these services for Jitsi:

| Service | Permissions | Purpose |
|---------|-------------|---------|
| **ECS** | `ecs:*` | Manage clusters, services, tasks |
| **EC2** | `ec2:*` | VPC, subnets, security groups, network interfaces |
| **ELB** | `elasticloadbalancing:*` | Network load balancers, target groups |
| **SSM** | `ssm:*` | Parameter Store for secrets |
| **S3** | `s3:*` | Recording storage bucket |
| **CloudWatch** | `logs:*`, `cloudwatch:*` | Logging and monitoring |
| **IAM** | `iam:PassRole` | ECS task execution role |
| **Service Discovery** | `servicediscovery:*` | ECS Service Connect namespace |
| **Secrets Manager** | `secretsmanager:*` | Legacy secrets (migration target) |

## Verification Steps

After assignment is complete:

```bash
# Step 1: Logout to clear cached credentials
aws sso logout --profile <your-profile>

# Step 2: Login again to get new credentials
aws sso login --profile <your-profile>

# Step 3: Verify access works
aws sts get-caller-identity --profile <your-profile>
```

**Expected Success Output**:
```json
{
    "UserId": "AROA...:username",
    "Account": "<your-account-id>",
    "Arn": "arn:aws:sts::<your-account-id>:assumed-role/<PermissionSet>/username"
}
```

## Alternative: Create Custom Permission Set

If AdministratorAccess is too broad, create a custom permission set:

1. **In IAM Identity Center Console**:
   - Click "Permission sets" → "Create permission set"
   - Choose "Custom permission set"
   - Name: `JitsiPlatformAccess`

2. **Attach Policy** (choose one):

   **Option A - AWS Managed Policies**:
   - `AmazonECS_FullAccess`
   - `AmazonVPCFullAccess`
   - `ElasticLoadBalancingFullAccess`
   - `AmazonSSMFullAccess`
   - `AmazonS3FullAccess`
   - `CloudWatchLogsFullAccess`

   **Option B - Inline Policy**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ecs:*",
           "ec2:*",
           "elasticloadbalancing:*",
           "ssm:*",
           "s3:*",
           "logs:*",
           "cloudwatch:*",
           "servicediscovery:*",
           "iam:PassRole"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

3. **Assign to User/Group**:
   - Same process as above, but choose `JitsiPlatformAccess`

## Debugging Commands

If access still fails after assignment:

```bash
# Check SSO cache files
ls -la ~/.aws/sso/cache/

# Verify SSO session token
cat ~/.aws/sso/cache/*.json | jq '{startUrl, expiresAt}'

# Check profile configuration
aws configure list --profile <your-profile>

# Detailed debug output
aws sts get-caller-identity --profile <your-profile> --debug 2>&1 | grep -i forbidden
```

## AWS Profile Configuration Format

**Profile**: `~/.aws/config`
```ini
[profile <your-profile-name>]
sso_session = <sso-session-name>
sso_account_id = <your-aws-account-id>
sso_role_name = <permission-set-name>
region = <your-region>
output = json

[sso-session <sso-session-name>]
sso_start_url = <your-sso-start-url>
sso_region = <your-region>
sso_registration_scopes = sso:account:access
```

**See your private ops repository** for environment-specific configuration values.

**Note**: If "ForbiddenException" occurs, the issue is in IAM Identity Center permission assignment, not profile configuration.

## Next Steps

1. **Immediate**: Contact AWS administrator for account 215665149509
2. **Request**: Assign your IAM Identity Center user/group to AdministratorAccess permission set
3. **Verify**: Run verification commands above after assignment
4. **Deploy**: Proceed with [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) once access confirmed

## Additional Resources

- **AWS Documentation**: https://docs.aws.amazon.com/singlesignon/latest/userguide/
- **IAM Identity Center Console**: `https://console.aws.amazon.com/singlesignon/home?region=<your-region>`
- **Private Ops Repo**: See your organization's private ops repository for environment-specific details

## If Managed by Organization Admin

1. Provide this document to your AWS account administrator
2. Request: "Assign my user to [PermissionSet] for account [AccountID]"
3. Include: Your IAM Identity Center username and business justification

---

**Common Issue**: ForbiddenException after successful SSO login  
**Fix Location**: IAM Identity Center Console → AWS Accounts → Permission Set Assignment  
**Estimated Fix Time**: 5 minutes (by admin with appropriate access)
