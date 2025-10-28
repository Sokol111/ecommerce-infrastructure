# ---- Config ----
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# K3d
K3D_CONFIG ?= $(THIS_DIR)k3d-cluster.yaml
CLUSTER_NAME ?= dev-cluster
K3D_CONTEXT := k3d-$(CLUSTER_NAME)

# Skaffold
SKAFFOLD_CONFIG ?= $(THIS_DIR)skaffold.yaml
SKAFFOLD_PROFILE ?=

# Namespaces
NAMESPACE ?= dev
OBS_NS ?= observability
TRAEFIK_NS ?= traefik
MINIO_NS ?= minio

# Umbrella chart
CHART_PATH ?= $(THIS_DIR)helm/ecommerce-go-service

# Docker compose
COMPOSE_DIR := $(THIS_DIR)docker/docker-compose
MONGO_COMPOSE := $(COMPOSE_DIR)/mongo.yml
KAFKA_COMPOSE := $(COMPOSE_DIR)/kafka.yml
DOCKER_NETWORK := shared-network

# Observability services
GRAFANA_SVC ?= grafana
GRAFANA_LOCAL_PORT ?= 3000
GRAFANA_SVC_PORT ?= 80

.DEFAULT_GOAL := help

# ---- Utils ----
.PHONY: help
help: ## List available targets
	@echo ""
	@echo -e "\033[36mAvailable targets:\033[0m"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS=":.*?## "}; {printf "  \033[32m%-30s\033[0m %s\n", $$1, $$2}'
	@echo ""

.PHONY: tools-check
tools-check: ## Verify required CLIs are installed
	@echo -e "\033[36m→ Checking required tools...\033[0m"
	@missing=0; \
	for tool in k3d kubectl skaffold helm stern docker docker-compose; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo -e "  \033[31m✗ $$tool\033[0m not found in PATH"; \
			missing=1; \
		else \
			echo -e "  \033[32m✓ $$tool\033[0m"; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo -e "\033[31m✗ Some tools are missing\033[0m"; \
		exit 1; \
	fi
	@echo -e "\033[32m✓ All required tools are installed\033[0m"

.PHONY: check-env
check-env: ## Run comprehensive environment check
	@bash $(THIS_DIR)scripts/check-env.sh

.PHONY: status
status: ## Show cluster and deployment status
	@echo -e "\033[36m→ K3d Cluster Status:\033[0m"
	@if k3d cluster list 2>/dev/null | grep -q "$(CLUSTER_NAME)"; then \
		k3d cluster list | grep "$(CLUSTER_NAME)" || true; \
		echo ""; \
		echo -e "\033[36m→ Kubernetes Context:\033[0m"; \
		kubectl config current-context 2>/dev/null || echo "  No context set"; \
		echo ""; \
		echo -e "\033[36m→ Nodes:\033[0m"; \
		kubectl get nodes -o wide 2>/dev/null || echo "  Cluster not accessible"; \
		echo ""; \
		echo -e "\033[36m→ Deployments in '$(NAMESPACE)':\033[0m"; \
		kubectl get deployments -n "$(NAMESPACE)" 2>/dev/null || echo "  Namespace not found"; \
		echo ""; \
		echo -e "\033[36m→ Services in '$(NAMESPACE)':\033[0m"; \
		kubectl get services -n "$(NAMESPACE)" 2>/dev/null || echo "  Namespace not found"; \
	else \
		echo "  \033[33mCluster '$(CLUSTER_NAME)' not found\033[0m"; \
	fi

