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
INFRA_VALUES := $(HELM_DIR)/values/infrastructure
K8S_DIR      := k8s

# Namespaces
NS_PROD := prod
NS_OBS  := observability

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
##@ Initial Setup
# =============================================================================

.PHONY: setup
setup: setup-namespaces setup-repos setup-traefik ## Full initial setup (namespaces, repos, traefik)

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

.PHONY: setup-secrets
setup-secrets: ## Apply Kubernetes secrets (must create secrets.yaml first!)
	@if [ ! -f $(K8S_DIR)/secrets.yaml ]; then \
		printf "$(COLOR_RED)Error: $(K8S_DIR)/secrets.yaml not found$(COLOR_RESET)\n"; \
		printf "Copy secrets.yaml.example to secrets.yaml and fill in values:\n"; \
		printf "  cp $(K8S_DIR)/secrets.yaml.example $(K8S_DIR)/secrets.yaml\n"; \
		exit 1; \
	fi
	@printf "$(COLOR_BLUE)→ Applying secrets...$(COLOR_RESET)\n"
	kubectl apply -f $(K8S_DIR)/secrets.yaml
	@printf "$(COLOR_GREEN)✓ Secrets applied$(COLOR_RESET)\n"

# =============================================================================
##@ Deploy Infrastructure
# =============================================================================

.PHONY: deploy-redpanda
deploy-redpanda: ## Deploy Redpanda (Kafka-compatible broker)
	@printf "$(COLOR_BLUE)→ Deploying Redpanda...$(COLOR_RESET)\n"
	helm upgrade --install redpanda redpanda/redpanda \
		-n $(NS_PROD) \
		-f $(INFRA_VALUES)/redpanda-prod.yaml \
		--wait --timeout 5m
	@printf "$(COLOR_GREEN)✓ Redpanda deployed$(COLOR_RESET)\n"

.PHONY: deploy-imgproxy
deploy-imgproxy: ## Deploy imgproxy (image processing)
	@printf "$(COLOR_BLUE)→ Deploying imgproxy...$(COLOR_RESET)\n"
	kubectl apply -f $(K8S_DIR)/imgproxy.yaml
	@printf "$(COLOR_GREEN)✓ imgproxy deployed$(COLOR_RESET)\n"

.PHONY: deploy-infra
deploy-infra: deploy-redpanda deploy-imgproxy ## Deploy all infrastructure (Redpanda + imgproxy)

# =============================================================================
##@ Deploy Observability
# =============================================================================

.PHONY: deploy-alloy
deploy-alloy: ## Deploy Grafana Alloy (→ Grafana Cloud)
	@printf "$(COLOR_BLUE)→ Deploying Grafana Alloy...$(COLOR_RESET)\n"
	helm upgrade --install alloy grafana/alloy \
		-n $(NS_OBS) \
		-f $(INFRA_VALUES)/alloy-prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ Grafana Alloy deployed$(COLOR_RESET)\n"

.PHONY: deploy-observability
deploy-observability: deploy-alloy ## Deploy observability stack

# =============================================================================
##@ Deploy Application Services
# =============================================================================

.PHONY: deploy-auth
deploy-auth: ## Deploy auth-service
	@printf "$(COLOR_BLUE)→ Deploying auth-service...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-auth-service && helm dependency update
	helm upgrade --install auth-service $(HELM_DIR)/ecommerce-auth-service \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-auth-service/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ auth-service deployed$(COLOR_RESET)\n"

.PHONY: deploy-catalog
deploy-catalog: ## Deploy catalog-service
	@printf "$(COLOR_BLUE)→ Deploying catalog-service...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-catalog-service && helm dependency update
	helm upgrade --install catalog-service $(HELM_DIR)/ecommerce-catalog-service \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-catalog-service/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ catalog-service deployed$(COLOR_RESET)\n"

.PHONY: deploy-category-query
deploy-category-query: ## Deploy category-query-service
	@printf "$(COLOR_BLUE)→ Deploying category-query-service...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-category-query-service && helm dependency update
	helm upgrade --install category-query-service $(HELM_DIR)/ecommerce-category-query-service \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-category-query-service/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ category-query-service deployed$(COLOR_RESET)\n"

.PHONY: deploy-product-query
deploy-product-query: ## Deploy product-query-service
	@printf "$(COLOR_BLUE)→ Deploying product-query-service...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-product-query-service && helm dependency update
	helm upgrade --install product-query-service $(HELM_DIR)/ecommerce-product-query-service \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-product-query-service/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ product-query-service deployed$(COLOR_RESET)\n"

.PHONY: deploy-image-service
deploy-image-service: ## Deploy image-service
	@printf "$(COLOR_BLUE)→ Deploying image-service...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-image-service && helm dependency update
	helm upgrade --install image-service $(HELM_DIR)/ecommerce-image-service \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-image-service/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ image-service deployed$(COLOR_RESET)\n"

