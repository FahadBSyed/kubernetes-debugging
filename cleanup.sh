#!/bin/bash

# Clean up and completely remove Kind cluster and related resources
# This script removes all traces of the Kind cluster for a fresh start

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLUSTER_NAME="${1:-kind-cluster}"

echo -e "${BLUE}╔═══════════════════════════════════════════╗"
echo "║  Kind Cluster - Cleanup Script              ║"
echo "╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}This will delete the '$CLUSTER_NAME' cluster and clean up resources${NC}"
echo ""

# Confirmation
read -p "Are you sure? This cannot be undone. (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi
    echo "To deploy again, run:"

echo ""
echo -e "${BLUE}Starting cleanup...${NC}"
    # Stop any background kubectl port-forward started by setup
echo ""

# Check if cluster exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${BLUE}Deleting Kind cluster: $CLUSTER_NAME${NC}"
    kind delete cluster --name "$CLUSTER_NAME"
    echo -e "${GREEN}✓ Cluster deleted${NC}"
else
    echo -e "${YELLOW}No cluster named '$CLUSTER_NAME' found${NC}"
    # Kill any remaining listeners on localhost:8080
fi

echo ""

# Optional: Clean up Docker images
read -p "Remove unused Docker images and volumes? (y/n) " -n 1 -r
    # Remove port-forward log
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Pruning Docker resources...${NC}"
    docker system prune -f
    # Revoke Codespaces port visibility (if gh CLI available)
    echo -e "${GREEN}✓ Docker cleanup complete${NC}"
fi

echo ""
echo -e "${GREEN}Cleanup complete!${NC}"
echo ""
echo "To deploy again, run:"
echo -e "${BLUE}  sudo ./full-setup.sh${NC}"
echo ""
