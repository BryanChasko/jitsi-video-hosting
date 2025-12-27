# Jitsi Platform Testing Guide

This guide provides comprehensive instructions for testing the Jitsi Meet platform deployment, including scaling operations, health verification, and functionality testing.

## Overview

The testing framework provides automated verification of:
- ✅ ECS service scaling (0→1→0)
- ✅ Service health and stability
- ✅ HTTPS access and SSL certificate validation
- ✅ Jitsi Meet functionality
- ✅ Load balancer target health
- ✅ DNS resolution
- ✅ Cost optimization (scale-to-zero)

## Quick Start

### 1. Setup Scripts
```bash
cd scripts/
chmod +x setup.sh
./setup.sh
```

### 2. Run Complete Test Suite
```bash
./test-platform.sh
```

This will execute the full testing workflow automatically.

## Manual Testing Steps

### Step 1: Check Initial Status
```bash
./status.sh
```
Expected: Service should be scaled to 0 (standby mode)

### Step 2: Scale Up Service
```bash
./scale-up.sh
```
Expected: Service scales from 0 to 1 instance with health verification

### Step 3: Verify Health
```bash
./check-health.sh
```
Expected: All health checks should pass

### Step 4: Test Platform Access
```bash
# Test HTTPS access
curl -I https://meet.awsaerospace.org

# Test SSL certificate
echo | openssl s_client -servername meet.awsaerospace.org -connect meet.awsaerospace.org:443 | openssl x509 -noout -dates
```

### Step 5: Test Jitsi Functionality
1. Open browser to https://meet.awsaerospace.org
2. Verify Jitsi Meet interface loads
3. Create a test room
4. Verify room creation works

### Step 6: Scale Down Service
```bash
./scale-down.sh
```
Expected: Service scales back to 0 instances

### Step 7: Verify Cleanup
```bash
./status.sh
```
Expected: Service should be back in standby mode (0 instances)

## Infrastructure Components

### ECS Service Configuration
- **Cluster**: `jitsi-video-platform-cluster`
- **Service**: `jitsi-video-platform-service`
- **Task Definition**: Multi-container Jitsi Meet stack
  - `jitsi-web`: Web interface (port 80/443)
  - `prosody`: XMPP server
  - `jicofo`: Conference focus
  - `jvb`: Video bridge (port 10000 UDP)

### Network Load Balancer
- **HTTPS Listener**: Port 443 with TLS termination
- **JVB Listener**: Port 10000 UDP for video traffic
- **Health Checks**: HTTP on port 80 for web container

### SSL Certificate
- **Domain**: meet.awsaerospace.org
- **Provider**: AWS Certificate Manager
- **Validation**: DNS validation

## Testing Scripts Reference

### test-platform.sh
**Purpose**: Main orchestration script for complete testing workflow

**Features**:
- Prerequisites verification
- Automated scaling operations
- Health verification
- SSL certificate validation
- HTTPS access testing
- Jitsi functionality testing
- Cleanup and verification
- Comprehensive logging

**Usage**:
```bash
./test-platform.sh
```

**Log Location**: `/tmp/jitsi-test-YYYYMMDD-HHMMSS.log`

### scale-up.sh
**Purpose**: Scale ECS service from 0 to 1 with health verification

**Features**:
- Service existence verification
- Current status checking
- Scale-up execution
- Stability waiting (10-minute timeout)
- Task health verification
- Load balancer target health
- Detailed status reporting

**Usage**:
```bash
./scale-up.sh
```

### scale-down.sh
**Purpose**: Scale ECS service to 0 with verification

**Features**:
- Graceful scale-down
- Task termination monitoring
- Load balancer target draining
- Cleanup verification
- Cost optimization confirmation

**Usage**:
```bash
./scale-down.sh
```

### check-health.sh
**Purpose**: Comprehensive health verification

**Health Checks**:
1. ECS Service Status
2. Task Health Status
3. Load Balancer Targets
4. DNS Resolution
5. HTTPS Connectivity
6. SSL Certificate
7. Application Response

**Usage**:
```bash
./check-health.sh
```

### status.sh
**Purpose**: Detailed platform status reporting

**Information Displayed**:
- ECS service status
- Task details and health
- Load balancer status
- Network connectivity
- Resource utilization
- Cost estimation

**Usage**:
```bash
./status.sh
```

