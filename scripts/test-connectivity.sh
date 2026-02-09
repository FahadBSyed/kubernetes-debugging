#!/bin/bash

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==================================="
echo "Kind Cluster - Test Nginx Connectivity"
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

# Get the LoadBalancer IP
echo "Retrieving LoadBalancer IP..."
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

# Test connectivity with retries
if [ -z "$LB_IP" ]; then
    echo -e "${YELLOW}Warning: no LoadBalancer IP available to test connectivity.${NC}"
    exit 1
else
    CURL_RETRIES=5
    CURL_ATTEMPT=1
    SUCCESS=0
    echo ""
    echo "Testing connectivity to Nginx..."
    while [ $CURL_ATTEMPT -le $CURL_RETRIES ]; do
        if curl -sS --max-time 5 "http://$LB_IP:80" >/dev/null 2>&1; then
            # Successful probe; only show the reachable URL and port
            echo -e "${GREEN}✓ Nginx reachable at: http://$LB_IP:80${NC}"
            SUCCESS=1
            break
        else
            if [ $CURL_ATTEMPT -lt $CURL_RETRIES ]; then
                sleep 2
            fi
        fi
        CURL_ATTEMPT=$((CURL_ATTEMPT+1))
    done

    if [ $SUCCESS -ne 1 ]; then
        echo -e "${YELLOW}Warning: nginx did not respond at http://$LB_IP:80 after $CURL_RETRIES attempts.${NC}"
        exit 1
    fi
fi
