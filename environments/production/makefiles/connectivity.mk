# =============================================================================
##@ Connectivity
# =============================================================================

.PHONY: tunnel
tunnel: ## Open or repair the SSH tunnel for kubectl access
	@if kubectl --kubeconfig="$(KUBECONFIG_FILE)" get --raw=/healthz --request-timeout=3s >/dev/null 2>&1; then \
		printf "$(COLOR_YELLOW)⚡ Tunnel already healthy on port $(K8S_PORT)$(COLOR_RESET)\n"; \
	else \
		if ss -tln | grep -q ':$(K8S_PORT)\b'; then \
			printf "$(COLOR_YELLOW)⚡ Replacing unhealthy tunnel on port $(K8S_PORT)$(COLOR_RESET)\n"; \
			for pid in $$(pgrep -f "ssh .* -L $(K8S_PORT):127.0.0.1:$(K8S_PORT).*$(SSH_HOST)" || true); do \
				[ "$$pid" = "$$$$" ] || kill "$$pid" 2>/dev/null || true; \
			done; \
		fi; \
		printf "$(COLOR_BLUE)→ Opening SSH tunnel to $(SSH_HOST):$(K8S_PORT)...$(COLOR_RESET)\n"; \
		ssh \
			-o ExitOnForwardFailure=yes \
			-o ServerAliveInterval=30 \
			-o ServerAliveCountMax=3 \
			-L $(K8S_PORT):127.0.0.1:$(K8S_PORT) $(SSH_HOST) -N -f; \
		kubectl --kubeconfig="$(KUBECONFIG_FILE)" get --raw=/healthz --request-timeout=10s >/dev/null; \
		printf "$(COLOR_GREEN)✓ Tunnel established and healthy$(COLOR_RESET)\n"; \
	fi

.PHONY: tunnel-stop
tunnel-stop: ## Close SSH tunnel
	@printf "$(COLOR_BLUE)→ Closing SSH tunnel...$(COLOR_RESET)\n"
	@stopped=0; \
	for pid in $$(pgrep -f "ssh .* -L $(K8S_PORT):127.0.0.1:$(K8S_PORT).*$(SSH_HOST)" || true); do \
		[ "$$pid" = "$$$$" ] || { kill "$$pid" 2>/dev/null && stopped=1 || true; }; \
	done; \
	if [ "$$stopped" -eq 1 ]; then \
		printf "$(COLOR_GREEN)✓ Tunnel closed$(COLOR_RESET)\n"; \
	else \
		printf "$(COLOR_YELLOW)⚡ No active tunnel found$(COLOR_RESET)\n"; \
	fi

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

.PHONY: mcp-kubeconfig
mcp-kubeconfig: kubeconfig ## Create the read-only production Kubernetes MCP kubeconfig (requires tunnel)
	@printf "$(COLOR_BLUE)→ Creating production Kubernetes MCP identity...$(COLOR_RESET)\n"
	kubectl create namespace $(MCP_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(MCP_NAMESPACE) create serviceaccount $(MCP_SERVICE_ACCOUNT) --dry-run=client -o yaml | kubectl apply -f -
	kubectl create clusterrolebinding $(MCP_SERVICE_ACCOUNT) \
		--clusterrole=view \
		--serviceaccount=$(MCP_NAMESPACE):$(MCP_SERVICE_ACCOUNT) \
		--dry-run=client -o yaml | kubectl apply -f -
	@mkdir -p "$(dir $(MCP_KUBECONFIG_FILE))"
	@rm -f "$(MCP_KUBECONFIG_FILE)"
	@cluster_name="$$(kubectl config view --raw --minify -o jsonpath='{.contexts[0].context.cluster}')"; \
	ca_file="$$(mktemp)"; \
	trap 'rm -f "$$ca_file"' EXIT; \
	kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > "$$ca_file"; \
	token="$$(kubectl -n $(MCP_NAMESPACE) create token $(MCP_SERVICE_ACCOUNT) --duration=720h)"; \
	kubectl config --kubeconfig="$(MCP_KUBECONFIG_FILE)" set-cluster "$$cluster_name" \
		--server="https://127.0.0.1:$(K8S_PORT)" \
		--certificate-authority="$$ca_file" \
		--embed-certs=true; \
	kubectl config --kubeconfig="$(MCP_KUBECONFIG_FILE)" set-credentials $(MCP_SERVICE_ACCOUNT) --token="$$token"; \
	kubectl config --kubeconfig="$(MCP_KUBECONFIG_FILE)" set-context $(MCP_SERVICE_ACCOUNT) \
		--cluster="$$cluster_name" --user=$(MCP_SERVICE_ACCOUNT); \
	kubectl config --kubeconfig="$(MCP_KUBECONFIG_FILE)" use-context $(MCP_SERVICE_ACCOUNT); \
	chmod 600 "$(MCP_KUBECONFIG_FILE)"
	@printf "$(COLOR_GREEN)✓ Production MCP kubeconfig written to $(MCP_KUBECONFIG_FILE)$(COLOR_RESET)\n"

.PHONY: ssh
ssh: ## SSH into the VPS
	ssh $(SSH_HOST)
