# AWS Setup Guide

## Current Configuration (December 2025)

### Jitsi Hosting Account
- **Account ID**: `215665149509`
- **AWS Profile**: `jitsi-hosting`
- **Region**: `us-west-2`
- **IAM Identity Center**:
  - Instance ID: `ssoins-7907a9f3d93386c6`
  - SSO Portal URL: `https://d-9267ec26ec.awsapps.com/start`
  - User: `bryanchasko-aws-ug-jitsi-hosting`
  - Group: `builders`
  - Permission Set: `AdministratorAccess`

### AWS CLI Configuration

```bash
# Add to ~/.aws/config (if not already present)
[sso-session jitsi-hosting-org]
sso_start_url = https://d-9267ec26ec.awsapps.com/start
sso_region = us-west-2
sso_registration_scopes = sso:account:access

[profile jitsi-hosting]
sso_session = jitsi-hosting-org
sso_account_id = 215665149509
sso_role_name = AdministratorAccess
region = us-west-2
output = json
```

```bash
# Login to SSO
aws sso login --sso-session jitsi-hosting-org

# Verify credentials
aws sts get-caller-identity --profile jitsi-hosting
```

---

## AWS IAM Identity Center Setup 🔑 (For New Deployments)

### 1. Enable Identity Center
1. Log into your AWS root account
2. Navigate to IAM Identity Center service
3. Follow steps to enable it (creates default user portal URL)

### 2. Create Permission Set

**Permission Set Details:**
- **Name:** `Jitsi-Developer`
- **Description:** `Development access for Jitsi video platform infrastructure`
- **Session Duration:** 1 hour
- **Tags:**
  - `Project`: `jitsi-video-platform`
  - `Environment`: `production`
  - `Purpose`: `video-conferencing`

**Required AWS Managed Policies:**
- `AmazonVPCFullAccess` - VPC and networking resources
- `AmazonECS_FullAccess` - ECS Fargate services  
- `ElasticLoadBalancingFullAccess` - Network Load Balancer
- `AmazonS3FullAccess` - Video storage
- `SecretsManagerReadWrite` - Application secrets
- `AWSCertificateManagerFullAccess` - TLS certificates
- `IAMFullAccess` - IAM role creation
- `CloudWatchLogsFullAccess` - Log group management

### 3. Create Users and Groups
1. **Create User:**
   - Username: `bryan-chasko-jitsi` (or your equivalent)
   - Display name: `Bryan Chasko (Jitsi Platform)`
   - Email: Your email address
   - Password: Send email invitation

2. **Create Group:**
   - Group name: `jitsi-developers`
   - Description: `Developers with access to Jitsi video platform infrastructure`
   - Add your user to this group

### 4. Assign Access
1. Go to **AWS accounts** in IAM Identity Center
2. Select your target account
3. Click **Assign users or groups**
4. Select the `jitsi-developers` group
5. Select the `Jitsi-Developer` permission set
6. Click **Submit**

## Local Environment Configuration 💻

### 1. Install AWS CLI
Ensure you have the latest AWS CLI installed.

### 2. Configure SSO Profile
```bash
aws configure sso
```

**Configuration Values:**
- **SSO session name:** `jitsi-dev`
- **SSO Start URL:** Your Identity Center user portal URL
- **SSO Region:** `us-west-2`
- **SSO registration scopes:** `sso:account:access` (default)
- **AWS Account:** Your target account (auto-selected)
- **AWS Role:** `Jitsi-Developer` (auto-selected)
- **Default client Region:** `us-west-2`
- **CLI default output format:** `json`
- **Profile Name:** `jitsi-dev`

### 3. Verification
```bash
aws sts get-caller-identity --profile jitsi-dev
```

The output should show your federated user ARN, confirming successful SSO setup.

## Terraform Deployment

### Prerequisites
Install Terraform:
```bash
brew install terraform
```

### Deploy Base Infrastructure

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Plan deployment:**
   ```bash
   terraform plan
   ```

3. **Deploy infrastructure:**
   ```bash
   terraform apply
   ```

### Deployed Resources
The infrastructure includes:

**Network Foundation:**
- **VPC:** `vpc-0acc250e205ebcdf7` with CIDR `10.0.0.0/16`
- **Public Subnets:** 
  - `subnet-081cf3bdaa824df9b` in `us-west-2a` (`10.0.1.0/24`)
  - `subnet-0664d061583a06615` in `us-west-2b` (`10.0.2.0/24`)
- **Internet Gateway:** `igw-0784c626ea98fac10`

**Load Balancing & Security:**
- **Network Load Balancer:** `jitsi-video-platform-nlb-6005dd61c01ffd11.elb.us-west-2.amazonaws.com`
- **Security Group:** `sg-0c9e4f020335150f5` (ports 443 TCP, 10000 UDP)
- **Target Groups:**
  - HTTPS: `jitsi-video-platform-https-tg`
  - JVB UDP: `jitsi-video-platform-jvb-tg`

**Container Platform (Scale-to-Zero):**
- **ECS Cluster:** `jitsi-video-platform-cluster`
- **ECS Service:** `jitsi-video-platform-service` (desired_count = 0)
- **Task Definition:** `jitsi-video-platform-task:1`
- **S3 Bucket:** `jitsi-video-platform-recordings-4c2967df`

**Deployment Commands:**
```bash
terraform plan -out=tfplan
terraform apply tfplan
```