# ---- K3d Cluster Management ----
.PHONY: cluster-create
cluster-create: tools-check ## Create k3d cluster from config
	@if [ ! -f "$(K3D_CONFIG)" ]; then \
		echo -e "\033[31m✗ Missing config: $(K3D_CONFIG)\033[0m"; \
		exit 1; \
	fi
	@if k3d cluster list 2>/dev/null | grep -q "$(CLUSTER_NAME)"; then \
		echo -e "\033[33m✓ Cluster '$(CLUSTER_NAME)' already exists — skipping\033[0m"; \
	else \
		echo -e "\033[36m→ Creating cluster '$(CLUSTER_NAME)' from $(K3D_CONFIG)\033[0m"; \
		k3d cluster create --config "$(K3D_CONFIG)"; \
		echo -e "\033[32m✓ Cluster created\033[0m"; \
	fi
	@kubectl config use-context "$(K3D_CONTEXT)" 2>/dev/null || true

.PHONY: cluster-delete
cluster-delete: ## Delete k3d cluster completely
	@echo -e "\033[33m→ Deleting cluster '$(CLUSTER_NAME)'\033[0m"
	@k3d cluster delete "$(CLUSTER_NAME)" 2>/dev/null || true
	@kubectl config delete-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-cluster "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-user "admin@$(K3D_CONTEXT)" 2>/dev/null || true
	@echo -e "\033[32m✓ Cluster deleted\033[0m"

.PHONY: cluster-restart
cluster-restart: cluster-stop cluster-start ## Restart k3d cluster

.PHONY: cluster-stop
cluster-stop: ## Stop k3d cluster
	@echo -e "\033[36m→ Stopping cluster '$(CLUSTER_NAME)'\033[0m"
	@k3d cluster stop "$(CLUSTER_NAME)"
	@echo -e "\033[32m✓ Cluster stopped\033[0m"

.PHONY: cluster-start
cluster-start: ## Start k3d cluster
	@echo -e "\033[36m→ Starting cluster '$(CLUSTER_NAME)'\033[0m"
	@k3d cluster start "$(CLUSTER_NAME)"
	@kubectl config use-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@echo -e "\033[32m✓ Cluster started\033[0m"

.PHONY: cluster-reset
cluster-reset: cluster-delete cluster-create ## Delete and recreate cluster
	@echo -e "\033[32m✓ Cluster reset complete\033[0m"

# ---- Skaffold Deployment ----
.PHONY: dev
dev: cluster-create ## Start development loop (rebuild/deploy/logs)
	@echo -e "\033[36m→ Starting Skaffold dev mode\033[0m"
	@skaffold dev -f "$(SKAFFOLD_CONFIG)" $(if $(SKAFFOLD_PROFILE),-p $(SKAFFOLD_PROFILE),)

.PHONY: dev-debug
dev-debug: cluster-create ## Start development loop in DEBUG mode with Delve
	@echo -e "\033[36m→ Starting Skaffold dev mode with DEBUG profile\033[0m"
	@echo -e "\033[33m  Debug ports: 2345-2349 (product, category, product-query, category-query, image)\033[0m"
	@skaffold dev -f "$(SKAFFOLD_CONFIG)" -p debug

.PHONY: build
build: cluster-create ## Build and push images only (no deploy)
	@echo -e "\033[36m→ Building images\033[0m"
	@skaffold build -f "$(SKAFFOLD_CONFIG)"

.PHONY: deploy
deploy: cluster-create ## One-off deploy to cluster
	@echo -e "\033[36m→ Deploying to cluster\033[0m"
	@skaffold run -f "$(SKAFFOLD_CONFIG)" --status-check $(if $(SKAFFOLD_PROFILE),-p $(SKAFFOLD_PROFILE),)
	@echo -e "\033[32m✓ Deployment complete\033[0m"

.PHONY: deploy-debug
deploy-debug: cluster-create ## Deploy in DEBUG mode
	@echo -e "\033[36m→ Deploying in DEBUG mode\033[0m"
	@skaffold run -f "$(SKAFFOLD_CONFIG)" -p debug --status-check
	@echo -e "\033[32m✓ Debug deployment complete\033[0m"

