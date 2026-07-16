# =============================================================================
# E-Commerce Production Deployment (k3s)
# =============================================================================
# Usage: make [target]
# Run `make help` to see all available targets

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

# Colors
COLOR_RESET  := \033[0m
COLOR_BOLD   := \033[1m
COLOR_GREEN  := \033[32m
COLOR_YELLOW := \033[33m
COLOR_BLUE   := \033[36m
COLOR_RED    := \033[31m

# Paths
HELM_DIR     := ../../helm
VALUES_DIR   := values
K8S_DIR      := k8s
SEEDER_DIR   := ../../cmd/seeder

# Namespaces
NS_PROD := prod
NS_OBS  := observability

# SSH tunnel
SSH_HOST := hetzner
K8S_PORT := 6443

# Kubeconfig (uses SSH tunnel to reach k3s API)
KUBECONFIG_FILE := $(HOME)/.kube/config-hetzner
MCP_KUBECONFIG_FILE := $(HOME)/.kube/mcp-prod-viewer.kubeconfig
MCP_NAMESPACE := mcp
MCP_SERVICE_ACCOUNT := opencode-viewer
export KUBECONFIG := $(KUBECONFIG_FILE)

# Helm repos
REDPANDA_REPO := https://charts.redpanda.com
GRAFANA_REPO  := https://grafana.github.io/helm-charts

.DEFAULT_GOAL := help

# =============================================================================
# Help
# =============================================================================

.PHONY: help
help: ## Show this help message
	@printf "$(COLOR_BOLD)E-Commerce Production Deployment (k3s)$(COLOR_RESET)\n\n"
	@printf "$(COLOR_YELLOW)Usage:$(COLOR_RESET) make [target]\n\n"
	@printf "$(COLOR_YELLOW)Targets:$(COLOR_RESET)\n"
	@awk 'BEGIN {FS = ":.*##"; } \
		/^[a-zA-Z_-]+:.*?##/ { printf "  $(COLOR_GREEN)%-25s$(COLOR_RESET) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(COLOR_BOLD)%s$(COLOR_RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# =============================================================================
# Includes
# =============================================================================

include makefiles/connectivity.mk
include makefiles/setup.mk
include makefiles/deploy.mk
include makefiles/status.mk
include makefiles/operations.mk
