#!/bin/bash

# Setup script for Jitsi Platform operational scripts
# Makes all shell scripts executable and verifies prerequisites

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up Jitsi Platform operational scripts...${NC}"

# Make shell scripts executable
echo "Making shell scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh

# Verify scripts are executable
echo "Verifying script permissions..."
for script in test-platform.sh scale-up.sh scale-down.sh check-health.sh status.sh; do
    if [ -x "$SCRIPT_DIR/$script" ]; then
        echo "  ✓ $script"
    else
        echo "  ✗ $script (failed to make executable)"
        exit 1
    fi
done

echo -e "${GREEN}Setup completed successfully!${NC}"
echo
echo "Available scripts:"
echo "  ./test-platform.sh  - Complete testing workflow"
echo "  ./scale-up.sh       - Scale service up"
echo "  ./scale-down.sh     - Scale service down"
echo "  ./check-health.sh   - Health verification"
echo "  ./status.sh         - Platform status"
echo
echo "Run './test-platform.sh' to start comprehensive testing."