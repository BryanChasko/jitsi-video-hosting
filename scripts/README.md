# Operational Scripts

This directory contains operational scripts for managing the Jitsi platform.

## Available Scripts:

### Shell Scripts (Primary)
- `test-platform.sh` - **Complete platform testing workflow** - Main orchestration script
- `scale-up.sh` - Scale ECS service from 0 to 1 with health verification
- `scale-down.sh` - Scale ECS service from current count to 0 with verification
- `check-health.sh` - Comprehensive platform health verification
- `status.sh` - Display detailed current platform status

### Perl Scripts (Legacy)
- `scale-up.pl` - Basic scale-up script (legacy)
- `scale-down.pl` - Basic scale-down script (legacy)

## Usage:

### Quick Testing
```bash
# Run complete testing workflow
./test-platform.sh

# Check current status
./status.sh
```

### Manual Operations
```bash
# Scale up platform
./scale-up.sh

# Verify health
./check-health.sh

# Scale down platform
./scale-down.sh
```

## Requirements:
- AWS CLI configured with `jitsi-dev` profile
- Required tools: `curl`, `jq`, `openssl`, `bc`, `nslookup`
- Proper IAM permissions for ECS and ELB operations
- Internet connectivity for HTTPS testing

## Features:
- ✅ Comprehensive error handling and logging
- ✅ Clear status output for operators
- ✅ Support for scale-to-zero architecture
- ✅ SSL certificate validation
- ✅ Load balancer health monitoring
- ✅ Application functionality testing
- ✅ Cost optimization reporting

## Testing Workflow:
1. Prerequisites check
2. Initial status verification
3. Scale up service (0→1)
4. Health verification
5. SSL certificate validation
6. HTTPS access testing
7. Jitsi functionality testing
8. Scale down service (1→0)
9. Cleanup verification

All scripts include detailed logging and proper exit codes for automation integration.