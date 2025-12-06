# =============================================================================
# K3d Cluster Management
# =============================================================================

.PHONY: cluster
cluster: tools-check ## Create k3d cluster (idempotent)
	@if [ ! -f "$(K3D_CONFIG)" ]; then \
		printf "\033[31m✗ Missing config: $(K3D_CONFIG)\033[0m\n"; \
		exit 1; \
	fi
	@if k3d cluster list 2>/dev/null | grep -q "$(CLUSTER_NAME)"; then \
		printf "\033[33m✓ Cluster '$(CLUSTER_NAME)' already exists — skipping\033[0m\n"; \
	else \
		printf "\033[36m→ Creating cluster '$(CLUSTER_NAME)' from $(K3D_CONFIG)\033[0m\n"; \
		k3d cluster create --config "$(K3D_CONFIG)"; \
		printf "\033[32m✓ Cluster created\033[0m\n"; \
	fi
	@kubectl config use-context "$(K3D_CONTEXT)" 2>/dev/null || true

.PHONY: cluster-delete
cluster-delete: ## Delete k3d cluster and kubectl context
	@printf "\033[33m→ Deleting cluster '$(CLUSTER_NAME)'\033[0m\n"
	@k3d cluster delete "$(CLUSTER_NAME)" 2>/dev/null || true
	@kubectl config delete-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-cluster "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-user "admin@$(K3D_CONTEXT)" 2>/dev/null || true
	@printf "\033[32m✓ Cluster deleted\033[0m\n"

.PHONY: cluster-stop
cluster-stop: ## Stop k3d cluster (keeps data)
	@printf "\033[36m→ Stopping cluster '$(CLUSTER_NAME)'\033[0m\n"
	@k3d cluster stop "$(CLUSTER_NAME)"
	@printf "\033[32m✓ Cluster stopped\033[0m\n"

.PHONY: cluster-start
cluster-start: ## Start stopped k3d cluster
	@printf "\033[36m→ Starting cluster '$(CLUSTER_NAME)'\033[0m\n"
	@k3d cluster start "$(CLUSTER_NAME)"
	@kubectl config use-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@printf "\033[32m✓ Cluster started\033[0m\n"

.PHONY: cluster-restart
cluster-restart: cluster-stop cluster-start ## Restart k3d cluster (keeps data)

.PHONY: cluster-reset
cluster-reset: cluster-delete cluster ## Recreate cluster from scratch
	@printf "\033[32m✓ Cluster reset complete\033[0m\n"
