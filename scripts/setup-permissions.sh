#!/bin/bash

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==================================="
echo "Kind Cluster - Setup Permissions"
echo "===================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run with sudo${NC}"
    echo "Run: sudo ./scripts/setup-permissions.sh"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}Making scripts executable...${NC}"
chmod +x "$SCRIPT_DIR"/*.sh
echo -e "${GREEN}✓ All scripts are now executable${NC}"
echo ""

echo -e "${BLUE}Setting up Docker permissions...${NC}"

# Get the user who invoked sudo
REAL_USER="${SUDO_USER:-$(whoami)}"

if [ "$REAL_USER" = "root" ]; then
    echo -e "${YELLOW}Running as root, skipping user group setup${NC}"
else
    # Add user to docker group
    if id -nG "$REAL_USER" | grep -qw docker; then
        echo -e "${GREEN}✓ User '$REAL_USER' is already in docker group${NC}"
    else
        usermod -aG docker "$REAL_USER"
        echo -e "${GREEN}✓ Added user '$REAL_USER' to docker group${NC}"
        echo -e "${YELLOW}Note: User may need to log out and back in for group changes to take effect${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Checking script directory permissions...${NC}"
ls -la "$SCRIPT_DIR"
echo ""

echo -e "${GREEN}Permissions setup complete!${NC}"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "1. Check dependencies: ${BLUE}./scripts/check-dependencies.sh${NC}"
echo "2. Install missing packages: ${BLUE}sudo ./scripts/install-dependencies.sh${NC}"
echo "3. Create cluster: ${BLUE}./scripts/create-cluster.sh${NC}"
echo "4. View logs: ${BLUE}./scripts/view-logs.sh${NC}"
