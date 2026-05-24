# =============================================================================
##@ Cluster Setup
# =============================================================================

.PHONY: setup-namespaces
setup-namespaces: ## Create Kubernetes namespaces
	@printf "$(COLOR_BLUE)→ Creating namespaces...$(COLOR_RESET)\n"
	kubectl apply -f $(K8S_DIR)/namespaces.yaml
	@printf "$(COLOR_GREEN)✓ Namespaces created$(COLOR_RESET)\n"

.PHONY: setup-repos
setup-repos: ## Add Helm repositories
	@printf "$(COLOR_BLUE)→ Adding Helm repositories...$(COLOR_RESET)\n"
	helm repo add redpanda $(REDPANDA_REPO) 2>/dev/null || true
	helm repo add grafana $(GRAFANA_REPO) 2>/dev/null || true
	helm repo update
	@printf "$(COLOR_GREEN)✓ Helm repositories configured$(COLOR_RESET)\n"

.PHONY: setup-traefik
setup-traefik: ## Configure Traefik (k3s built-in) with ACME/Let's Encrypt
	@printf "$(COLOR_BLUE)→ Configuring Traefik...$(COLOR_RESET)\n"
	kubectl apply -f $(K8S_DIR)/traefik-config.yaml
	@printf "$(COLOR_GREEN)✓ Traefik configured (restart may take a moment)$(COLOR_RESET)\n"

# =============================================================================
##@ Secrets
# =============================================================================

.PHONY: setup-secrets
setup-secrets: ## Decrypt and apply Kubernetes secrets via SOPS
	@if [ ! -f $(K8S_DIR)/secrets.enc.yaml ]; then \
		printf "$(COLOR_RED)Error: $(K8S_DIR)/secrets.enc.yaml not found$(COLOR_RESET)\n"; \
		exit 1; \
	fi
	@printf "$(COLOR_BLUE)→ Decrypting and applying secrets...$(COLOR_RESET)\n"
	sops decrypt $(K8S_DIR)/secrets.enc.yaml | kubectl apply -f -
	@printf "$(COLOR_GREEN)✓ Secrets applied$(COLOR_RESET)\n"

VSCODE_CODE := $(or $(shell which code 2>/dev/null),$(wildcard $(HOME)/.vscode-server/bin/*/bin/remote-cli/code))

.PHONY: secrets-edit
secrets-edit: ## Edit encrypted secrets (opens in VS Code)
	@if [ -z "$(VSCODE_CODE)" ]; then printf "$(COLOR_RED)Error: 'code' command not found$(COLOR_RESET)\n"; exit 1; fi
	EDITOR="$(VSCODE_CODE) --wait" sops $(K8S_DIR)/secrets.enc.yaml

.PHONY: secrets-view
secrets-view: ## View decrypted secrets (stdout only, not saved)
	sops decrypt $(K8S_DIR)/secrets.enc.yaml
