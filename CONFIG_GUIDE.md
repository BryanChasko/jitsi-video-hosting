# Configuration Guide - Jitsi Video Hosting

This guide explains how to configure the Jitsi video hosting platform without exposing sensitive information in the public repository.

## The Problem We're Solving

The public repository should be **domain-agnostic** and **profile-agnostic**. You should be able to:
1. Fork/clone this repo
2. Point it to your own domain
3. Use your own AWS profile
4. Keep sensitive details private

## The Solution: JitsiConfig Module

We use a centralized `JitsiConfig` Perl module that implements **object-oriented configuration management** with a clear separation of concerns:

```
┌─────────────────────────┐
│   Public Repository     │
│  (jitsi-video-hosting)  │
│  - JitsiConfig module   │
│  - Terraform (generic)  │
│  - Scripts (generic)    │
└──────────────┬──────────┘
               │ Uses
┌──────────────▼──────────┐
│  Private Repository     │
│ (jitsi-video-hosting    │
│         -ops)           │
│  - config.json          │
│  (sensitive details)    │
└─────────────────────────┘
```

## Configuration Hierarchy

Configuration is loaded in this priority order (highest to lowest):

1. **Environment Variables** - `JITSI_*` prefixed
2. **Private config.json** - In `../jitsi-video-hosting-ops/config.json`
3. **Compiled Defaults** - In `lib/JitsiConfig.pm`

### Example: Overriding Domain

```bash
# Method 1: Via environment variable
export JITSI_DOMAIN="meet.mybusiness.com"
./scripts/status.pl

# Method 2: Via Terraform var
export TF_VAR_domain_name="meet.mybusiness.com"
terraform plan

# Method 3: Via config.json (permanent)
# Edit jitsi-video-hosting-ops/config.json
#   "domain": "meet.mybusiness.com"
./scripts/status.pl
```

## Setup for Your Own Deployment

### Prerequisites

- Public repo cloned: `jitsi-video-hosting/`
- AWS SSO profile configured (see [IAM_IDENTITY_CENTER_SETUP.md](IAM_IDENTITY_CENTER_SETUP.md))
- Domain name registered (e.g., `meet.yourdomain.com`)

### Step 1: Create Private Operations Repository

Create your own private repository to store sensitive configuration:

```bash
# On GitHub, create private repo: your-username/jitsi-ops
# Then clone it alongside the public repo

cd ~/Code/Projects/  # or your preferred location
git clone https://github.com/your-username/jitsi-ops.git

# Verify structure
ls -la
  jitsi-video-hosting/    # Public repo (this one)
  jitsi-ops/              # Your private repo
```

**Important**: The private repo must be a **sibling directory** to the public repo for the JitsiConfig module to find it.

### Step 2: Create Configuration File

```bash
cd jitsi-ops/

# Copy template from public repo
cp ../jitsi-video-hosting/config.json.template config.json

# Edit with your values
vim config.json  # or nano, code, etc.
```

**Your `config.json`**:
```json
{
  "domain": "meet.yourdomain.com",
  "aws_profile": "your-aws-profile-name",
  "aws_region": "us-west-2",
  "project_name": "jitsi-video-platform",
  "environment": "prod",
  "cluster_name": "jitsi-video-platform-cluster",
  "service_name": "jitsi-video-platform-service",
  "nlb_name": "jitsi-video-platform-nlb"
}
```

**Replace**:
- `meet.yourdomain.com` → Your actual domain
- `your-aws-profile-name` → Your AWS CLI profile (from Step 1 prerequisites)
- `us-west-2` → Your preferred AWS region (optional)

### Step 3: Protect Sensitive Information

Create additional private documentation in your ops repo:

