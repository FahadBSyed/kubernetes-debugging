#!/bin/bash

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="${1:-kind-cluster}"

echo -e "${BLUE}==================================="
echo "Kind Cluster - View Logs"
echo "===================================${NC}"
echo ""

echo -e "${BLUE}Cluster Status:${NC}"
kind get clusters
echo ""

echo -e "${BLUE}Available Clusters and Contexts:${NC}"
kubectl config get-contexts 2>/dev/null || echo "No contexts available"
echo ""

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${BLUE}Cluster: $CLUSTER_NAME${NC}"
    echo -e "${GREEN}Node Status:${NC}"
    kubectl get nodes --context "kind-${CLUSTER_NAME}" 2>/dev/null || echo "Unable to get nodes"
    echo ""
    
    echo -e "${GREEN}System Pods:${NC}"
    kubectl get pods -n kube-system --context "kind-${CLUSTER_NAME}" 2>/dev/null || echo "Unable to get pods"
    echo ""
    
    echo -e "${GREEN}All Namespaces:${NC}"
    kubectl get ns --context "kind-${CLUSTER_NAME}" 2>/dev/null || echo "Unable to get namespaces"
    echo ""
else
    echo -e "${YELLOW}Cluster '$CLUSTER_NAME' not found${NC}"
    echo -e "Run ${BLUE}./scripts/create-cluster.sh${NC} to create it"
fi
