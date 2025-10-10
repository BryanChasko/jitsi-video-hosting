# On-Demand Video Platform: Requirements & Architectural Goals

Vision and architectural goals for a video conferencing platform to serve the New England 3D (NE3D) Blender and Rio Grande Corridor Cloud Community (RGC3) AWS user groups. The solution is built leveraging 100% free Jitsi Meet open-source experience while prioritizing cost control through on-demand operation to spin down resources when calls are not in progress. Recorded video to be stored in s3 for future editing.

## Getting Started

🚀 **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - **START HERE** - Complete step-by-step deployment guide for new developers

📋 **[AWS_SETUP.md](AWS_SETUP.md)** - Complete AWS IAM Identity Center setup guide for deploying your own Jitsi platform

🌐 **[DOMAIN_SETUP.md](DOMAIN_SETUP.md)** - DNS and SSL certificate configuration guide

🔧 **[TOOLING.md](TOOLING.md)** - AI-assisted development workflow with Amazon Q and GitHub CLI

🧪 **[TESTING.md](TESTING.md)** - Comprehensive platform testing guide and automation scripts

🤖 **[OPERATIONS.md](https://github.com/BryanChasko/jitsi-video-hosting-ops)** - Project-specific operational details (AWS account, region, etc.) - *Private repository*

🏭 **[PRODUCTION_OPTIMIZATION.md](PRODUCTION_OPTIMIZATION.md)** - Comprehensive production optimization guide with security, monitoring, and performance enhancements

✅ **Infrastructure Status**: Fully deployed with HTTPS-enabled Network Load Balancer, DNS configured, and scale-to-zero ECS service

🚀 **Testing Status**: Complete Perl-based testing suite with 10-phase workflow, health verification, and SSL validation

🔧 **Production Status**: **FULLY OPERATIONAL** - Video calls working with WebSocket support, smart power management, monitoring, and enhanced security

🎥 **Video Calling Status**: **LIVE** - Platform successfully serving video conferences at https://meet.awsaerospace.org

🔋 **Power Management**: **SMART TIERED SYSTEM** - Scale-down, power-down (97% savings), and full-destroy options for optimal cost control

📋 **GitHub Issues**: [View Current Issues](https://github.com/BryanChasko/jitsi-video-hosting/issues) - Track development progress and upcoming features

Generally speaking, this aims to be a guide others can use to host video calls and enable streaming for their own communities, hosted on AWS.

## Repository Structure

```
├── README.md           # Project overview and requirements
├── CHANGELOG.md        # Project change history and releases
├── CO_ORGANIZER_GUIDE.md # Management guide for NE3D/RGC3 teams
├── AWS_SETUP.md        # AWS Identity Center setup guide
├── DOMAIN_SETUP.md     # DNS and SSL certificate configuration
├── TOOLING.md          # AI-assisted development workflow and tools
├── TESTING.md          # Comprehensive testing guide and automation
├── PRODUCTION_OPTIMIZATION.md # Production optimization guide
├── PRODUCTION_SUMMARY.md # Production deployment summary
├── ROADMAP.md          # Development roadmap and feature planning
├── main.tf            # Main Terraform configuration
├── variables.tf       # Terraform variables
├── outputs.tf         # Terraform outputs
├── scripts/           # Perl operational scripts
│   ├── setup.pl       # Script initialization and permissions
│   ├── test-platform.pl  # Complete testing workflow (10-phase)
│   ├── scale-up.pl    # Scale service up with verification
│   ├── scale-down.pl  # Scale service down with verification
│   ├── power-down.pl  # Smart shutdown (97% cost savings)
│   ├── fully-destroy.pl # Complete infrastructure destruction
│   ├── check-health.pl # Multi-layer health verification
│   └── status.pl      # Platform status reporting
└── .gitignore         # Git exclusions
```

## Service Endpoint

The platform is to be accessible at the following publicly registered domain:
**`https://meet.awsaerospace.org`**

## Cost Analysis 💰

### Monthly Cost Breakdown

**Fixed Costs (Always Running):**
- Network Load Balancer: $16.20/month
- S3 Storage: $0.02/month
- AWS Secrets Manager: $0.40/month
- **Fixed Total: $16.62/month**

**Variable Costs (When Running):**
- ECS Fargate (4 vCPU, 8GB): $0.198/hour

### Usage Scenarios

| Usage Pattern | Monthly Hours | Variable Cost | Total Cost |
|---------------|---------------|---------------|-----------|
| **Scaled Down** | 0 hours | $0.00 | **$16.62** |
| **Light Use** | 10 hours | $1.98 | **$18.60** |
| **Regular Use** | 60 hours (2hrs daily) | $12.01 | **$28.63** |
| **Heavy Use** | 120 hours (4hrs daily) | $23.76 | **$40.38** |
| **Always On** | 744 hours | $147.31 | **$163.93** |

### Cost Comparison

| Service | Monthly Cost | Users | Notes |
|---------|--------------|-------|---------|
| **This Platform** | $28.63 | Unlimited | 2hrs daily usage |
| Zoom Pro | $12.49 | 1 host | 40min limit |
| Google Meet | $6.00 | Per user | Enterprise required |
| Microsoft Teams | $4.00 | Per user | Business plan |

**Key Advantage**: Scale-to-zero architecture saves 58% vs always-on deployment

## Quick Testing

To test the deployed platform:

```bash
# Setup testing scripts (Perl-based)
cd scripts/
./setup.pl

# Run complete testing workflow
./test-platform.pl
```

This will:
1. ✅ Scale ECS service from 0 to 1
2. ✅ Verify service health and stability
3. ✅ Test HTTPS access and SSL certificate
4. ✅ Verify Jitsi Meet functionality
5. ✅ Scale back to 0 for cost optimization

### Manual Testing

1. **Start Platform**: `./scripts/scale-up.pl`
2. **Open Browser**: Navigate to https://meet.awsaerospace.org
3. **Create Room**: Enter any room name (e.g., "test-meeting")
4. **Join Call**: Click "Join" - you should see video/audio interface
5. **Stop Platform**: `./scripts/scale-down.pl` (for cost savings)

### Troubleshooting

If you encounter "You have been disconnected":
1. Ensure WebSocket configuration is enabled (already fixed in current deployment)
2. Check JVB logs: `aws logs get-log-events --log-group-name /ecs/jitsi-video-platform`
3. Verify target group health in AWS Console
4. Restart service: `./scripts/scale-down.pl && ./scripts/scale-up.pl`

See **[TESTING.md](TESTING.md)** for detailed testing documentation.

## Deployment Success ✅

The platform has been successfully deployed and is **fully operational**:

- ✅ **Video calls working** - WebSocket connectivity resolved
- ✅ **SSL/TLS encryption** - Valid certificate for meet.awsaerospace.org
- ✅ **Scale-to-zero architecture** - Cost optimization when not in use
- ✅ **Multi-container setup** - All Jitsi components running correctly
- ✅ **AWS Secrets Manager** - Secure credential management
- ✅ **CloudWatch monitoring** - Comprehensive logging and metrics

### Key Issues Resolved

1. **Container Configuration** - Fixed Fargate compatibility issues
2. **Secrets Management** - Resolved IAM permissions for Secrets Manager
3. **WebSocket Connectivity** - Enabled JVB WebSocket support for video calls
4. **XMPP Communication** - Fixed inter-container communication using localhost

### Current Architecture

- **Task Definition**: Revision 4 with WebSocket support
- **Container Count**: 4 containers (jitsi-web, prosody, jicofo, jvb)
- **Resource Allocation**: 4 vCPU / 8GB RAM
- **Network**: Network Load Balancer with TLS termination
- **Storage**: S3 bucket for video recordings (when enabled)
- **Cost Optimization**: Scale-to-zero when not in use

## Next Steps & Roadmap

### Phase 2: Authentication & Custom Branding ([Issue #14](https://github.com/BryanChasko/jitsi-video-hosting/issues/14))
- **Cognito Authentication**: Implement gated community access with manual user creation
- **Social Login**: GitHub/Google integration for awsaerospace.org community
- **Custom Branding**: Replace Jitsi branding with AWS Aerospace theme
- **User Management**: Admin-controlled user creation and role management

### Phase 3: Enhanced Features
- **Video Recording**: EKS-based Jibri service for privileged container support ([Issue #16](https://github.com/BryanChasko/jitsi-video-hosting/issues/16))
- **Private Operations**: Separate private repository for sensitive operational files ([Issue #15](https://github.com/BryanChasko/jitsi-video-hosting/issues/15))
- **Advanced Monitoring**: Enhanced CloudWatch dashboards and alerting ([Issue #12](https://github.com/BryanChasko/jitsi-video-hosting/issues/12))
- **Security Hardening**: Secret rotation and compliance features ([Issue #13](https://github.com/BryanChasko/jitsi-video-hosting/issues/13))

### Community Integration
- Integration with existing awsaerospace.org website authentication
- Custom meeting features for AWS user groups (NE3D, RGC3)
- Meeting scheduling and community announcements
- Mobile-responsive design and PWA capabilities

## Jitsi Application Requirements (The "What")

The chosen hosting platform must satisfy the following technical requirements necessary for a fully functional, secure Jitsi Meet deployment:

| Component | Required Ports | Protocol | Requirement |
| :--- | :--- | :--- | :--- |
| **Web Interface** | 443 | TCP | Mandatory for secure browser access (HTTPS). |
| **Media (JVB)** | 10000 | UDP | **Critical.** Must be open to the internet for direct media transmission. |
| **Internal Communication** | N/A | Localhost | Internal components must be able to communicate via the host network interface (localhost). |
| **TLS/Encryption** | 443 | TLS | A valid, public SSL/TLS certificate for the domain is required. |

## Architectural & Operational Goals (The "How")

Any deployed solution must meet the following operational and cost management objectives:

### Cost Control & Scale-to-Zero

* **Goal:** Scale to zero operational cost when the platform is not in use.
* **Requirement:** The core application compute must be able to scale down to **zero running instances** and back up rapidly to align with scheduled events.
* **Control:** A **deterministic control plane** must be implemented to manage the scale-up (`start`) and scale-down (`stop`) actions.

### Security & Management

* **Developer Access:** Access must be managed using an **Identity Center / SSO** flow, eliminating long-lived access keys.
* **Secrets:** All application secrets must be stored in a dedicated, secure secrets manager (e.g., AWS Secrets Manager).
* **Target Region:** All core infrastructure must be deployed in the **US West (Oregon) - `us-west-2`** region.

---

## Developer Guidance: Effective Infrastructure-as-Code (IaC) Workflow

Use these guidelines to ensure the generated code is accurate and aligns with all project requirements, keeping the entire file structure in mind.

| Infrastructure Goal | Required Context | IaC/GitOps Action |
| :--- | :--- | :--- |
| **Networking** | Entire project files (VPC, Subnet, Security Groups) | Define the necessary Terraform files for the VPC and two public subnets as described in the requirements. |
| **Jitsi Ports** | Project requirements for Jitsi ports (443 TCP, 10000 UDP) | Implement the Network Load Balancer (NLB) resource with the correct listeners and target groups for Jitsi traffic. |
| **Cost Control** | ECS Fargate Service parameters | Write the base ECS Fargate service Terraform, ensuring the initial `desired_count` is set to **`0`** to support the scale-to-zero requirement. |
| **Security** | IAM Policy and Task Definition files | Review the generated IAM Policy for the ECS Task Role against the principle of least privilege, using the established requirements. |

---

