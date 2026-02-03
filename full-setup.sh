#!/bin/bash


# =============================================================================
# Kind Cluster Full Setup Script
# =============================================================================
# This script provides a complete, repeatable setup for a local Kubernetes cluster
# using Kind (Kubernetes-in-Docker), MetalLB for LoadBalancer support, and an nginx demo.
#
# STRUCTURE OVERVIEW:
# - The script is organized as a series of numbered steps, each guarded by a conditional
#   so you can resume from any step using --start-step/-s.
# - Each step prints a banner and performs a focused task (e.g., dependency check, cluster creation).
# - Helper functions are defined at the top for step control and output formatting.
#
# HELPER FUNCTIONS:
# - should_run <step_number>:
#     Returns 0 (true) if the current step should execute, based on the --start-step argument.
#     This allows the script to be resumed from any step, skipping earlier ones.
# - print_step <step_number> <description>:
#     Prints a formatted banner for each step for clarity in logs and output.
#
# HOW TO EXPAND:
# - To add a new step, increment the step number and wrap the logic in:
#       if should_run <N>; then
#           print_step "<N>" "Description of new step"
#           ...your logic...
#       fi
# - Steps can be reordered or new ones inserted without breaking resume logic.
# - Each step should be idempotent if possible, so rerunning from any step is safe.
#
# USAGE:
#   ./full-setup.sh                # Run all steps from the beginning
#   ./full-setup.sh -s 8           # Resume from step 8
#   ./full-setup.sh -c mycluster   # Use a custom Kind cluster name
#
# See the README for more details and troubleshooting.
# =============================================================================

set -e

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
# Parse CLI args: support optional --start-step/-s and cluster name via -c/--cluster or positional
START_STEP=""
CLUSTER_NAME=""
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--start-step)
            START_STEP="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -* )
            echo "Unknown option: $1"
            shift
            ;;
        * )
            if [ -z "$CLUSTER_NAME" ]; then
                CLUSTER_NAME="$1"
            fi
            shift
            ;;
    esac
done

# Default cluster name
CLUSTER_NAME="${CLUSTER_NAME:-kind-cluster}"

# Determine the real user (handle both sudo and non-sudo execution)
if [ "$EUID" -eq 0 ]; then
    REAL_USER="${SUDO_USER:-root}"
    REAL_HOME=$(eval echo "~$REAL_USER")
else
    REAL_USER="$USER"
    REAL_HOME="$HOME"
fi

# These paths will be used later in the different steps. 
# We define them here to ensure they are consistent regardless of where the user starts.
KUBE_DIR="$REAL_HOME/.kube"
KUBE_CONFIG="$KUBE_DIR/config"

# Helper: return 0 if the given step should run
should_run() {
    local step=$1
    if [ -z "$START_STEP" ]; then
        return 0
    fi
    if ! [[ "$START_STEP" =~ ^[0-9]+$ ]]; then
        # non-numeric start-step; ignore
        return 0
    fi
    if [ "$step" -lt "$START_STEP" ]; then
        return 1
    fi
    return 0
}

# Banner
echo -e "${BLUE}╔═══════════════════════════════════════════╗"
echo "║  Kind Cluster - Complete Setup Script      ║"
echo "║  Single invocation deployment               ║"
echo "╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Cluster Name: ${GREEN}$CLUSTER_NAME${NC}"
echo ""

