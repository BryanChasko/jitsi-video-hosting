# Operational Scripts

This directory contains operational scripts for managing the Jitsi platform.

## Scripts to be implemented by Amazon Q Developer:

- `test-platform.sh` - Complete platform testing workflow
- `scale-up.sh` - Scale ECS service from 0 to 1
- `scale-down.sh` - Scale ECS service from 1 to 0  
- `check-health.sh` - Verify platform health and status
- `status.sh` - Display current platform status

## Requirements:
- Use AWS CLI with `jitsi-dev` profile
- Proper error handling and logging
- Clear status output for operators
- Support for scale-to-zero architecture