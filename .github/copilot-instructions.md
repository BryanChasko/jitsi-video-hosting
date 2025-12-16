# Jitsi Video Hosting Platform - AI Agent Instructions

## Project Overview

On-demand Jitsi Meet video conferencing on AWS with **scale-to-zero cost optimization**.

**Important**: This is a public repository. All domain-specific and profile-specific configuration is stored in the **private** `jitsi-video-hosting-ops` repository. See `CONFIG_GUIDE.md` for details.

## Developer Preferences (CRITICAL)

### Language Priorities

1. **Rust** - Preferred for new tooling and performance-critical code
2. **Perl** - REQUIRED for automation scripts (never shell/bash)
3. **HCL** - Terraform configurations
4. **Markdown** - All documentation

### Configuration Philosophy

- **Public Repo**: Generic, domain-agnostic code and infrastructure definitions
- **Private Repo** (`jitsi-video-hosting-ops`): Domain names, AWS profiles, sensitive details
- **Abstraction**: `JitsiConfig` Perl module loads configuration from private repo
- **OOP Principles**: Configuration accessed via clean object interface, not hardcoded values

See `CONFIG_GUIDE.md` for implementation details.

### Tools & Philosophy

- **Editors**: VIM (terminal), Kiro CLI (AI-assisted)
- **Tooling > Creating**: Prefer implementing existing tools over building new
- **Agent-to-Agent**: Leverage MCP tooling and autonomous agent workflows
- **Scale-to-Zero**: ALL infrastructure must power down when idle
- **Data Format**: Markdown for docs, vectors for data (S3 Vectors compatible)
- **AWS Authentication**: ALWAYS use AWS SSO (`aws sso login`), credentials via temporary session tokens only

### Default AWS Profile - CRITICAL

**ALWAYS use profile `jitsi-hosting` for this project**

- All AWS CLI commands: `--profile jitsi-hosting`
- All Terraform commands: `-var="aws_profile=jitsi-hosting"`
- All Perl scripts: Automatically use via `JitsiConfig` module
- Profile config: `jitsi-video-hosting-ops/config.json`

**Verification**: `aws sts get-caller-identity --profile jitsi-hosting`

### Planning Philosophy: Costs & Metrics, Not Timelines

This project tracks:

- ✅ **Costs**: Monthly/hourly rates, savings, break-even points
- ✅ **Metrics**: Performance data, resource counts, technical measurements
- ✅ **TODOs**: Checkboxes `[ ]` for completion tracking
- ❌ **NO Timelines**: No quarters, sprints, deadlines, or estimates

**Examples**:

- ✅ "Cost: $0.24/month idle, $0.22/hour running, 96% savings"
- ✅ "TODO: [ ] Deploy SSM migration"
- ❌ "Q1 2026", "Estimated 2 weeks", "Due Friday"

### AWS SSO Authentication Policy

**CRITICAL**: This project uses AWS SSO exclusively for authentication.

**Recommended Practices**:

- ✅ Use `aws sso login --profile <profile-name>` for all authentication
- ✅ Use `--profile` flag with every AWS CLI command
- ✅ Export temporary credentials via `eval $(aws configure export-credentials --profile <profile> --format env)`
- ✅ Use short-lived session tokens (expired sessions require re-authentication)
- ✅ Store SSO configuration in `~/.aws/config` (never credentials in `~/.aws/credentials`)
- ✅ Use environment variables for tools requiring credential access (Terraform, Kiro CLI, scripts)

**SSO Setup**:

- Infrastructure account: `jitsi-hosting` profile (account: 215665149509)
- DNS/Domain account: `aerospaceug-admin` profile (account: 211125425201)
- SSO Portal: `https://d-9267ec26ec.awsapps.com/start`

**Standard SSO Workflow**:

```bash
# Clear stale sessions
aws sso logout --profile jitsi-hosting

# Authenticate (opens browser)
aws sso login --profile jitsi-hosting

# Verify authentication
aws sts get-caller-identity --profile jitsi-hosting

# For tools requiring environment variables (Kiro CLI, Terraform, etc.)
eval $(aws configure export-credentials --profile jitsi-hosting --format env)
```