# Function to print step headers
print_step() {
    local step=$1
    local description=$2
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Step $step: $description${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================================
# Step 1: Request sudo privileges if needed
# ============================================================================
if should_run 1; then
    print_step "1" "Verifying sudo access"

    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}This script requires sudo for installation steps${NC}"
        echo "Requesting sudo access..."
        # Test sudo access
        if ! sudo -l > /dev/null 2>&1; then
            echo -e "${RED}✗ Sudo access denied${NC}"
            exit 1
        fi
        echo -e "${GREEN}✓ Sudo access verified${NC}"
    else
        echo -e "${GREEN}✓ Running as root${NC}"
    fi
    echo ""
fi

# ============================================================================
# Step 2: Make scripts executable
# ============================================================================
if should_run 2; then
    print_step "2" "Setting up script permissions"

    echo "Making scripts executable..."
    sudo chmod +x "$SCRIPT_DIR/scripts"/*.sh
    echo -e "${GREEN}✓ All scripts are executable${NC}"
    echo ""
fi

# ============================================================================
# Step 3: Check current dependencies
# ============================================================================
if should_run 3; then
    print_step "3" "Checking dependencies"

    echo "Analyzing environment..."
    if "$SCRIPT_DIR/scripts/check-dependencies.sh" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ All dependencies already installed${NC}"
        INSTALL_DEPS=0
    else
        echo -e "${YELLOW}⚠ Some dependencies are missing${NC}"
        INSTALL_DEPS=1
    fi
    echo ""
fi

# ============================================================================
# Step 4: Install missing dependencies (if needed)
# ============================================================================
if should_run 4; then
    if [ "$INSTALL_DEPS" -eq 1 ]; then
        print_step "4" "Installing dependencies"
        echo "Installing missing packages..."
        sudo "$SCRIPT_DIR/scripts/install-dependencies.sh"
        echo ""
    fi
fi

# ============================================================================
# Step 5: Setup Docker permissions
# ============================================================================
if should_run 5; then
    print_step "5" "Setting up Docker permissions"

    if [ "$EUID" -ne 0 ]; then
        REAL_USER="${SUDO_USER:-$(whoami)}"
    else
        REAL_USER="${USER:-root}"
    fi

    if groups | grep -q docker; then
        echo -e "${GREEN}✓ User already in docker group${NC}"
    else
        echo "Adding user to docker group..."
        sudo usermod -aG docker "$REAL_USER"
        echo -e "${GREEN}✓ User added to docker group${NC}"
        echo -e "${YELLOW}Note: Changes take effect on next login${NC}"
    fi
    echo ""
fi

# ============================================================================
# Step 6: Check for existing cluster
# ============================================================================
if should_run 6; then
    print_step "6" "Checking for existing cluster"

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        echo -e "${YELLOW}Cluster '$CLUSTER_NAME' already exists${NC}"
        read -p "Delete and recreate it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Deleting existing cluster..."
            kind delete cluster --name "$CLUSTER_NAME"
            echo -e "${GREEN}✓ Cluster deleted${NC}"
        else
            echo -e "${GREEN}✓ Using existing cluster${NC}"
            echo ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${GREEN}Setup Complete!${NC}"
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ No existing cluster found${NC}"
    fi
    echo ""
fi

# ============================================================================
# Step 7: Create the cluster
# ============================================================================
if should_run 7; then
    print_step "7" "Creating Kind cluster"

    echo "Creating cluster '$CLUSTER_NAME'..."
    kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/config/kind-cluster-config.yaml"
    echo ""
fi

# ============================================================================
# Step 8: Verify cluster health
# ============================================================================
if should_run 8; then
    print_step "8" "Verifying cluster health"

    echo -e "${BLUE}Waiting for all nodes to be Ready...${NC}"
    max_attempts=30
    attempt=0

    while [ "$attempt" -lt "$max_attempts" ]; do
        ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c "Ready" || echo 0)
        total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo 0)
        
        if [ "$ready_nodes" -eq "$total_nodes" ] && [ "$total_nodes" -gt 0 ]; then
            echo -e "${GREEN}✓ All $total_nodes nodes are Ready${NC}"
            break
        fi
        
        echo "Waiting... ($ready_nodes/$total_nodes nodes ready)"
        sleep 2
        ((attempt++))
    done

    if [ "$attempt" -eq "$max_attempts" ]; then
        echo -e "${YELLOW}⚠ Timeout waiting for nodes to be ready${NC}"
    else
        echo ""
    fi
fi

# ============================================================================
# Step 9: Display cluster information
# ============================================================================
if should_run 9; then
    print_step "9" "Cluster information"

    echo -e "${GREEN}Nodes:${NC}"
    kubectl get nodes -o wide
    echo ""

    echo -e "${GREEN}System Namespace Status:${NC}"
    kubectl get pods -n kube-system --no-headers | wc -l | xargs echo "Total pods:"
    running=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c "Running" || echo 0)
    echo "Running: $running"
    echo ""

    echo -e "${GREEN}Cluster Information:${NC}"
    echo "Name: $CLUSTER_NAME"
    echo "Context: kind-${CLUSTER_NAME}"
    echo "API Server: $(kubectl cluster-info 2>/dev/null | grep 'Kubernetes master' | sed 's/.*Kubernetes master.* //')"
    echo ""
fi

# ============================================================================
# Step 10: Save kubeconfig to default location
# ============================================================================
if should_run 10; then
    print_step "10" "Configuring kubectl access"

    KUBE_DIR="$REAL_HOME/.kube"
    KUBE_CONFIG="$KUBE_DIR/config"

    # Create .kube directory if it does not exist
    if [ ! -d "$KUBE_DIR" ]; then
        mkdir -p "$KUBE_DIR"
        chmod 700 "$KUBE_DIR"
        chown "$REAL_USER:$REAL_USER" "$KUBE_DIR" 2>/dev/null || true
        echo "Created $KUBE_DIR"
    fi

    # Save kubeconfig to default location
    echo "Saving kubeconfig to $KUBE_CONFIG..."
    kind get kubeconfig --name "$CLUSTER_NAME" > "$KUBE_CONFIG"
    chmod 600 "$KUBE_CONFIG"
    chown "$REAL_USER:$REAL_USER" "$KUBE_CONFIG" 2>/dev/null || true
    echo "✓ Kubeconfig saved to $KUBE_CONFIG"
    echo ""

    # Verify kubectl access (for the real user)
    echo "Verifying kubectl access..."
    if sudo -u "$REAL_USER" KUBECONFIG="$KUBE_CONFIG" kubectl cluster-info > /dev/null 2>&1; then
        echo "✓ kubectl is configured and ready"
        echo "   User: $REAL_USER"
    else
        echo "⚠ kubectl access could not be verified, but kubeconfig has been saved"
        echo "   Try running: kubectl get nodes"
    fi
    echo ""
fi

# ============================================================================
# Step 11: Create `demo` namespace and deploy nginx
# ============================================================================
if should_run 11; then
    print_step "11" "Create 'demo' namespace and deploy nginx"

    echo "Creating namespace 'demo' (if missing)..."
    kubectl create namespace demo >/dev/null 2>&1 || true

    echo "Applying nginx manifest into namespace 'demo'..."
    kubectl apply -f "$SCRIPT_DIR/nginx-deployment.yaml"

    echo "Waiting for nginx pods to become ready..."
    kubectl -n demo wait --for=condition=ready pod -l app=nginx --timeout=120s || true
    kubectl -n demo get pods -o wide
fi

# ============================================================================
# Install MetalLB and expose nginx via LoadBalancer (then make public)
# ============================================================================
if should_run 12; then
    print_step "12" "Install MetalLB (LoadBalancer for Kind)"

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
                echo "Error: MetalLB manifest unavailable (network failure and no local backup)."
                exit 1
            fi
        fi
    else
        echo "curl is not available; attempting to use local manifest if present"
        if [ -f "$LOCAL_METALLB_MANIFEST" ]; then
            kubectl apply -f "$LOCAL_METALLB_MANIFEST"
        else
            echo "Error: curl not found and no local MetalLB manifest available. Install curl or add $LOCAL_METALLB_MANIFEST"
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
            echo "✓ MetalLB pods are running"
            break
        fi
        echo "Waiting for MetalLB pods ($ready/$total)"
        sleep 2
        count=$((count+1))
    done

    if [ $count -eq $max ]; then
        echo "${YELLOW}Warning: MetalLB pods may not be ready yet${NC}"
    fi
fi

if should_run 13; then
    print_step "13" "Configure MetalLB IPAddressPool & L2Advertisement"

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

    kubectl apply -f "$METALLB_CFG"
    echo "Configured MetalLB IP pool"
fi

if should_run 14; then
    print_step "14" "Expose nginx as LoadBalancer and wait for external IP"

    echo "Patching nginx service to LoadBalancer..."
    kubectl -n demo patch svc nginx -p '{"spec":{"type":"LoadBalancer"}}' --kubeconfig "$KUBE_CONFIG" || true

    echo "Waiting for external IP assignment (MetalLB)..."
    LB_IP=""
    attempt=0
    max_attempts=60
    while [ $attempt -lt $max_attempts ]; do
        LB_IP=$(kubectl -n demo get svc nginx --kubeconfig "$KUBE_CONFIG" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [ -n "$LB_IP" ]; then
            echo "✓ External IP assigned: $LB_IP"
            break
        fi
        echo "Waiting for external IP... ($attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt+1))
    done

    if [ -z "$LB_IP" ]; then
        echo "${YELLOW}Warning: LoadBalancer IP not assigned. MetalLB may not have configured the pool correctly.${NC}"
    else
        echo "LoadBalancer IP: $LB_IP"
    fi
fi

if should_run 15; then
    print_step "15" "Test connectivity to NGinx"

    LB_IP=""
    attempt=0
    max_attempts=60
    while [ $attempt -lt $max_attempts ]; do
        LB_IP=$(kubectl -n demo get svc nginx --kubeconfig "$KUBE_CONFIG" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [ -n "$LB_IP" ]; then
            echo "✓ External IP assigned: $LB_IP"
            break
        fi
        echo "Waiting for external IP... ($attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt+1))
    done

    # Try curling the service a few times; hide output on success and only print the URL:port
    if [ -z "$LB_IP" ]; then
        echo "${YELLOW}Warning: no LoadBalancer IP available to test connectivity.${NC}"
    else
        CURL_RETRIES=5
        CURL_ATTEMPT=1
        SUCCESS=0
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
            echo "${YELLOW}Warning: nginx did not respond at http://$LB_IP:80 after $CURL_RETRIES attempts.${NC}"
        fi
    fi
fi