.PHONY: undeploy
undeploy: ## Delete all Skaffold-managed releases
	@echo -e "\033[33m→ Removing Skaffold deployments\033[0m"
	@skaffold delete -f "$(SKAFFOLD_CONFIG)" || true
	@echo -e "\033[32m✓ Deployments removed\033[0m"

.PHONY: redeploy
redeploy: undeploy deploy ## Undeploy and deploy again

# ---- Local Infrastructure (Docker Compose) ----
.PHONY: infra-up
infra-up: tools-check ## Start local infrastructure (MongoDB + Kafka)
	@echo -e "\033[36m→ Starting local infrastructure\033[0m"
	@docker network inspect "$(DOCKER_NETWORK)" >/dev/null 2>&1 || \
		(echo "  Creating network '$(DOCKER_NETWORK)'" && docker network create "$(DOCKER_NETWORK)")
	@docker compose -f "$(MONGO_COMPOSE)" up -d
	@docker compose -f "$(KAFKA_COMPOSE)" up -d
	@echo -e "\033[32m✓ Infrastructure started\033[0m"
	@echo "  MongoDB: mongodb://localhost:27017"
	@echo "  Kafka: localhost:9092"

.PHONY: infra-down
infra-down: ## Stop local infrastructure
	@echo -e "\033[33m→ Stopping local infrastructure\033[0m"
	@docker compose -f "$(MONGO_COMPOSE)" down
	@docker compose -f "$(KAFKA_COMPOSE)" down
	@echo -e "\033[32m✓ Infrastructure stopped\033[0m"

.PHONY: infra-logs
infra-logs: ## Show logs from local infrastructure
	@echo -e "\033[36m→ Infrastructure logs (Ctrl+C to stop)\033[0m"
	@docker compose -f "$(MONGO_COMPOSE)" -f "$(KAFKA_COMPOSE)" logs -f

.PHONY: infra-restart
infra-restart: infra-down infra-up ## Restart local infrastructure

.PHONY: infra-clean
infra-clean: infra-down ## Stop and remove volumes
	@echo -e "\033[33m→ Cleaning infrastructure volumes\033[0m"
	@docker compose -f "$(MONGO_COMPOSE)" down -v
	@docker compose -f "$(KAFKA_COMPOSE)" down -v
	@echo -e "\033[32m✓ Volumes removed\033[0m"

# ---- Kubernetes Helpers ----
.PHONY: pods
pods: ## List all pods in dev namespace
	@kubectl get pods -n "$(NAMESPACE)" -o wide

.PHONY: pods-all
pods-all: ## List pods in all namespaces
	@kubectl get pods -A -o wide

.PHONY: services
services: ## List services in dev namespace
	@kubectl get services -n "$(NAMESPACE)"

.PHONY: ingress
ingress: ## List ingresses in dev namespace
	@kubectl get ingress -n "$(NAMESPACE)"

.PHONY: describe
describe: ## Describe a pod: make describe POD=<pod-name>
ifndef POD
	@echo -e "\033[31m✗ Usage: make describe POD=<pod-name>\033[0m"
	@exit 1
endif
	@kubectl describe pod "$(POD)" -n "$(NAMESPACE)"

.PHONY: logs
logs: ## Tail logs for a service: make logs SVC=<service-name>
ifndef SVC
	@echo -e "\033[31m✗ Usage: make logs SVC=<service-name>\033[0m"
	@exit 1
endif
	@echo -e "\033[36m→ Tailing logs for '$(SVC)' (Ctrl+C to stop)\033[0m"
	@stern "$(SVC)" -n "$(NAMESPACE)"

.PHONY: logs-all
logs-all: ## Tail logs for all services in dev namespace
	@echo -e "\033[36m→ Tailing all logs in '$(NAMESPACE)' (Ctrl+C to stop)\033[0m"
	@stern ".*" -n "$(NAMESPACE)"

.PHONY: logs-select
logs-select: ## Interactive log viewer with service selection
	@bash $(THIS_DIR)scripts/logs.sh