**Troubleshooting**: If tools can't access SSO profiles directly, export credentials to environment variables using `aws configure export-credentials`. This provides temporary session tokens while maintaining SSO's security model.

### Documentation Updates Required

After significant changes, update:

1. `SESSION_CHANGELOG.md` - Track all Q/A session changes
2. `blog/BLOG_JITSI_ECS_EXPRESS.md` - Jitsi + ECS Express learnings
3. `blog/BLOG_KIRO_TERRAFORM.md` - Kiro CLI + Terraform learnings

## Critical Architecture Principles

### Scale-to-Zero Infrastructure

- **Default state**: ECS service runs at `desired_count = 0` (see `main.tf:883`)
- **Cost model**: $16.62/month fixed (NLB + S3 + Secrets), $0.198/hour when running
- **Never change** `desired_count` in Terraform - use operational scripts only
- Operational scripts handle scaling: `scale-up.pl`, `scale-down.pl`, `power-down.pl`

### Multi-Account AWS Setup

- **Infrastructure account**: `215665149509` (us-west-2, profile: `jitsi-hosting`)
  - SSO Instance: `ssoins-7907a9f3d93386c6`
  - SSO Portal: `https://d-9267ec26ec.awsapps.com/start`
  - Permission Set: `AdministratorAccess`
- **DNS/Domain account**: `211125425201` (us-east-2, profile: `aerospaceug-admin`)
- **Critical**: Cross-account SSL certificate validation requires manual DNS records
- See `OPERATIONS.md` for account-specific details (contains sensitive data - DO NOT COMMIT)

### Single-File Terraform Architecture

All infrastructure defined in `main.tf` (909 lines):

- VPC networking (lines 1-87): Custom VPC 10.0.0.0/16, multi-AZ public subnets
- Security groups (lines 88-142): HTTPS/443, JVB UDP/10000, TCP/4443, HTTP/80
- Load balancing (lines 144-233): Network Load Balancer with TLS termination
- Container platform (lines 236-909): ECS Fargate with 4 Jitsi containers
- Storage/secrets (lines 360-453): S3 recordings bucket, AWS Secrets Manager

**Key Variables** (loaded from environment or config.json):

- `aws_profile`: AWS CLI profile name (not hardcoded)
- `domain_name`: Jitsi domain (not hardcoded)

## Development Workflows

### Terraform Operations

```bash
# Infrastructure changes - ALWAYS use tfplan
terraform plan -out=tfplan
terraform apply tfplan

# State inspection (useful for debugging)
terraform state list
terraform state show aws_ecs_service.jitsi
```

**Never run**: `terraform apply` without `-out=tfplan` (production safety requirement)

### Operational Scripts (Perl)

All scripts in `scripts/` directory use `JitsiConfig` module for configuration:

- **JitsiConfig Module** (`lib/JitsiConfig.pm`): OOP interface for config management
- **Config Sources**: Environment variables, private config.json, defaults
- **Naming Convention**: Uses `$config->project_name()`, `$config->domain()`, etc.

**Primary scripts**:

- `test-platform.pl`: 10-phase testing workflow (prerequisites → scale → test → cleanup)
- `scale-up.pl`: Scale to 1 instance with health verification (10min timeout)
- `scale-down.pl`: Scale to 0 with verification
- `power-down.pl`: Delete compute resources, keep networking/storage (97% savings)
- `status.pl`: Detailed platform status (ECS, LB, tasks, health)

**Configuration is NOT hardcoded** - all scripts load from JitsiConfig module

### Testing Workflow

```bash
cd scripts/
./test-platform.pl  # Full 10-phase automated test
# Phases: prerequisites → status → scale-up → health → SSL → HTTPS → Jitsi → scale-down
```

## Project-Specific Conventions

### Configuration Constants

The codebase uses **JitsiConfig** module instead of hardcoding values:

**Perl scripts** (`lib/JitsiConfig.pm`):

```perl
use JitsiConfig;
my $config = JitsiConfig->new();
my $domain = $config->domain();
my $profile = $config->aws_profile();
my $cluster = $config->cluster_name();
```

**Terraform** (`variables.tf`):

