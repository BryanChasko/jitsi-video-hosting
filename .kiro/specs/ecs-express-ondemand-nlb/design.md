# ECS Express with On-Demand NLB - Design Document

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SCALE-UP SEQUENCE                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. scale-up.pl                                                          │
│     │                                                                    │
│     ├─► terraform apply -target=module.jvb_nlb                          │
│     │   └─► Creates: NLB, Target Group, Listener (UDP/10000)            │
│     │                                                                    │
│     ├─► Wait for NLB active (aws elbv2 describe-load-balancers)         │
│     │                                                                    │
│     ├─► aws ecs update-service --desired-count 1                        │
│     │   └─► ECS Express auto-creates ALB for HTTPS/443                  │
│     │                                                                    │
│     ├─► Register ECS task IPs to NLB target group                       │
│     │                                                                    │
│     └─► Verify health: ALB (HTTPS) + NLB (UDP) + Jitsi app              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                        SCALE-DOWN SEQUENCE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. scale-down.pl                                                        │
│     │                                                                    │
│     ├─► aws ecs update-service --desired-count 0                        │
│     │   └─► ECS Express auto-removes ALB                                │
│     │                                                                    │
│     ├─► Wait for tasks to drain (60s timeout)                           │
│     │                                                                    │
│     ├─► terraform destroy -target=module.jvb_nlb                        │
│     │   └─► Destroys: NLB, Target Group, Listener                       │
│     │                                                                    │
│     └─► Verify: No LB resources remain                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Design

### 1. JVB NLB Module (`modules/jvb-nlb/main.tf`)

```hcl
# Module: modules/jvb-nlb/main.tf

variable "project_name" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "security_group_id" {}

resource "aws_lb" "jvb" {
  name               = "${var.project_name}-jvb-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection = false  # Allow script teardown

  tags = {
    Name        = "${var.project_name}-jvb-nlb"
    Project     = var.project_name
    Lifecycle   = "on-demand"
  }
}

resource "aws_lb_target_group" "jvb_udp" {
  name        = "${var.project_name}-jvb-udp"
  port        = 10000
  protocol    = "UDP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # Required for Fargate

  health_check {
    enabled             = true
    protocol            = "TCP"
    port                = "8080"  # JVB health port
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = {
    Name    = "${var.project_name}-jvb-udp-tg"
    Project = var.project_name
  }
}

resource "aws_lb_listener" "jvb_udp" {
  load_balancer_arn = aws_lb.jvb.arn
  port              = 10000
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jvb_udp.arn
  }
}

output "nlb_dns_name" {
  value = aws_lb.jvb.dns_name
}

output "nlb_arn" {
  value = aws_lb.jvb.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.jvb_udp.arn
}
```

### 2. ECS Service with Express Mode

```hcl
# In main.tf - Updated ECS Service

resource "aws_ecs_service" "jitsi" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.jitsi.id
  task_definition = aws_ecs_task_definition.jitsi.arn
  desired_count   = 0  # Scale-to-zero default
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.jitsi.id]
    assign_public_ip = true
  }

  # ECS Service Connect for Express ALB
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.jitsi.arn

    service {
      port_name      = "web"
      discovery_name = "jitsi-web"

      client_alias {
        port     = 443
        dns_name = "jitsi-web"
      }
    }

    log_configuration {
      log_driver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.jitsi.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "service-connect"
      }
    }
  }

  # ALB managed by Express - no load_balancer block needed for HTTPS
  # NLB managed by scripts - target registration done dynamically

  lifecycle {
    ignore_changes = [desired_count]  # Managed by scripts
  }
}

# Service Discovery Namespace (required for Service Connect)
resource "aws_service_discovery_private_dns_namespace" "jitsi" {
  name        = "${var.project_name}.local"
  description = "Service discovery namespace for Jitsi"
  vpc         = aws_vpc.jitsi.id

  tags = {
    Project = var.project_name
  }
}
```

### 3. Scale-Up Script Flow