.PHONY: exec
exec: ## Execute shell in pod: make exec POD=<pod-name>
ifndef POD
	@echo -e "\033[31m✗ Usage: make exec POD=<pod-name>\033[0m"
	@exit 1
endif
	@kubectl exec -it "$(POD)" -n "$(NAMESPACE)" -- /bin/sh

.PHONY: restart
restart: ## Restart deployment: make restart DEP=<deployment-name>
ifndef DEP
	@echo -e "\033[31m✗ Usage: make restart DEP=<deployment-name>\033[0m"
	@exit 1
endif
	@echo -e "\033[36m→ Restarting deployment '$(DEP)'\033[0m"
	@kubectl rollout restart deployment/"$(DEP)" -n "$(NAMESPACE)"
	@kubectl rollout status deployment/"$(DEP)" -n "$(NAMESPACE)"
	@echo -e "\033[32m✓ Deployment restarted\033[0m"

.PHONY: events
events: ## Show recent events in dev namespace
	@kubectl get events -n "$(NAMESPACE)" --sort-by='.lastTimestamp' | tail -20

# ---- Observability & Port Forwarding ----
.PHONY: grafana
grafana: ## Port-forward Grafana to http://localhost:3000
	@echo -e "\033[36m→ Forwarding Grafana: http://localhost:$(GRAFANA_LOCAL_PORT)\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(OBS_NS)" port-forward "svc/$(GRAFANA_SVC)" "$(GRAFANA_LOCAL_PORT):$(GRAFANA_SVC_PORT)"

.PHONY: prometheus
prometheus: ## Port-forward Prometheus to http://localhost:9090
	@echo -e "\033[36m→ Forwarding Prometheus: http://localhost:9090\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(OBS_NS)" port-forward "svc/prometheus-server" 9090:80

.PHONY: minio
minio: ## Port-forward MinIO console to http://localhost:9001
	@echo -e "\033[36m→ Forwarding MinIO Console: http://localhost:9001\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(MINIO_NS)" port-forward "svc/minio-console" 9001:9001

.PHONY: traefik
traefik: ## Port-forward Traefik dashboard to http://localhost:9000
	@echo -e "\033[36m→ Forwarding Traefik Dashboard: http://localhost:9000\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(TRAEFIK_NS)" port-forward "svc/traefik" 9000:9000

.PHONY: forward-all
forward-all: ## Port-forward all observability services (requires multiple terminals)
	@echo -e "\033[36mAvailable port forwards:\033[0m"
	@echo "  \033[32mmake grafana\033[0m     - Grafana at http://localhost:3000"
	@echo "  \033[32mmake prometheus\033[0m  - Prometheus at http://localhost:9090"
	@echo "  \033[32mmake minio\033[0m       - MinIO Console at http://localhost:9001"
	@echo "  \033[32mmake traefik\033[0m     - Traefik Dashboard at http://localhost:9000"
	@echo ""
	@echo -e "\033[33mRun each in a separate terminal\033[0m"

# ---- Debug Helpers ----
.PHONY: debug-info
debug-info: ## Show debug port forwarding information
	@echo -e "\033[36mDebug Port Mappings:\033[0m"
	@echo "  localhost:2345 → ecommerce-product-service"
	@echo "  localhost:2346 → ecommerce-category-service"
	@echo "  localhost:2347 → ecommerce-product-query-service"
	@echo "  localhost:2348 → ecommerce-category-query-service"
	@echo "  localhost:2349 → ecommerce-image-service"
	@echo ""
	@echo -e "\033[36mVS Code Debug Configuration:\033[0m"
	@echo "  Use 'Attach to K3D' configurations in launch.json"
	@echo ""
	@echo -e "\033[36mTo start debugging:\033[0m"
	@echo "  1. Run: \033[32mmake dev-debug\033[0m"
	@echo "  2. Wait for services to start"
	@echo "  3. In VS Code, select 'Attach to K3D' config and press F5"

