# Co-Organizer Guide: Managing Jitsi Video Platform

Quick reference for NE3D and RGC3 co-organizers to manage the video platform.

## Platform URL
**https://meet.awsaerospace.org**

---

## Prerequisites (One-time setup)

### 1. Install AWS CLI
```bash
# macOS
brew install awscli

# Windows
# Download from: https://aws.amazon.com/cli/
```

### 2. Get AWS Access
Contact Bryan Chasko for:
- AWS Identity Center invitation
- `jitsi-dev` profile configuration

### 3. Clone Repository
```bash
git clone https://github.com/BryanChasko/jitsi-video-hosting.git
cd jitsi-video-hosting
```

---

## Daily Operations

### Starting the Platform (Before Meetings)

```bash
# 1. Login to AWS (expires every 8 hours)
aws sso login --profile jitsi-dev

# 2. Start the platform
cd scripts/
./scale-up.pl
```

#### What `scale-up.pl` does:
- **Changes ECS service** from 0 to 1 running instance
- **Starts 4 containers**: jitsi-web, prosody, jicofo, jvb
- **Allocates resources**: 4 vCPU, 8GB RAM on AWS Fargate
- **Registers with load balancer** for HTTPS traffic
- **Waits for health checks** to pass (2-3 minutes)
- **Verifies** all containers are communicating properly

**Result**: Platform becomes accessible at https://meet.awsaerospace.org

### Stopping the Platform (Multiple Options)

#### Option 1: Scale Down (Between Meetings)
```bash
# Quick shutdown - keeps infrastructure ready
./scale-down.pl
```
- **What it does**: Stops containers only, keeps load balancer running
- **Cost**: $16.62/month (no savings on fixed costs)
- **Restore time**: 2-3 minutes
- **Use when**: Between meetings (hours)

#### Option 2: Power Down (Between Events) 🆕
```bash
# Smart shutdown - removes expensive resources
./power-down.pl
```
- **What it does**: Removes load balancer, ECS, VPC but keeps S3, secrets, IAM
- **Cost**: $0.42/month (97% savings)
- **Restore time**: 5-10 minutes with `terraform apply`
- **Use when**: Between events (days/weeks)

#### Option 3: Full Destroy (Long-term Shutdown) ⚠️
```bash
# Complete shutdown - removes everything
./fully-destroy.pl
```
- **What it does**: Destroys all infrastructure (requires typing "DESTROY")
- **Cost**: $0.00/month (100% savings)
- **Restore time**: 15-20 minutes + DNS reconfiguration
- **Use when**: Long-term shutdown (months)

### Check Platform Status

```bash
# Quick status check
./status.pl

# Full health verification
./check-health.pl
```

---

## Hosting Meetings

### 1. Start Platform
Run `./scale-up.pl` (if not already running)

### 2. Create Meeting
- Go to: **https://meet.awsaerospace.org**
- Enter room name: `ne3d-meeting` or `rgc3-discussion`
- Click "Join"

### 3. Share with Participants
Send them:
- **URL**: https://meet.awsaerospace.org
- **Room name**: Same name you used

### 4. After Meeting
Run `./scale-down.pl` to save costs

---

## Troubleshooting

### "Service not found" error
```bash
# Refresh AWS login
aws sso login --profile jitsi-dev
```

### Platform not responding
```bash
# Restart the service
./scale-down.pl
sleep 30
./scale-up.pl
```

### Check logs
```bash
aws logs get-log-events \
  --log-group-name /ecs/jitsi-video-platform \
  --log-stream-name ecs/jitsi-web/[TASK-ID] \
  --profile jitsi-dev
```

---

## Cost Management

| Power State | Monthly Cost | Restore Time | Use Case |
|-------------|--------------|--------------|----------|
| **Running** | $16.62 + usage | - | Active meetings |
| **Scale Down** | $16.62 | 2-3 min | Between meetings |
| **Power Down** | $0.42 | 5-10 min | Between events |
| **Full Destroy** | $0.00 | 15-20 min | Long-term shutdown |

**Recommendation**: Use power-down between events for maximum savings

---

## Emergency Contacts

- **Primary**: Bryan Chasko
- **Platform Issues**: GitHub Issues
- **AWS Account**: Contact Bryan for access

---

## Quick Commands Reference

```bash
# Essential commands
aws sso login --profile jitsi-dev  # Login (required first)
./scale-up.pl                      # Start platform
./scale-down.pl                    # Stop platform (keep infrastructure)
./power-down.pl                    # Power down (remove expensive resources)
./fully-destroy.pl                 # Full destroy (remove everything)
./status.pl                        # Check status
./check-health.pl                  # Full health check

# Meeting URL
https://meet.awsaerospace.org
```

---

*Last updated: October 2024*