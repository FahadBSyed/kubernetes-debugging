#!/bin/bash

# Exit on any error
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================="
echo "Kind Cluster - Install Dependencies"
echo "===================================${NC}"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}This script must be run with sudo${NC}"
   exit 1
fi

# Update package lists
echo -e "${BLUE}Updating package lists...${NC}"
apt-get update

# Function to install package if not exists
install_if_missing() {
    local cmd=$1
    local package=$2
    local display_name=$3
    
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${BLUE}Installing $display_name...${NC}"
        apt-get install -y "$package"
        echo -e "${GREEN}✓ $display_name installed${NC}"
    else
        echo -e "${GREEN}✓ $display_name already installed${NC}"
    fi
}

# Install Docker
if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}Installing Docker...${NC}"
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}✓ Docker installed and started${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Install kubectl
install_if_missing "kubectl" "kubectl" "kubectl"

# Install Kind
if ! command -v kind &> /dev/null; then
    echo -e "${BLUE}Installing Kind...${NC}"
    curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
    chmod +x /usr/local/bin/kind
    echo -e "${GREEN}✓ Kind installed${NC}"
else
    echo -e "${GREEN}✓ Kind already installed${NC}"
fi

# Install additional useful tools
install_if_missing "git" "git" "Git"
install_if_missing "curl" "curl" "curl"
install_if_missing "jq" "jq" "jq"

echo ""
echo -e "${BLUE}Setting up Docker permissions...${NC}"
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    echo -e "${GREEN}✓ Added $SUDO_USER to docker group${NC}"
    echo -e "${YELLOW}Note: User may need to log out and back in for group changes to take effect${NC}"
fi

echo ""
echo -e "${GREEN}All dependencies installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Verify installation: ./scripts/check-dependencies.sh"
echo "2. Create cluster: ./scripts/create-cluster.sh"
