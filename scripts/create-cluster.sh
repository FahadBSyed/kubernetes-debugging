#!/bin/bash

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLUSTER_NAME="${1:-kind-cluster}"
CONFIG_FILE="config/kind-cluster-config.yaml"

echo -e "${BLUE}==================================="
echo "Kind Cluster - Create Cluster"
echo "===================================${NC}"
echo ""

# Verify dependencies
echo -e "${BLUE}Verifying dependencies...${NC}"
for cmd in docker kind kubectl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}✗ $cmd not found. Please install dependencies first.${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ All dependencies available${NC}"
echo ""

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}Cluster '$CLUSTER_NAME' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Deleting existing cluster...${NC}"
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo -e "${GREEN}Keeping existing cluster${NC}"
        exit 0
    fi
fi

# Create cluster
echo -e "${BLUE}Creating Kind cluster '$CLUSTER_NAME'...${NC}"
echo "Using config: $CONFIG_FILE"
echo ""

if [ -f "$CONFIG_FILE" ]; then
    kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_FILE"
else
    echo -e "${YELLOW}Config file not found, creating with default settings...${NC}"
    kind create cluster --name "$CLUSTER_NAME"
fi

# Verify cluster
echo ""
echo -e "${BLUE}Verifying cluster...${NC}"
kubectl cluster-info --context "kind-${CLUSTER_NAME}"
echo ""

# Get cluster info
echo -e "${BLUE}Cluster Details:${NC}"
echo -e "Name: ${GREEN}$CLUSTER_NAME${NC}"
echo -e "Context: ${GREEN}kind-${CLUSTER_NAME}${NC}"
echo ""

# Show nodes
echo -e "${BLUE}Nodes:${NC}"
kubectl get nodes
echo ""

# Show system pods
echo -e "${BLUE}System Namespace Pods:${NC}"
kubectl get pods -n kube-system
echo ""

echo -e "${GREEN}✓ Cluster created successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "- View cluster status: kind get clusters"
echo "- Get cluster info: kubectl cluster-info --context kind-${CLUSTER_NAME}"
echo "- Deploy apps: kubectl apply -f <manifest-file>"
echo "- Delete cluster: kind delete cluster --name ${CLUSTER_NAME}"
echo "- View logs: ./scripts/view-logs.sh"
