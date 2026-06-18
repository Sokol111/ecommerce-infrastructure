# =============================================================================
# Infrastructure Components
# =============================================================================

.PHONY: traefik-install
traefik-install: ## Install Traefik Ingress Controller
	@if helm status traefik -n $(TRAEFIK_NS) >/dev/null 2>&1; then \
		printf "\033[33m⊘ Traefik already installed, skipping\033[0m\n"; \
	else \
		printf "\033[36m→ Installing Traefik CRDs\033[0m\n"; \
		helm upgrade --install traefik-crds traefik-crds \
			--repo https://traefik.github.io/charts \
			--version 1.11.0 \
			--namespace $(TRAEFIK_NS) \
			--create-namespace \
			--wait 2>/dev/null || printf "\033[33m  CRDs already installed\033[0m\n"; \
		printf "\033[36m→ Installing Traefik\033[0m\n"; \
		helm upgrade --install traefik traefik \
			--repo https://traefik.github.io/charts \
			--version 37.1.0 \
			--namespace $(TRAEFIK_NS) \
			--values $(TRAEFIK_VALUES) \
			--wait; \
		printf "\033[32m✓ Traefik installed\033[0m\n"; \
	fi

.PHONY: alloy-install
alloy-install: ## Install Grafana Alloy
	@if helm status alloy -n $(OBS_NS) >/dev/null 2>&1; then \
		printf "\033[33m⊘ Grafana Alloy already installed, skipping\033[0m\n"; \
	else \
		printf "\033[36m→ Installing Grafana Alloy\033[0m\n"; \
		helm upgrade --install alloy alloy \
			--repo https://grafana.github.io/helm-charts \
			--version 1.10.0 \
			--namespace $(OBS_NS) \
			--create-namespace \
			--values $(ALLOY_VALUES) \
			--wait \
			--timeout 5m; \
		printf "\033[32m✓ Grafana Alloy installed\033[0m\n"; \
	fi

.PHONY: traefik-uninstall
traefik-uninstall: ## Uninstall Traefik
	@printf "\033[33m→ Uninstalling Traefik\033[0m\n"
	@helm uninstall traefik -n $(TRAEFIK_NS) 2>/dev/null || true
	@helm uninstall traefik-crds -n $(TRAEFIK_NS) 2>/dev/null || true
	@printf "\033[32m✓ Traefik uninstalled\033[0m\n"

.PHONY: alloy-uninstall
alloy-uninstall: ## Uninstall Grafana Alloy
	@printf "\033[33m→ Uninstalling Grafana Alloy\033[0m\n"
	@helm uninstall alloy -n $(OBS_NS) 2>/dev/null || true
	@printf "\033[32m✓ Grafana Alloy uninstalled\033[0m\n"
