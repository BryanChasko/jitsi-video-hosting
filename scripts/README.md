# Operational Scripts

This directory contains operational scripts for managing the Jitsi platform.

## Available Scripts:

- `project-status.pl` - Display current project status including ECS service counts and load balancer DNS
- `scale-up.pl` - Scale ECS service from 0 to 1
- `scale-down.pl` - Scale ECS service from 1 to 0

## Usage:

### Project Status
```bash
# Make script executable (if not already)
chmod +x project-status.pl

# Run status check
./project-status.pl
```

Example output:
```
Project: Jitsi Video Platform
ECS Service: jitsi-video-platform-service (0/0 running)
Load Balancer: jitsi-video-platform-nlb-6005dd61c01ffd11.elb.us-west-2.amazonaws.com
Status: Scaled to zero
```

## Scripts to be implemented by Amazon Q Developer:

- `test-platform.sh` - Complete platform testing workflow
- `check-health.sh` - Verify platform health and status

## Requirements:
- Use AWS CLI with `jitsi-dev` profile
- Proper error handling and logging
- Clear status output for operators
- Support for scale-to-zero architecture