```hcl
variable "domain_name" {
  # Loaded from env: TF_VAR_domain_name or JITSI_DOMAIN
}
variable "aws_profile" {
  # Loaded from env: TF_VAR_aws_profile or JITSI_AWS_PROFILE
}
```

**Configuration Sources** (in priority order):

1. Environment variables (`JITSI_*` or `TF_VAR_*`)
2. Private config file (`../jitsi-video-hosting-ops/config.json`)
3. Compiled defaults (in JitsiConfig.pm or variables.tf)

See `CONFIG_GUIDE.md` for full details.

### Jitsi Container Stack

Task definition contains 4 containers (see `main.tf:455-878`):

1. **jitsi-web**: Frontend (port 80), DISABLE_HTTPS=1 (NLB handles TLS)
2. **prosody**: XMPP server, internal auth domain `auth.meet.jitsi`
3. **jicofo**: Conference focus, health checks enabled
4. **jvb**: Video bridge, AWS-specific NAT traversal config (CRITICAL for AWS)

**JVB AWS Configuration** (lines 700-750):

- STUN servers for NAT traversal
- Private candidate filtering for AWS networking
- TCP harvester for fallback connectivity
- Colibri WebSocket for modern browsers

### Secrets Management

All secrets in AWS Secrets Manager (never hardcode):

```hcl
aws_secretsmanager_secret.jitsi_secrets -> {
  jicofo_component_secret, jicofo_auth_password,
  jvb_component_secret, jvb_auth_password
}
```

## Common Development Tasks

### Adding New Infrastructure Resources

1. Add to `main.tf` following existing naming: `${var.project_name}-resource-name`
2. Tag with: `Project = var.project_name`, `Environment = var.environment`
3. Add output to `outputs.tf` if needed by scripts
4. Update `DEPLOYMENT_GUIDE.md` if user-facing
5. **Never hardcode** domain or profile - use `var.domain_name` and `var.aws_profile`

### Modifying Container Configuration

1. Update environment variables in `main.tf` task definition
2. **Never hardcode** domain names - use `var.domain_name` interpolation
3. Test with: `terraform plan -out=tfplan && terraform apply tfplan`
4. Force new deployment: `aws ecs update-service --cluster ... --force-new-deployment`
5. Verify with: `./scripts/test-platform.pl`

### Adding Operational Scripts

Follow established patterns in existing scripts:

```perl
#!/usr/bin/env perl
use strict; use warnings;
use JSON; use Term::ANSIColor qw(colored);
use lib '../lib';
use JitsiConfig;

my $config = JitsiConfig->new();
my $domain = $config->domain();
my $profile = $config->aws_profile();
```

**Never hardcode** configuration values - always use JitsiConfig module.

### Documentation Structure

- `README.md`: High-level overview, cost analysis, service status
- `DEPLOYMENT_GUIDE.md`: Step-by-step new deployment
- `OPERATIONS.md`: Sensitive account/credential details (private repo)
- `TOOLING.md`: Development workflow, AI-assisted development
- `PRODUCTION_OPTIMIZATION.md`: Security, monitoring, performance enhancements
- `TESTING.md`: Test procedures and automation

## Integration Points

### Load Balancer → ECS Service

- NLB HTTPS listener (443) → Target Group → jitsi-web container (80)
- NLB JVB listener (10000 UDP) → Target Group → jvb container (10000)
- Health checks: HTTP on port 80 for HTTPS target group, TCP 443 for JVB

### DNS → Load Balancer

- CNAME: `meet.awsaerospace.org` → `jitsi-video-platform-nlb-*.elb.us-west-2.amazonaws.com`
- Managed in account `211125425201` (separate AWS profile)

### Container Networking

