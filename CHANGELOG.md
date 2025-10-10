# Changelog

All notable changes to the Jitsi Video Platform project will be documented in this file.

## [Unreleased]

### Added
- **Smart Power Management System** - Three-tier shutdown options for cost optimization
  - `power-down.pl` - Removes expensive resources, keeps static resources (97% cost savings)
  - `fully-destroy.pl` - Complete infrastructure destruction with confirmation
  - Updated `scale-down.pl` documentation for clarity
- **Co-Organizer Guide** - Comprehensive management documentation for NE3D/RGC3 teams
- **GitHub Issues Created**:
  - [#17](https://github.com/BryanChasko/jitsi-video-hosting/issues/17) - AWS Device Farm mobile testing integration
  - [#18](https://github.com/BryanChasko/jitsi-video-hosting/issues/18) - Smart power management implementation
  - [#19](https://github.com/BryanChasko/jitsi-video-hosting/issues/19) - Custom AWS Aerospace branding

### Changed
- **Roadmap Structure** - Reorganized phases to prioritize power management and branding
- **Cost Management** - Updated documentation with three-tier power options
- **Documentation** - Enhanced with detailed power management explanations

### Technical Details
- Power management scripts preserve S3 buckets, Secrets Manager, IAM roles, CloudWatch logs
- Cost reduction from $16.62/month to $0.42/month with power-down mode
- Restore times: 2-3 min (scale-up), 5-10 min (power-up), 15-20 min (full restore)

## [1.0.0] - 2024-10-10

### Added
- **Complete Jitsi Meet Platform** - Fully operational video conferencing at https://meet.awsaerospace.org
- **Scale-to-Zero Architecture** - ECS Fargate with manual scaling scripts
- **AWS Infrastructure**:
  - Network Load Balancer with TLS termination
  - ECS cluster with 4-container Jitsi setup
  - AWS Secrets Manager for secure credential storage
  - S3 bucket for video recordings
  - CloudWatch logging and monitoring
- **Operational Scripts**:
  - `scale-up.pl` - Start platform with health verification
  - `scale-down.pl` - Stop platform for cost savings
  - `status.pl` - Platform status reporting
  - `check-health.pl` - Multi-layer health verification
  - `test-platform.pl` - Complete testing workflow

### Technical Specifications
- **Domain**: meet.awsaerospace.org with valid SSL certificate
- **Capacity**: Unlimited users per meeting, unlimited concurrent meetings
- **Resources**: 4 vCPU, 8GB RAM on AWS Fargate
- **Containers**: jitsi-web, prosody, jicofo, jvb with WebSocket support
- **Region**: US West (Oregon) - us-west-2

### Security
- AWS Identity Center (SSO) authentication for administrators
- Secrets stored in AWS Secrets Manager
- TLS encryption for all communications
- Private VPC with security groups

### Cost Optimization
- Scale-to-zero when not in use: $0.00/hour
- Running cost: $0.20/hour
- Fixed infrastructure: $16.62/month
- 58% savings vs always-on deployment

---

*Format based on [Keep a Changelog](https://keepachangelog.com/)*