.PHONY: debug-check
debug-check: ## Check if debug ports are accessible
	@echo -e "\033[36m→ Checking debug ports...\033[0m"
	@for port in 2345 2346 2347 2348 2349; do \
		if nc -z localhost $$port 2>/dev/null; then \
			echo "  \033[32m✓ Port $$port\033[0m - accessible"; \
		else \
			echo "  \033[31m✗ Port $$port\033[0m - not accessible"; \
		fi; \
	done

# ---- Development Workflows ----
.PHONY: init
init: tools-check cluster-create infra-up deploy ## Complete initialization (cluster + infra + deploy)
	@echo ""
	@echo -e "\033[32m✓ Development environment ready!\033[0m"
	@echo ""
	@echo -e "\033[36mNext steps:\033[0m"
	@echo "  - Run \033[32mmake dev\033[0m to start development mode"
	@echo "  - Run \033[32mmake dev-debug\033[0m for debugging"
	@echo "  - Run \033[32mmake status\033[0m to check cluster status"
	@echo "  - Run \033[32mmake grafana\033[0m to access observability"

.PHONY: clean
clean: undeploy infra-clean cluster-delete ## Complete cleanup (cluster + infra + deployments)
	@echo -e "\033[32m✓ Complete cleanup finished\033[0m"

.PHONY: reset
reset: clean init ## Complete reset (clean + init)
	@echo -e "\033[32m✓ Environment reset complete\033[0m"

# ---- Helm Management ----
.PHONY: helm-list
helm-list: ## List all Helm releases
	@helm list -A

.PHONY: helm-status
helm-status: ## Show status of ecommerce release
	@helm status ecommerce -n "$(NAMESPACE)"

.PHONY: helm-values
helm-values: ## Show computed values for ecommerce release
	@helm get values ecommerce -n "$(NAMESPACE)"

.PHONY: helm-template
helm-template: ## Show rendered Helm templates
	@helm template ecommerce "$(CHART_PATH)"

.PHONY: helm-upgrade
helm-upgrade: ## Manually upgrade Helm chart
	@echo -e "\033[36m→ Upgrading Helm release\033[0m"
	@helm upgrade --install ecommerce "$(CHART_PATH)" -n "$(NAMESPACE)" --create-namespace
	@echo -e "\033[32m✓ Helm release upgraded\033[0m"

# ---- Quick Commands (Aliases) ----
.PHONY: up
up: cluster-start infra-up ## Quick start: cluster + infrastructure

.PHONY: down
down: infra-down cluster-stop ## Quick stop: infrastructure + cluster

.PHONY: ps
ps: pods ## Alias for 'pods'

.PHONY: svc
svc: services ## Alias for 'services'

# ---- Monitoring & Health Checks ----
.PHONY: health
health: ## Check health of all services
	@echo -e "\033[36m→ Checking service health...\033[0m"
	@kubectl get deployments -n "$(NAMESPACE)" -o custom-columns=\
'NAME:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas,UP-TO-DATE:.status.updatedReplicas'

.PHONY: resources
resources: ## Show resource usage
	@echo -e "\033[36m→ Node resource usage:\033[0m"
	@kubectl top nodes 2>/dev/null || echo "  \033[33mMetrics not available (metrics-server required)\033[0m"
	@echo ""
	@echo -e "\033[36m→ Pod resource usage in '$(NAMESPACE)':\033[0m"
	@kubectl top pods -n "$(NAMESPACE)" 2>/dev/null || echo "  \033[33mMetrics not available (metrics-server required)\033[0m"

.PHONY: namespaces
namespaces: ## List all namespaces
	@kubectl get namespaces

.PHONY: context
context: ## Show current kubectl context
	@kubectl config current-context

.PHONY: contexts
contexts: ## List all kubectl contexts
	@kubectl config get-contexts