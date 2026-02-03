#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "==================================="
echo "Kind Cluster - Dependency Check"
echo "==================================="
echo ""

# Initialize counters
MISSING=0
INSTALLED=0

# Function to check if command exists
check_command() {
    local cmd=$1
    local display_name=$2
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓${NC} $display_name: ${GREEN}installed${NC}"
        echo "  Version: $version"
        ((INSTALLED++))
    else
        echo -e "${RED}✗${NC} $display_name: ${RED}NOT installed${NC}"
        ((MISSING++))
    fi
}

# Function to check if service is running
check_service() {
    local service=$1
    local display_name=$2
    
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓${NC} $display_name service: ${GREEN}running${NC}"
    else
        echo -e "${YELLOW}!${NC} $display_name service: ${YELLOW}not running${NC}"
    fi
}

echo "Checking core dependencies..."
echo "-----------------------------------"
check_command "docker" "Docker"
check_command "kind" "Kind"
check_command "kubectl" "kubectl"
check_command "git" "Git"

echo ""
echo "Checking optional dependencies..."
echo "-----------------------------------"
check_command "helm" "Helm"
check_command "jq" "jq"

echo ""
echo "Checking system services..."
echo "-----------------------------------"
check_service "docker" "Docker"

echo ""
echo "Checking permissions..."
echo "-----------------------------------"
if groups | grep -q docker; then
    echo -e "${GREEN}✓${NC} User is in docker group: ${GREEN}yes${NC}"
else
    echo -e "${RED}✗${NC} User is in docker group: ${RED}no${NC}"
    echo "  Run: sudo usermod -aG docker \$USER && newgrp docker"
fi

echo ""
echo "-----------------------------------"
echo "Summary:"
echo "  Installed: $INSTALLED"
echo "  Missing: $MISSING"
echo "-----------------------------------"

if [ "$MISSING" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Run 'scripts/install-dependencies.sh' to install missing packages${NC}"
    exit 1
else
    echo -e "${GREEN}All dependencies are installed!${NC}"
    exit 0
fi
