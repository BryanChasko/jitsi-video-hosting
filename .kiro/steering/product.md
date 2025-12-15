# Product Overview - Jitsi Video Hosting Platform

## Purpose
On-demand, self-hosted video conferencing platform using open-source Jitsi Meet deployed on AWS. Designed for user groups (NE3D Blender, RGC3 AWS) with **scale-to-zero cost optimization** as the primary architectural goal.

## Target Users
- Community organizers hosting virtual meetups
- User group administrators needing video conferencing
- Cost-conscious organizations wanting unlimited video calling without per-user pricing

## Key Features
- **Unlimited Participants**: No per-user licensing costs
- **Scale-to-Zero**: Platform costs $0.00/hour when not in use
- **Self-Hosted**: Full control over data and configuration
- **Production Video**: WebSocket support, STUN/TURN for NAT traversal

## Business Objectives
1. **Cost Efficiency**: ~$28/month for 2hrs daily usage vs $100+/month for commercial alternatives
2. **Operational Simplicity**: Single-command scale-up/down via Perl scripts
3. **Zero Idle Cost**: 97% savings with power-down mode ($16.62/month → $0.42/month)

## Current Migration
Transitioning from `meet.awsaerospace.org` to `meet.bryanchasko.com` using:
- Kiro CLI for spec-driven development
- ECS Express Mode for simplified infrastructure
- New AWS account (`aws-ug-jitsi-hosting`)

## Success Metrics
- Platform available within 3 minutes of scale-up command
- Zero fixed compute costs when idle
- Video calls working with 2+ participants across different networks