```bash
cd jitsi-ops/

# Copy IAM Identity Center config template
cat > IAM_IDENTITY_CENTER_CONFIG.md << 'EOF'
# IAM Identity Center Configuration

**SSO Start URL**: https://d-xxxxxxxxxx.awsapps.com/start
**AWS Account ID**: 123456789012
**Permission Set**: AdministratorAccess
**Profile Name**: your-aws-profile-name

See public repo IAM_IDENTITY_CENTER_SETUP.md for setup instructions.
EOF

# Create operations guide
cat > OPERATIONS.md << 'EOF'
# Operations Guide - Your Organization

## Deployment Procedures
[Your specific procedures]

## Monitoring
[Your monitoring setup]

## Incident Response
[Your procedures]
EOF

# Commit to your private repo
git add .
git commit -m "Initial configuration for Jitsi platform"
git push origin main
```

### Step 4: Verify Configuration Loading

```bash
cd ~/Code/Projects/jitsi-video-hosting

# Test Perl scripts load config correctly
perl -I lib -e "use JitsiConfig; my \$config = JitsiConfig->new(); print \$config->domain() . \"\n\";"
# Should output: meet.yourdomain.com

# Test AWS profile
perl -I lib -e "use JitsiConfig; my \$config = JitsiConfig->new(); print \$config->aws_profile() . \"\n\";"
# Should output: your-aws-profile-name
```

### Step 5: Run Scripts and Terraform

From the public repo directory:

```bash
cd jitsi-video-hosting/

# Scripts automatically load from ../jitsi-video-hosting-ops/config.json
./scripts/status.pl

# Terraform requires explicit vars (use helper function)
# Option 1: Manually set env vars
export TF_VAR_domain_name="meet.yourdomain.com"
export TF_VAR_aws_profile="your-profile"

# Option 2: Use a helper to export from config
# (See Terraform Helper Script below)

terraform plan
```

## What Gets Configured

### Domain Name
- **Jitsi Web UI**: Served at your domain
- **SSL Certificate**: Must match your domain (created separately in AWS)
- **NLB Target**: Routes `your-domain` → Jitsi Web container
- **Health Checks**: Use your domain for HTTPS verification

### AWS Profile
- **Authentication**: All AWS CLI commands use this profile
- **Cross-Account**: If using separate infrastructure/DNS accounts
- **Credentials**: Sourced from `~/.aws/config` and `~/.aws/credentials`

### Resource Names
- **ECS Cluster**: `jitsi-video-platform-cluster`
- **ECS Service**: `jitsi-video-platform-service`
- **NLB**: `jitsi-video-platform-nlb`
- **S3 Bucket**: `jitsi-video-platform-recordings-*` (auto-suffix)

## Usage Examples

### For End Users (Non-Developers)

If someone gives you this repo, just configure your domain:

```bash
# In jitsi-video-hosting-ops/config.json
{
  "domain": "my-meetings.company.com",
  "aws_profile": "company-aws"
}

# Then run any script
./scripts/scale-up.pl
./scripts/test-platform.pl
./scripts/status.pl
```

### For CI/CD (GitHub Actions, etc.)

```yaml
env:
  TF_VAR_domain_name: ${{ secrets.JITSI_DOMAIN }}
  TF_VAR_aws_profile: ${{ secrets.AWS_PROFILE }}
  JITSI_AWS_PROFILE: ${{ secrets.AWS_PROFILE }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: terraform plan
      - run: ./scripts/scale-up.pl
```

### For Multiple Environments

You can maintain separate configs:

```bash
# Production
export JITSI_DOMAIN="meet.company.com"
export JITSI_AWS_PROFILE="prod-profile"

# Staging
export JITSI_DOMAIN="meet-staging.company.com"
export JITSI_AWS_PROFILE="staging-profile"

# Terraform automatically picks up TF_VAR_* or JITSI_* env vars
terraform plan
```

## Terraform Helper Script

For convenience, create a shell script to load config into Terraform:

```bash
#!/bin/bash
# In jitsi-video-hosting/scripts/load-config.sh

if [ -f "../jitsi-video-hosting-ops/config.json" ]; then
  export TF_VAR_domain_name=$(jq -r '.domain' ../jitsi-video-hosting-ops/config.json)
  export TF_VAR_aws_profile=$(jq -r '.aws_profile' ../jitsi-video-hosting-ops/config.json)
else
  echo "ERROR: config.json not found"
  exit 1
fi

# Now run terraform
terraform "$@"
```

