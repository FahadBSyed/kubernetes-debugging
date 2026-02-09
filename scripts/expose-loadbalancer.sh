#!/bin/bash

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==================================="
echo "Kind Cluster - Expose Nginx as LoadBalancer"
echo "===================================${NC}"
echo ""

# Get the real user's kubeconfig
if [ "$EUID" -eq 0 ]; then
    REAL_USER="${SUDO_USER:-root}"
    REAL_HOME=$(eval echo "~$REAL_USER")
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

KUBE_DIR="$REAL_HOME/.kube"
KUBE_CONFIG="$KUBE_DIR/config"

echo "Patching nginx service to LoadBalancer..."
kubectl -n demo patch svc nginx -p '{"spec":{"type":"LoadBalancer"}}' --kubeconfig "$KUBE_CONFIG" || echo "Service already patched or patch failed (non-fatal)"

echo "Waiting for external IP assignment (MetalLB)..."
LB_IP=""
attempt=0
max_attempts=60
while [ $attempt -lt $max_attempts ]; do
    LB_IP=$(kubectl -n demo get svc nginx --kubeconfig "$KUBE_CONFIG" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [ -n "$LB_IP" ]; then
        echo -e "${GREEN}✓ External IP assigned: $LB_IP${NC}"
        break
    fi
    echo "Waiting for external IP... ($attempt/$max_attempts)"
    sleep 2
    attempt=$((attempt+1))
done

if [ -z "$LB_IP" ]; then
    echo -e "${YELLOW}Warning: LoadBalancer IP not assigned. MetalLB may not have configured the pool correctly.${NC}"
    exit 1
else
    echo -e "${GREEN}✓ LoadBalancer IP: $LB_IP${NC}"
fi
