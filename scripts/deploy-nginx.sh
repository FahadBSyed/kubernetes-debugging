#!/bin/bash

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==================================="
echo "Kind Cluster - Deploy Nginx"
echo "===================================${NC}"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

echo "Creating namespace 'demo' (if missing)..."
kubectl create namespace demo >/dev/null 2>&1 || echo "Namespace 'demo' already exists"

echo "Applying nginx manifest into namespace 'demo'..."
kubectl apply -f "$SCRIPT_DIR/nginx-deployment.yaml"

echo "Waiting for nginx pods to become ready..."
kubectl -n demo wait --for=condition=ready pod -l app=nginx --timeout=120s || true

echo -e "${GREEN}Nginx pods status:${NC}"
kubectl -n demo get pods -o wide

echo -e "${GREEN}✓ Nginx deployment complete${NC}"
