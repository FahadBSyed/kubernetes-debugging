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
    "$SCRIPT_DIR/scripts/deploy-nginx.sh"
    echo ""
fi

# ============================================================================
# Install MetalLB and expose nginx via LoadBalancer (then make public)
# ============================================================================
if should_run 12; then
    print_step "12" "Install MetalLB (LoadBalancer for Kind)"
    "$SCRIPT_DIR/scripts/install-metallb.sh"
    echo ""
fi

if should_run 13; then
    # Step 13 is now combined with Step 12 in install-metallb.sh
    true
fi

if should_run 14; then
    print_step "14" "Expose nginx as LoadBalancer and wait for external IP"
    "$SCRIPT_DIR/scripts/expose-loadbalancer.sh"
    echo ""
fi

if should_run 15; then
    print_step "15" "Test connectivity to NGinx"
    "$SCRIPT_DIR/scripts/test-connectivity.sh"
    echo ""
fi