Usage:
```bash
./scripts/load-config.sh plan
./scripts/load-config.sh apply
```

## Accessing Configuration from Code

### From Perl Scripts

```perl
use lib 'lib';
use JitsiConfig;

my $config = JitsiConfig->new();
my $domain = $config->domain();
my $profile = $config->aws_profile();
my $all_config = $config->all();
```

### From Terraform

All variables are defined in `variables.tf`:

```hcl
variable "domain_name" {
  description = "Domain name (from env var or config.json)"
  type        = string
  # Loaded from: TF_VAR_domain_name or JITSI_DOMAIN
}

variable "aws_profile" {
  description = "AWS profile (from env var or config.json)"
  type        = string
  # Loaded from: TF_VAR_aws_profile or JITSI_AWS_PROFILE
}
```

Use in resources:
```hcl
resource "aws_ecs_service" "jitsi" {
  name            = var.service_name
  cluster         = var.cluster_name
  # ...
}
```

### From Shell Scripts

```bash
# Source the config (requires jq)
DOMAIN=$(jq -r '.domain' ../jitsi-video-hosting-ops/config.json)
PROFILE=$(jq -r '.aws_profile' ../jitsi-video-hosting-ops/config.json)

aws ecs describe-services \
  --cluster jitsi-video-platform-cluster \
  --profile "$PROFILE" \
  --output json
```

## Security Best Practices

1. **Never commit** `config.json` to public repository
   - Add to `.gitignore`: `../jitsi-video-hosting-ops/config.json`

2. **Use private repositories** for `-ops` directories
   - GitHub: Set to Private
   - GitLab: Set to Private

3. **Limit access** to ops repository
   - Only trusted team members
   - Use branch protection rules

4. **Rotate credentials** regularly
   - AWS profile credentials (follow AWS best practices)
   - SSL certificates

5. **Audit configuration changes**
   - Track who modified domain or AWS settings
   - Review PRs before merging ops repo changes

## Troubleshooting

### "Missing required configuration" Error

```bash
# Check if config.json exists
ls -la ../jitsi-video-hosting-ops/config.json

# Validate JSON
jq . ../jitsi-video-hosting-ops/config.json

# Check required fields
jq '.domain, .aws_profile' ../jitsi-video-hosting-ops/config.json
```

### Scripts Can't Find Config

```bash
# Ensure you're in the correct directory
pwd
# Should output: .../jitsi-video-hosting

# Check parent directory structure
ls -la ../
# Should show: jitsi-video-hosting-ops/

# Test module loading
cd scripts
perl -I../lib -e 'use JitsiConfig; my $c = JitsiConfig->new(); print "Domain: " . $c->domain();'
```

### Terraform Can't Find Variables

```bash
# Check env vars are set
echo $TF_VAR_domain_name
echo $TF_VAR_aws_profile

# Or use JITSI_* vars (auto-converted by scripts)
export JITSI_DOMAIN="your.domain"
export JITSI_AWS_PROFILE="your-profile"

# Test terraform
terraform console
> var.domain_name
```

## For Public Contributors

If you're contributing to this public repository:

1. **Don't hardcode** domain names or AWS profiles
2. **Use variables** from `lib/JitsiConfig.pm`
3. **Document** any new configuration options
4. **Update** `lib/JitsiConfig.pm` if adding new settings
5. **Test** with environment variables, not hardcoded values

Example:
```perl
# GOOD: Uses JitsiConfig
use JitsiConfig;
my $config = JitsiConfig->new();
my $domain = $config->domain();

# BAD: Hardcoded
my $domain = "meet.bryanchasko.com";
```

## Next Steps

1. Set up your private `jitsi-video-hosting-ops` repository
2. Copy `config.json.template` to `config.json`
3. Edit with your domain and AWS profile
4. Run `./scripts/status.pl` to verify everything works
5. Proceed with Terraform deployment

---

For detailed operational procedures, see `../jitsi-video-hosting-ops/OPERATIONS.md`
