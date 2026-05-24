# =============================================================================
# Infrastructure Components
# =============================================================================

.PHONY: infra
infra: infra-traefik infra-otel ## Install Traefik + OTel Collector
	@printf "\033[32m✓ All infrastructure components installed\033[0m\n"

.PHONY: infra-traefik
infra-traefik: cluster ## Install Traefik Ingress Controller
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

.PHONY: infra-otel
infra-otel: cluster ## Install OpenTelemetry Collector
	@if helm status otel-collector -n $(OBS_NS) >/dev/null 2>&1; then \
		printf "\033[33m⊘ OpenTelemetry Collector already installed, skipping\033[0m\n"; \
	else \
		printf "\033[36m→ Installing OpenTelemetry Collector\033[0m\n"; \
		helm upgrade --install otel-collector opentelemetry-collector \
			--repo https://open-telemetry.github.io/opentelemetry-helm-charts \
			--version 0.133.0 \
			--namespace $(OBS_NS) \
			--create-namespace \
			--values $(OTELCOL_VALUES) \
			--wait; \
		printf "\033[32m✓ OpenTelemetry Collector installed\033[0m\n"; \
	fi

.PHONY: infra-traefik-uninstall
infra-traefik-uninstall: ## Uninstall Traefik
	@printf "\033[33m→ Uninstalling Traefik\033[0m\n"
	@helm uninstall traefik -n $(TRAEFIK_NS) 2>/dev/null || true
	@helm uninstall traefik-crds -n $(TRAEFIK_NS) 2>/dev/null || true
	@printf "\033[32m✓ Traefik uninstalled\033[0m\n"

.PHONY: infra-otel-uninstall
infra-otel-uninstall: ## Uninstall OTel Collector
	@printf "\033[33m→ Uninstalling OpenTelemetry Collector\033[0m\n"
	@helm uninstall otel-collector -n $(OBS_NS) 2>/dev/null || true
	@printf "\033[32m✓ OpenTelemetry Collector uninstalled\033[0m\n"

.PHONY: infra-uninstall
infra-uninstall: infra-traefik-uninstall infra-otel-uninstall ## Uninstall all infra components
	@printf "\033[32m✓ All infrastructure components uninstalled\033[0m\n"
