#!/bin/bash

# Kubernetes Service Port Forwarding
# Standard pattern for accessing services during development/debugging
# This mimics how you'd access a service in a real cluster environment

set -e

NAMESPACE="${1:-demo}"
SERVICE="${2:-nginx}"
LOCAL_PORT="${3:-8080}"
SERVICE_PORT="${4:-80}"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Kubernetes Service Port Forwarding                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Configuration:"
echo "  Namespace:      $NAMESPACE"
echo "  Service:        $SERVICE"
echo "  Local Port:     $LOCAL_PORT"
echo "  Service Port:   $SERVICE_PORT"
echo "  Kubeconfig:     $KUBECONFIG"
echo ""

# Verify kubeconfig exists
if [ ! -f "$KUBECONFIG" ]; then
    echo "Error: Kubeconfig not found at $KUBECONFIG"
    exit 1
fi

# Verify service exists
echo "Verifying service exists..."
if ! kubectl get svc "$SERVICE" -n "$NAMESPACE" --kubeconfig "$KUBECONFIG" > /dev/null 2>&1; then
    echo "Error: Service '$SERVICE' not found in namespace '$NAMESPACE'"
    echo ""
    echo "Available services in $NAMESPACE:"
    kubectl get svc -n "$NAMESPACE" --kubeconfig "$KUBECONFIG" || true
    exit 1
fi

echo "✓ Service found"
echo ""

# Show service details
echo "Service Details:"
kubectl get svc "$SERVICE" -n "$NAMESPACE" --kubeconfig "$KUBECONFIG" -o wide
echo ""

# Start port-forward
echo "Starting port-forward..."
echo "  kubectl port-forward -n $NAMESPACE svc/$SERVICE $LOCAL_PORT:$SERVICE_PORT"
echo ""
echo "Service will be accessible at:"
echo "  http://localhost:$LOCAL_PORT"
echo ""
echo "To stop: Ctrl+C"
echo "────────────────────────────────────────────────────────────────"
echo ""

# Run port-forward in foreground
kubectl port-forward -n "$NAMESPACE" svc/"$SERVICE" "$LOCAL_PORT":"$SERVICE_PORT" --kubeconfig "$KUBECONFIG"
