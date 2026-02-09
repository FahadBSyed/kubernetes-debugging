#!/bin/bash

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==================================="
echo "Kind Cluster - Install MetalLB"
echo "===================================${NC}"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Step 1: Install MetalLB manifests
METALLB_URL="https://raw.githubusercontent.com/metallb/metallb/refs/tags/v0.13.12/config/manifests/metallb-native.yaml"
LOCAL_METALLB_MANIFEST="$SCRIPT_DIR/config/metallb-native.yaml"

echo "Installing MetalLB manifests..."
# Try to download the exact manifest and save as a local backup; fall back to local copy if download fails
if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$METALLB_URL" -o "$LOCAL_METALLB_MANIFEST"; then
        echo "Saved MetalLB manifest to $LOCAL_METALLB_MANIFEST"
        kubectl apply -f "$LOCAL_METALLB_MANIFEST"
    else
        echo "Could not fetch $METALLB_URL"
        if [ -f "$LOCAL_METALLB_MANIFEST" ]; then
            echo "Using existing local manifest: $LOCAL_METALLB_MANIFEST"
            kubectl apply -f "$LOCAL_METALLB_MANIFEST"
        else
            echo -e "${RED}Error: MetalLB manifest unavailable (network failure and no local backup).${NC}"
            exit 1
        fi
    fi
else
    echo "curl is not available; attempting to use local manifest if present"
    if [ -f "$LOCAL_METALLB_MANIFEST" ]; then
        kubectl apply -f "$LOCAL_METALLB_MANIFEST"
    else
        echo -e "${RED}Error: curl not found and no local MetalLB manifest available. Install curl or add $LOCAL_METALLB_MANIFEST${NC}"
        exit 1
    fi
fi

echo "Waiting for MetalLB pods to be ready..."
sleep 3
max=30
count=0
while [ $count -lt $max ]; do
    ready=$(kubectl -n metallb-system get pods --no-headers 2>/dev/null | grep -c "Running" || true)
    total=$(kubectl -n metallb-system get pods --no-headers 2>/dev/null | wc -l || true)
    if [ "$total" -gt 0 ] && [ "$ready" -eq "$total" ]; then
        echo -e "${GREEN}✓ MetalLB pods are running${NC}"
        break
    fi
    echo "Waiting for MetalLB pods ($ready/$total)"
    sleep 2
    count=$((count+1))
done

if [ $count -eq $max ]; then
    echo -e "${YELLOW}Warning: MetalLB pods may not be ready yet${NC}"
fi

# Step 2: Configure MetalLB IPAddressPool & L2Advertisement
echo ""
echo "Configuring MetalLB IPAddressPool & L2Advertisement..."
METALLB_CFG="$SCRIPT_DIR/config/metallb-pool.yaml"
if [ ! -f "$METALLB_CFG" ]; then
    cat > "$METALLB_CFG" <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: kind-pool
    namespace: metallb-system
spec:
    addresses:
    - 172.18.0.240-172.18.0.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: l2
    namespace: metallb-system
spec: {}
EOF
    echo "Created $METALLB_CFG"
fi

# Retry applying the pool configuration (webhooks may not be ready yet)
echo "Applying MetalLB pool configuration (with retries for webhook readiness)..."
MAX_RETRIES=10
RETRY_COUNT=0
RETRY_DELAY=3
SUCCESS=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if kubectl apply -f "$METALLB_CFG" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Configured MetalLB IP pool${NC}"
        SUCCESS=1
        break
    else
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "Webhooks not ready yet, retrying... ($RETRY_COUNT/$MAX_RETRIES)"
            sleep $RETRY_DELAY
        fi
    fi
done

if [ $SUCCESS -ne 1 ]; then
    echo -e "${RED}Error: Failed to apply MetalLB pool configuration after $MAX_RETRIES attempts${NC}"
    # Try one more time to show the actual error
    echo "Attempting final apply to show error details:"
    kubectl apply -f "$METALLB_CFG"
    exit 1
fi