## Troubleshooting

### Common Issues

#### 1. Service Won't Scale Up
**Symptoms**: Scale-up command succeeds but tasks don't start
**Possible Causes**:
- Insufficient CPU/memory resources
- Task definition issues
- Network configuration problems
- IAM permission issues

**Debugging**:
```bash
# Check ECS events
aws ecs describe-services --cluster jitsi-video-platform-cluster --services jitsi-video-platform-service --profile jitsi-dev

# Check task logs
aws logs describe-log-streams --log-group-name /ecs/jitsi-video-platform --profile jitsi-dev
```

#### 2. Health Checks Failing
**Symptoms**: Tasks start but health checks fail
**Possible Causes**:
- Container startup time too long
- Application configuration issues
- Port mapping problems

**Debugging**:
```bash
# Check container logs
aws logs get-log-events --log-group-name /ecs/jitsi-video-platform --log-stream-name [stream-name] --profile jitsi-dev

# Test container health manually
curl -I http://[task-ip]:80/
```

#### 3. HTTPS Access Issues
**Symptoms**: Can't access https://meet.awsaerospace.org
**Possible Causes**:
- DNS resolution issues
- Load balancer configuration
- SSL certificate problems
- Security group rules

**Debugging**:
```bash
# Test DNS
nslookup meet.awsaerospace.org

# Test load balancer
aws elbv2 describe-load-balancers --profile jitsi-dev

# Check security groups
aws ec2 describe-security-groups --group-ids [sg-id] --profile jitsi-dev
```

#### 4. Jitsi Functionality Issues
**Symptoms**: Interface loads but rooms don't work
**Possible Causes**:
- XMPP server configuration
- Component communication issues
- JVB connectivity problems

**Debugging**:
```bash
# Check all container logs
./status.sh

# Test JVB connectivity
nc -u [load-balancer-ip] 10000
```

## Performance Considerations

### Resource Allocation
- **CPU**: 2048 units (2 vCPU) per task
- **Memory**: 4096 MB (4 GB) per task
- **Network**: Enhanced networking enabled

### Scaling Characteristics
- **Scale-up time**: ~2-3 minutes
- **Scale-down time**: ~30-60 seconds
- **Health check stabilization**: ~1-2 minutes

### Cost Optimization
- **Standby cost**: $0.00/hour (scaled to zero)
- **Active cost**: ~$0.20/hour (approximate, varies by region)
- **Automatic scaling**: Manual via scripts (can be automated)

## Security Considerations

### Network Security
- HTTPS-only access (port 443)
- JVB UDP port 10000 for media
- No direct container access
- VPC isolation

### SSL/TLS
- AWS Certificate Manager integration
- TLS 1.2+ enforcement
- Automatic certificate renewal

### Access Control
- AWS IAM integration
- Profile-based authentication
- Least privilege principles

## Monitoring and Logging

### CloudWatch Integration
- Container logs: `/ecs/jitsi-video-platform`
- Service metrics: ECS CloudWatch metrics
- Load balancer metrics: ELB CloudWatch metrics

### Log Retention
- Default: 7 days
- Configurable via Terraform

### Alerting
- Can be configured via CloudWatch Alarms
- Integration with SNS for notifications

## Automation Integration

### CI/CD Integration
All scripts return proper exit codes:
- `0`: Success
- `1`: Failure

### Scheduled Testing
Scripts can be run via cron or scheduled tasks:
```bash
# Daily health check at 9 AM
0 9 * * * /path/to/scripts/check-health.sh

# Weekly full test on Sundays at 2 AM
0 2 * * 0 /path/to/scripts/test-platform.sh
```

### Monitoring Integration
Scripts can be integrated with monitoring systems:
- Nagios/Icinga checks
- Prometheus exporters
- Custom monitoring solutions

## Support and Maintenance

### Regular Maintenance Tasks
1. **Weekly**: Run full test suite
2. **Monthly**: Review logs and performance
3. **Quarterly**: Update container images
4. **Annually**: Review SSL certificates

### Backup and Recovery
- Infrastructure: Terraform state backup
- Configuration: Git repository backup
- Logs: CloudWatch retention policy

### Updates and Patches
- Container images: Jitsi stable releases
- Infrastructure: Terraform updates
- Scripts: Version control via Git

For additional support or questions, refer to the project documentation or contact the platform administrators.