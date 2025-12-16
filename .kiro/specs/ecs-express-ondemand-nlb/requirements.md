# ECS Express with On-Demand NLB Specification

## Overview
Implement ECS Express Mode for HTTPS traffic with scripted on-demand NLB for JVB UDP video traffic. Achieves true scale-to-zero ($0/month when idle) while preserving optimal video quality via UDP.

## Current State
- **Load Balancer**: None (comment placeholder at line 143)
- **Video Protocol**: JVB configured for UDP/10000 but no LB to route it
- **Cost When Idle**: ~$16.62/month (VPC, CloudWatch active)
- **Target Cost**: $0/month when idle

## Architecture Target

```
RUNNING STATE:
┌─────────────────────────────────────────────────────────────┐
│  Internet                                                    │
│     │                                                        │
│     ├──► ECS Express ALB (HTTPS/443) ──► jitsi-web (80)     │
│     │    (AWS-managed lifecycle)                             │
│     │                                                        │
│     └──► On-Demand NLB (UDP/10000) ──► jvb (10000)          │
│          (Script-managed lifecycle)                          │
└─────────────────────────────────────────────────────────────┘

IDLE STATE:
┌─────────────────────────────────────────────────────────────┐
│  No ALB, No NLB, No ECS Tasks                               │
│  Only: VPC skeleton, S3 bucket, SSM parameters              │
│  Cost: ~$0/month                                            │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

### REQ-1: ECS Express Service Configuration
- [ ] Enable ECS Service Connect or Express Mode for ALB management
- [ ] Configure service for HTTPS/443 with AWS-managed certificate
- [ ] ALB automatically created when desired_count > 0
- [ ] ALB automatically destroyed when desired_count = 0
- [ ] Health checks via HTTP on port 80

### REQ-2: On-Demand NLB Terraform Module
- [ ] Create reusable NLB module in `modules/jvb-nlb/`
- [ ] NLB listens on UDP/10000, forwards to JVB container
- [ ] Target group with IP target type for Fargate
- [ ] Health check on TCP/8080 (JVB health endpoint)
- [ ] Module can be applied/destroyed independently

### REQ-3: Scale-Up Script Enhancement
- [ ] Create NLB via Terraform module before scaling ECS
- [ ] Wait for NLB to be active and healthy
- [ ] Update JVB environment with NLB DNS name
- [ ] Scale ECS service to desired_count=1
- [ ] Verify both ALB (Express) and NLB are serving traffic

### REQ-4: Scale-Down Script Enhancement
- [ ] Scale ECS service to desired_count=0
- [ ] Wait for tasks to drain
- [ ] Destroy NLB via Terraform module
- [ ] Verify NLB resources fully removed
- [ ] Log cost savings from NLB teardown

### REQ-5: JVB Configuration Updates
- [ ] Configure DOCKER_HOST_ADDRESS dynamically from NLB DNS
- [ ] Maintain UDP/10000 as primary video transport
- [ ] Configure TCP/4443 as fallback (for restrictive networks)
- [ ] Update STUN/TURN configuration for AWS networking

### REQ-6: DNS Management
- [ ] Primary domain (meet.awsaerospace.org) points to Express ALB
- [ ] Optional: JVB subdomain for direct UDP (jvb.awsaerospace.org)
- [ ] DNS updates handled in scale-up/scale-down scripts
- [ ] TTL considerations for fast failover

### REQ-7: Cost Verification
- [ ] Idle state: $0/month (no ALB, no NLB, no tasks)
- [ ] Running state: ~$0.20/hour (ALB + NLB + Fargate)
- [ ] Update cost-analysis.pl with new model
- [ ] Document hourly vs monthly cost comparison

## Acceptance Criteria

1. `./scripts/scale-up.pl` creates NLB, starts ECS, ALB auto-provisions
2. Video calls work with UDP/10000 (verify via browser WebRTC stats)
3. `./scripts/scale-down.pl` destroys NLB, stops ECS, ALB auto-removes
4. After scale-down: `terraform state list` shows no LB resources
5. Cost when idle verified at $0/month (excluding Route 53)

## Technical Constraints

- ECS Express requires Fargate platform version 1.4.0+
- NLB UDP listeners require specific health check configuration
- JVB needs public IP or NLB for media traffic
- Cross-AZ NLB adds $0.01/GB data processing cost

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| NLB creation takes 2-3 minutes | Pre-warm option, user notification |
| DNS propagation delay | Low TTL (60s), health check grace period |
| Express ALB not supported in region | Fallback to manual ALB in module |
| UDP blocked by client firewall | TCP/4443 fallback configured |