.PHONY: deploy-admin-ui
deploy-admin-ui: ## Deploy admin-ui
	@printf "$(COLOR_BLUE)→ Deploying admin-ui...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-admin-ui && helm dependency update
	helm upgrade --install admin-ui $(HELM_DIR)/ecommerce-admin-ui \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-admin-ui/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ admin-ui deployed$(COLOR_RESET)\n"

.PHONY: deploy-ecommerce-ui
deploy-ecommerce-ui: ## Deploy ecommerce-ui
	@printf "$(COLOR_BLUE)→ Deploying ecommerce-ui...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-ui && helm dependency update
	helm upgrade --install ecommerce-ui $(HELM_DIR)/ecommerce-ui \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-ui/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ ecommerce-ui deployed$(COLOR_RESET)\n"

.PHONY: deploy-backend
deploy-backend: deploy-auth deploy-catalog deploy-image-service deploy-product-query deploy-category-query ## Deploy all backend services

.PHONY: deploy-frontend
deploy-frontend: deploy-admin-ui deploy-ecommerce-ui ## Deploy all frontend UIs

.PHONY: deploy-services
deploy-services: deploy-backend deploy-frontend ## Deploy all application services

# =============================================================================
##@ Full Deployment
# =============================================================================

.PHONY: deploy
deploy: deploy-infra deploy-observability deploy-services ## Deploy everything

.PHONY: deploy-all
deploy-all: setup setup-secrets deploy ## Full setup + deploy (first time only)

# =============================================================================
##@ Monitoring & Status
# =============================================================================

.PHONY: status
status: ## Show status of all pods
	@printf "$(COLOR_BOLD)Namespace: $(NS_PROD)$(COLOR_RESET)\n"
	@kubectl get pods -n $(NS_PROD) -o wide
	@printf "\n$(COLOR_BOLD)Namespace: $(NS_OBS)$(COLOR_RESET)\n"
	@kubectl get pods -n $(NS_OBS) -o wide

.PHONY: health
health: ## Check health of all services
	@printf "$(COLOR_BOLD)Pod Health:$(COLOR_RESET)\n"
	@kubectl get pods -n $(NS_PROD) -o custom-columns=\
	"NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"
	@printf "\n"
	@kubectl get pods -n $(NS_OBS) -o custom-columns=\
	"NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"

.PHONY: logs
logs: ## Follow logs for a service (usage: make logs SVC=auth-service)
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make logs SVC=<service-name>\n"
	@exit 1
endif
	kubectl logs -f -n $(NS_PROD) -l app.kubernetes.io/name=$(SVC)

.PHONY: ingresses
ingresses: ## Show all ingress routes
	@printf "$(COLOR_BOLD)Ingress Routes:$(COLOR_RESET)\n"
	@kubectl get ingress -n $(NS_PROD)

# =============================================================================
##@ Upgrades
# =============================================================================

.PHONY: upgrade-service
upgrade-service: ## Upgrade a single service (usage: make upgrade-service SVC=auth-service)
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make upgrade-service SVC=<chart-name>\n"
	@exit 1
endif
	@printf "$(COLOR_BLUE)→ Upgrading $(SVC)...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-$(SVC) && helm dependency update
	helm upgrade $(SVC) $(HELM_DIR)/ecommerce-$(SVC) \
		-n $(NS_PROD) \
		-f $(HELM_DIR)/ecommerce-$(SVC)/values.prod.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ $(SVC) upgraded$(COLOR_RESET)\n"

# =============================================================================
##@ Cleanup
# =============================================================================

.PHONY: delete-services
delete-services: ## Delete all application services (keeps infra)
	@printf "$(COLOR_YELLOW)→ Deleting application services...$(COLOR_RESET)\n"
	-helm uninstall auth-service -n $(NS_PROD)
	-helm uninstall catalog-service -n $(NS_PROD)
	-helm uninstall image-service -n $(NS_PROD)
	-helm uninstall product-query-service -n $(NS_PROD)
	-helm uninstall category-query-service -n $(NS_PROD)
	-helm uninstall admin-ui -n $(NS_PROD)
	-helm uninstall ecommerce-ui -n $(NS_PROD)
	@printf "$(COLOR_GREEN)✓ Application services deleted$(COLOR_RESET)\n"

.PHONY: delete-all
delete-all: ## Delete everything (⚠️ destructive!)
	@printf "$(COLOR_RED)⚠️  WARNING: This will delete all deployments!$(COLOR_RESET)\n"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	-helm uninstall auth-service catalog-service image-service product-query-service category-query-service admin-ui ecommerce-ui -n $(NS_PROD)
	-helm uninstall redpanda -n $(NS_PROD)
	-helm uninstall alloy -n $(NS_OBS)
	-kubectl delete -f $(K8S_DIR)/imgproxy.yaml
	@printf "$(COLOR_GREEN)✓ Everything deleted$(COLOR_RESET)\n"
