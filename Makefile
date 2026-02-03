#!/bin/bash

# Makefile-style commands for Kind cluster management
# Usage: make <target> or source ./Makefile and use functions

.PHONY: help check-deps install-deps setup-perms create-cluster view-logs delete-cluster clean

help:
	@echo "Kind Cluster - Available Commands"
	@echo "==================================="
	@echo "make check-deps       - Check dependencies"
	@echo "make install-deps     - Install missing dependencies (requires sudo)"
	@echo "make setup-perms      - Set up execution permissions (requires sudo)"
	@echo "make create-cluster   - Create Kind cluster"
	@echo "make view-logs        - View cluster status"
	@echo "make delete-cluster   - Delete Kind cluster"
	@echo "make clean            - Clean up all resources"
	@echo "make help             - Show this help message"

check-deps:
	./scripts/check-dependencies.sh

install-deps:
	sudo ./scripts/install-dependencies.sh

setup-perms:
	sudo ./scripts/setup-permissions.sh

create-cluster:
	./scripts/create-cluster.sh

view-logs:
	./scripts/view-logs.sh

delete-cluster:
	kind delete cluster --name kind-cluster

cluster-info:
	kubectl cluster-info --context kind-kind-cluster

get-nodes:
	kubectl get nodes -o wide

get-pods:
	kubectl get pods -A

logs-control-plane:
	docker logs kind-cluster-control-plane

clean: delete-cluster
	@echo "Cluster deleted. To remove all Docker images: docker system prune"

.DEFAULT_GOAL := help
