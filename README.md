# Quick Setup Guide for Kind Cluster in Codespace

## Overview
This project sets up a Kubernetes cluster with NGinx on a MetalLB load balancer using Kind (Kubernetes in Docker) within a GitHub Codespace. It includes automated scripts to check dependencies, install required packages, and manage the cluster.

## Included Add-ons

- **MetalLB**: The setup deploys MetalLB (see `config/metallb-native.yaml` and `config/metallb-pool.yaml`) to provide external LoadBalancer IPs for services inside the Kind cluster.
- **NGinx**: An Nginx Deployment and Service are deployed and exposed on port 80; MetalLB will assign an external IP (example: `http://172.18.0.240:80`).

## Quick Start

### Single Command Setup (Recommended)
Deploy everything with one command:
```bash
sudo ./full-setup.sh
```

This orchestrates all steps:
- ✓ Sets up execution permissions
- ✓ Checks dependencies
- ✓ Installs missing packages
- ✓ Configures Docker permissions
- ✓ Creates the Kind cluster
- ✓ Verifies cluster health

**Optional:** Specify custom cluster name:
```bash
sudo ./full-setup.sh my-cluster
```

---

### Manual Step-by-Step Setup
If you prefer more control:

1. **Setup Permissions**
   ```bash
   sudo ./scripts/setup-permissions.sh
   ```

2. **Check Dependencies**
   ```bash
   ./scripts/check-dependencies.sh
   ```

3. **Install Missing Dependencies**
   ```bash
   sudo ./scripts/install-dependencies.sh
   ```

4. **Create Kind Cluster**
   ```bash
   ./scripts/create-cluster.sh
   ```

5. **Verify Cluster**
   ```bash
   ./scripts/view-logs.sh
   ```

## Project Structure

```
kind-cluster/
├── scripts/
│   ├── check-dependencies.sh      # Check if all dependencies are installed
│   ├── install-dependencies.sh    # Install missing dependencies
│   ├── setup-permissions.sh       # Set up execution permissions
│   ├── create-cluster.sh          # Create the Kind cluster
│   └── view-logs.sh               # View cluster status and logs
├── config/
│   └── kind-cluster-config.yaml   # Kind cluster configuration
├── full-setup.sh                   # Complete one-command setup (RECOMMENDED)
├── cleanup.sh                      # Remove cluster and Docker resources
├── README.md                       # This file
├── Makefile                        # Convenient make commands
└── .gitignore                      # Git ignore configuration
```

## Requirements

### Core Dependencies
- **Docker**: Container runtime
- **Kind**: Kubernetes in Docker
- **kubectl**: Kubernetes CLI
- **Git**: Version control (usually pre-installed)

### Optional Dependencies
- **Helm**: Kubernetes package manager
- **jq**: JSON processor for logs and configs

## Permissions

The scripts handle the following permissions automatically:

1. **Script Execution**: Makes all shell scripts executable
2. **Docker Access**: Adds user to docker group for non-root access
3. **Sudo Requirements**: Only `install-dependencies.sh` and `setup-permissions.sh` need sudo

### Manual Docker Access (if needed)
```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Common Commands

### Cluster Management
```bash
# View cluster status
./scripts/view-logs.sh

# Get cluster info
kubectl cluster-info --context kind-kind-cluster

# Get cluster nodes
kubectl get nodes

# Delete cluster
kind delete cluster --name kind-cluster

# Full cleanup (remove cluster and Docker resources)
sudo ./cleanup.sh
```

## Configuration

The cluster configuration is in `config/kind-cluster-config.yaml`:

- **Nodes**: 1 control plane + 2 workers (adjustable)
- **Pod CIDR**: 10.244.0.0/16
- **Service CIDR**: 10.96.0.0/12
- **Port Mappings**: HTTP (80), HTTPS (443), Kubernetes API (6443)

### Single-Node Cluster

To use a single-node cluster, edit `config/kind-cluster-config.yaml` and remove the worker nodes section.

## Repeatability & Clean Deployments

This project is fully repeatable from a clean environment:

### Full Redeploy Process
```bash
# 1. Clean up existing cluster
sudo ./cleanup.sh

# 2. Start fresh deployment (everything in one command)
sudo ./full-setup.sh
```

### Key Features for Repeatability
✓ **Single command deployment** - `./full-setup.sh` handles all setup steps  
✓ **Idempotent scripts** - Safe to run multiple times  
✓ **Automatic dependency checking** - Installs only what's missing  
✓ **Permission handling** - Automatically manages sudo and docker groups  
✓ **Health verification** - Waits for cluster to be fully ready  
✓ **Clean separation** - Individual scripts work independently  
✓ **Docker cleanup** - `cleanup.sh` removes all traces for fresh start  

### Continuous Integration Ready
The scripts work in CI/CD pipelines:
```bash
# CI/CD pipeline example
sudo ./cleanup.sh || true  # Optional cleanup
sudo ./full-setup.sh       # Fresh deployment
kubectl apply -f manifests/
```

## Resource Usage

Typical resource consumption for this setup:
- **Memory**: ~2-3 GB per worker node + 1 GB for control plane
- **Disk**: ~5-10 GB
- **CPU**: 2+ cores recommended

## Next Steps

1. Deploy applications to your cluster using kubectl
2. Configure ingress and networking for your services
3. Set up monitoring and logging (optional)
4. Create development pipelines and CI/CD workflows

## References

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitHub Codespaces](https://github.com/features/codespaces)

## License

This project is provided as-is for use in GitHub Codespaces.