- Internal XMPP communication: containers on shared network namespace
- External access: Only through NLB (containers don't have public IPs directly exposed)

## Key Files Reference

- `main.tf`: All infrastructure (VPC, ECS, NLB, S3, Secrets Manager)
- `variables.tf`: Configuration variables (region, CPU/memory, domain)
- `outputs.tf`: Terraform outputs (VPC ID, subnets, LB DNS, etc.)
- `scripts/test-platform.pl`: Complete testing automation
- `OPERATIONS.md`: AWS accounts, resource IDs, DNS config (sensitive)

## Gotchas & Important Notes

1. **Scale-to-zero conflicts**: Never modify ECS `desired_count` in Terraform state
2. **Cross-account DNS**: SSL cert validation records must be created manually
3. **JVB NAT traversal**: AWS-specific config required (STUN, TCP fallback)
4. **NLB health checks**: Use HTTP/80 even though traffic is HTTPS (TLS terminates at NLB)
5. **Container startup**: Health checks have 60s start period (Jitsi initialization time)
6. **Profile switching**: Remember to use correct profile for DNS operations (`aerospaceug-admin`)

## Cost Optimization Mindset

When proposing changes, always consider:

- Will this increase fixed costs? (Currently $16.62/month)
- Does it maintain scale-to-zero capability?
- Can it be powered down with `power-down.pl`?

---

## Kiro CLI Integration

This project supports Kiro CLI for AI-assisted infrastructure development.

### Kiro Setup

```bash
# Install Kiro CLI
curl -fsSL https://cli.kiro.dev/install | bash

# Start Kiro in project directory
cd ~/Code/Projects/jitsi-video-hosting
kiro-cli
```

### Kiro Powers & MCP

We utilize Kiro **Powers** to inject specialized context and tools:

- **`aws-labs/ecs-express`**: (Active) Provides ECS Express Mode defaults and scale-to-zero patterns.
- **`hashicorp/terraform`**: (Reference) Provides Terraform Registry and HCP workspace management tools.

**MCP Servers** (Model Context Protocol) connect Kiro to external systems:

- **`aws-tools`**: For direct AWS resource management.

### Spec-Driven Workflow

Follow the structured Kiro workflow for all major changes:

1. **Specify**: `/specify "description"` -> Generates Requirements.
2. **Design**: Review generated `design.md`.
3. **Implement**: Execute steps from generated `tasks.md`.

### Key Kiro Commands for This Project

| Command                                 | Purpose                            |
| --------------------------------------- | ---------------------------------- |
| `/configure aws-sso --profile NAME`     | Set up AWS SSO authentication      |
| `/powers activate aws-labs/ecs-express` | Enable ECS Express Mode            |
| `/specify "description"`                | Create formal change specification |
| `@autonomous-agent "task"`              | Delegate infrastructure tasks      |
| `@aws-tools/deploy`                     | Deploy with AWS tools MCP          |

### ECS Express Mode

When using the `aws-labs/ecs-express` Power:

- Automatic NLB provisioning (replaces manual LB config)
- Simplified task definitions
- Built-in scale-to-zero support
- Streamlined Fargate configuration

### Migration Reference

See `KIRO_MIGRATION_PLAN.md` for:

- Domain migration procedures
- AWS profile configuration
- Spec-driven development workflow
- Detailed change tracking

### Domain Configuration (Current State)

The platform is designed to be domain-agnostic. Key configuration points:

- `variables.tf:34` - `domain_name` variable
- `scripts/*.pl` - `$DOMAIN_NAME` constant
- Certificate ARN in `main.tf:226` (account-specific)

### Steering Files

Kiro uses steering files in `.kiro/steering/` for project context:

- `product.md` - Product overview and goals
- `tech.md` - Technology stack and developer preferences
- `structure.md` - Project organization and patterns

---

## Session Tracking

### Changelog

All changes during Q/A sessions are tracked in `SESSION_CHANGELOG.md`. This file uses a format compatible with future S3 Vectors storage for semantic search across session history.

### Blog Updates

Two blog posts are actively maintained during development:

- `blog/BLOG_JITSI_ECS_EXPRESS.md` - Self-hosted video with Jitsi + ECS Express
- `blog/BLOG_KIRO_TERRAFORM.md` - Spec-driven IaC with Kiro CLI

**Reminder**: Update these blogs when discovering insights about ECS Express, Kiro workflows, or deployment patterns.

---

## Repository Structure

### Public: `jitsi-video-hosting/`

- Infrastructure code (Terraform)
- Operational scripts (Perl)
- Documentation (Markdown)
- Kiro steering files
- Blog drafts

### Private: `jitsi-video-hosting-ops/`

- Account-specific details
- Credential references
- Sensitive operational data

**Never commit** sensitive data to the public repository.