```perl
#!/usr/bin/env perl
# scripts/scale-up.pl - Enhanced for on-demand NLB

use strict;
use warnings;
use lib '../lib';
use JitsiConfig;

my $config = JitsiConfig->new();

# Phase 1: Create NLB via Terraform
print "Creating JVB NLB...\n";
system("terraform apply -target=module.jvb_nlb -auto-approve") == 0
    or die "Failed to create NLB";

# Phase 2: Get NLB DNS name
my $nlb_dns = `terraform output -raw jvb_nlb_dns_name`;
chomp $nlb_dns;
print "NLB DNS: $nlb_dns\n";

# Phase 3: Wait for NLB active
print "Waiting for NLB to be active...\n";
my $max_wait = 180;  # 3 minutes
my $waited = 0;
while ($waited < $max_wait) {
    my $state = `aws elbv2 describe-load-balancers --names $config->project_name()-jvb-nlb --query 'LoadBalancers[0].State.Code' --output text --profile $config->aws_profile()`;
    chomp $state;
    last if $state eq 'active';
    sleep 10;
    $waited += 10;
    print "  NLB state: $state (waited ${waited}s)\n";
}

# Phase 4: Scale ECS service (triggers Express ALB)
print "Scaling ECS service to 1...\n";
system("aws ecs update-service --cluster $config->cluster_name() --service $config->service_name() --desired-count 1 --profile $config->aws_profile()") == 0
    or die "Failed to scale ECS";

# Phase 5: Register task IPs to NLB target group
# (This happens after tasks start - may need separate registration script)

# Phase 6: Health verification
print "Verifying platform health...\n";
# ... health check logic
```

### 4. Scale-Down Script Flow

```perl
#!/usr/bin/env perl
# scripts/scale-down.pl - Enhanced for on-demand NLB

use strict;
use warnings;
use lib '../lib';
use JitsiConfig;

my $config = JitsiConfig->new();

# Phase 1: Scale ECS to 0 (Express ALB auto-removes)
print "Scaling ECS service to 0...\n";
system("aws ecs update-service --cluster $config->cluster_name() --service $config->service_name() --desired-count 0 --profile $config->aws_profile()") == 0
    or die "Failed to scale ECS";

# Phase 2: Wait for tasks to drain
print "Waiting for tasks to drain...\n";
sleep 60;

# Phase 3: Destroy NLB via Terraform
print "Destroying JVB NLB...\n";
system("terraform destroy -target=module.jvb_nlb -auto-approve") == 0
    or die "Failed to destroy NLB";

# Phase 4: Verify no LB resources
print "Verifying cleanup...\n";
my $lbs = `aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, \`$config->project_name()\`)].LoadBalancerName' --output text --profile $config->aws_profile()`;
if ($lbs) {
    warn "Warning: Load balancers still exist: $lbs\n";
} else {
    print "✓ All load balancers removed\n";
}

print "\n=== COST IMPACT ===\n";
print "NLB removed: -\$16.20/month\n";
print "ALB removed: -\$16.20/month (Express)\n";
print "Fargate stopped: -\$0.20/hour\n";
print "New monthly cost: \$0.00\n";
```

## Cost Model

### Running State (Per Hour)
| Resource | Cost/Hour |
|----------|-----------|
| NLB | $0.0225 |
| ALB (Express) | $0.0225 |
| Fargate (2 vCPU, 4GB) | $0.12 |
| Data Transfer | ~$0.02 |
| **Total** | **~$0.19/hour** |

### Idle State (Per Month)
| Resource | Cost/Month |
|----------|------------|
| VPC/Subnets | $0.00 |
| S3 (recordings) | ~$0.23 |
| SSM Parameters | $0.00 |
| Route 53 (optional) | $0.50 |
| **Total** | **~$0.73/month** |

### Comparison
| Scenario | Old Model | New Model |
|----------|-----------|-----------|
| Always-on | $150+/month | $150+/month |
| Scale-to-zero (keep LB) | $16.62/month | N/A |
| True scale-to-zero | N/A | **$0.73/month** |
| 10 hours/month usage | $16.62 + $1.20 | $0.73 + $1.90 |

## File Structure

```
jitsi-video-hosting/
├── main.tf                    # Core infrastructure (modified)
├── modules/
│   └── jvb-nlb/
│       ├── main.tf            # NLB resources
│       ├── variables.tf       # Module inputs
│       └── outputs.tf         # NLB DNS, ARNs
├── scripts/
│   ├── scale-up.pl            # Enhanced with NLB creation
│   ├── scale-down.pl          # Enhanced with NLB teardown
│   └── register-targets.pl    # Register task IPs to NLB
└── .kiro/
    └── specs/
        └── ecs-express-ondemand-nlb/
            ├── requirements.md
            ├── design.md
            └── tasks.md
```

## Integration Points

### JVB Container Configuration
```hcl
environment = [
  {
    name  = "JVB_ADVERTISE_IPS"
    value = ""  # Set dynamically by scale-up script
  },
  {
    name  = "JVB_PORT"
    value = "10000"
  },
  {
    name  = "JVB_TCP_PORT"
    value = "4443"  # Fallback
  },
  {
    name  = "JVB_TCP_MAPPED_PORT" 
    value = "4443"
  }
]
```

### DNS Strategy
- **Option A**: Single domain, ALB handles all (simpler)
- **Option B**: Subdomain for JVB UDP (jvb.domain.com → NLB)
- **Recommended**: Option A with TCP fallback for simplicity
