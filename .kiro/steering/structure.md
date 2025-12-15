# Project Structure - Jitsi Video Hosting Platform

## Repository Layout

### Public Repository: `jitsi-video-hosting/`
```
├── main.tf                 # All infrastructure (909 lines, single-file pattern)
├── variables.tf            # Configuration variables
├── outputs.tf              # Terraform outputs
├── scripts/                # Perl operational scripts (NOT shell)
│   ├── scale-up.pl         # Start platform
│   ├── scale-down.pl       # Stop platform (scale to 0)
│   ├── power-down.pl       # Remove compute resources (97% savings)
│   ├── fully-destroy.pl    # Complete teardown
│   ├── status.pl           # Platform status
│   ├── check-health.pl     # Health verification
│   └── test-platform.pl    # 10-phase testing workflow
├── blog/                   # Blog post drafts (update during development)
│   ├── BLOG_JITSI_ECS_EXPRESS.md
│   └── BLOG_KIRO_TERRAFORM.md
├── .kiro/steering/         # Kiro context files
│   ├── product.md
│   ├── tech.md
│   └── structure.md
├── .github/
│   └── copilot-instructions.md  # AI agent instructions
├── KIRO_MIGRATION_PLAN.md  # Current migration documentation
├── SESSION_CHANGELOG.md    # Q/A session change tracking
└── [Documentation files]   # README, guides, etc.
```

### Private Repository: `jitsi-video-hosting-ops/`
```
├── OPERATIONS.md           # Sensitive account details
├── README.md               # Private repo overview
├── terraform.tfvars        # (Future) Private variable values
└── secrets/                # (Future) Credential references
```

## Key Patterns

### Single-File Terraform
All infrastructure in `main.tf` organized by section:
- Lines 1-87: VPC networking
- Lines 88-142: Security groups
- Lines 144-233: Load balancing
- Lines 236-454: ECS cluster, IAM, logging
- Lines 455-878: Task definition (4 containers)
- Lines 879-909: ECS service (scale-to-zero)

### Perl Script Convention
All scripts follow this pattern:
```perl
#!/usr/bin/env perl
use strict; use warnings;
use JSON; use Term::ANSIColor qw(colored);

my $PROJECT_NAME = "jitsi-video-platform";
my $AWS_PROFILE = "bryanchasko-jitsi-host";  # Updated for migration
my $AWS_REGION = "us-west-2";
my $DOMAIN_NAME = "meet.bryanchasko.com";    # Updated for migration
```

### Resource Naming
All AWS resources: `${var.project_name}-{component}`
- Cluster: `jitsi-video-platform-cluster`
- Service: `jitsi-video-platform-service`
- NLB: `jitsi-video-platform-nlb`

### Documentation Updates
When making changes, also update:
1. `SESSION_CHANGELOG.md` - Track the change
2. `blog/BLOG_*.md` - If relevant to blog topics
3. `.github/copilot-instructions.md` - If affecting agent behavior
