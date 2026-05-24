# =============================================================================
##@ Connectivity
# =============================================================================

.PHONY: tunnel
tunnel: ## Open SSH tunnel for kubectl access
	@if ss -tln | grep -q ':$(K8S_PORT)\b'; then \
		printf "$(COLOR_YELLOW)⚡ Tunnel already active on port $(K8S_PORT)$(COLOR_RESET)\n"; \
	else \
		printf "$(COLOR_BLUE)→ Opening SSH tunnel to $(SSH_HOST):$(K8S_PORT)...$(COLOR_RESET)\n"; \
		ssh -L $(K8S_PORT):127.0.0.1:$(K8S_PORT) $(SSH_HOST) -N -f; \
		printf "$(COLOR_GREEN)✓ Tunnel established$(COLOR_RESET)\n"; \
	fi

.PHONY: tunnel-stop
tunnel-stop: ## Close SSH tunnel
	@printf "$(COLOR_BLUE)→ Closing SSH tunnel...$(COLOR_RESET)\n"
	@pkill -f "ssh -L $(K8S_PORT)" 2>/dev/null && \
		printf "$(COLOR_GREEN)✓ Tunnel closed$(COLOR_RESET)\n" || \
		printf "$(COLOR_YELLOW)⚡ No active tunnel found$(COLOR_RESET)\n"

.PHONY: kubeconfig
kubeconfig: ## Fetch kubeconfig from VPS (creates ~/.kube/config-hetzner)
	@if [ -f $(KUBECONFIG_FILE) ]; then \
		printf "$(COLOR_YELLOW)⚡ $(KUBECONFIG_FILE) already exists$(COLOR_RESET)\n"; \
	else \
		printf "$(COLOR_BLUE)→ Fetching kubeconfig from $(SSH_HOST)...$(COLOR_RESET)\n"; \
		mkdir -p $(HOME)/.kube; \
		ssh $(SSH_HOST) "cat /etc/rancher/k3s/k3s.yaml" > $(KUBECONFIG_FILE); \
		printf "$(COLOR_GREEN)✓ Kubeconfig saved to $(KUBECONFIG_FILE)$(COLOR_RESET)\n"; \
	fi

.PHONY: ssh
ssh: ## SSH into the VPS
	ssh $(SSH_HOST)
