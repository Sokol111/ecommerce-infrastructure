# =============================================================================
# E-Commerce Production Deployment Makefile
# =============================================================================
# Usage: make [target]
# Run `make help` to see all available targets

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

# Colors for output
COLOR_RESET := \033[0m
COLOR_BOLD := \033[1m
COLOR_GREEN := \033[32m
COLOR_YELLOW := \033[33m
COLOR_BLUE := \033[36m
COLOR_RED := \033[31m

# Docker Compose configuration
COMPOSE_FILE := docker-compose.yml
COMPOSE := docker compose -f $(COMPOSE_FILE)

# Service groups
INFRA_SERVICES := mongo mongo-init kafka schema-registry minio minio-init imgproxy
OBSERVABILITY_SERVICES := alloy prometheus tempo loki grafana
APP_SERVICES := auth-service catalog-service image-service product-query-service category-query-service admin-ui ecommerce-ui
ALL_SERVICES := $(INFRA_SERVICES) $(OBSERVABILITY_SERVICES) $(APP_SERVICES) traefik

.DEFAULT_GOAL := help

# =============================================================================
# Help
# =============================================================================

.PHONY: help
help: ## Show this help message
	@printf "$(COLOR_BOLD)E-Commerce Production Deployment$(COLOR_RESET)\n\n"
	@printf "$(COLOR_YELLOW)Usage:$(COLOR_RESET) make [target]\n\n"
	@printf "$(COLOR_YELLOW)Targets:$(COLOR_RESET)\n"
	@awk 'BEGIN {FS = ":.*##"; } \
		/^[a-zA-Z_-]+:.*?##/ { printf "  $(COLOR_GREEN)%-20s$(COLOR_RESET) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(COLOR_BOLD)%s$(COLOR_RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# =============================================================================
##@ Deployment
# =============================================================================

.PHONY: deploy
deploy: check-env ## Deploy the entire stack
	@printf "$(COLOR_BLUE)→ Deploying entire stack...$(COLOR_RESET)\n"
	$(COMPOSE) up -d
	@printf "$(COLOR_GREEN)✓ Stack deployed successfully$(COLOR_RESET)\n"
	@$(MAKE) --no-print-directory status

.PHONY: deploy-fresh
deploy-fresh: check-env ## Force recreate all containers (use after config changes)
	@printf "$(COLOR_BLUE)→ Recreating all containers...$(COLOR_RESET)\n"
	$(COMPOSE) up -d --force-recreate
	@printf "$(COLOR_GREEN)✓ All containers recreated$(COLOR_RESET)\n"
	@$(MAKE) --no-print-directory status

.PHONY: deploy-infra
deploy-infra: check-env ## Deploy infrastructure services (MongoDB, Kafka, MinIO, imgproxy)
	@printf "$(COLOR_BLUE)→ Deploying infrastructure services...$(COLOR_RESET)\n"
	$(COMPOSE) up -d $(INFRA_SERVICES)
	@printf "$(COLOR_GREEN)✓ Infrastructure deployed$(COLOR_RESET)\n"

.PHONY: deploy-observability
deploy-observability: check-env ## Deploy observability stack (OTel, Prometheus, Grafana, etc.)
	@printf "$(COLOR_BLUE)→ Deploying observability services...$(COLOR_RESET)\n"
	$(COMPOSE) up -d $(OBSERVABILITY_SERVICES)
	@printf "$(COLOR_GREEN)✓ Observability stack deployed$(COLOR_RESET)\n"

.PHONY: deploy-services
deploy-services: check-env ## Deploy application services (Go microservices + UIs)
	@printf "$(COLOR_BLUE)→ Deploying application services...$(COLOR_RESET)\n"
	$(COMPOSE) up -d $(APP_SERVICES)
	@printf "$(COLOR_GREEN)✓ Application services deployed$(COLOR_RESET)\n"

.PHONY: deploy-traefik
deploy-traefik: check-env ## Deploy Traefik reverse proxy
	@printf "$(COLOR_BLUE)→ Deploying Traefik...$(COLOR_RESET)\n"
	$(COMPOSE) up -d traefik
	@printf "$(COLOR_GREEN)✓ Traefik deployed$(COLOR_RESET)\n"

# =============================================================================
##@ Lifecycle Management
# =============================================================================

.PHONY: down
down: ## Stop and remove all containers
	@printf "$(COLOR_YELLOW)→ Stopping all services...$(COLOR_RESET)\n"
	$(COMPOSE) down
	@printf "$(COLOR_GREEN)✓ All services stopped$(COLOR_RESET)\n"

.PHONY: down-volumes
down-volumes: ## Stop all containers and remove volumes (⚠️ DATA LOSS)
	@printf "$(COLOR_RED)⚠️  WARNING: This will delete all data!$(COLOR_RESET)\n"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	$(COMPOSE) down -v
	@printf "$(COLOR_GREEN)✓ All services and volumes removed$(COLOR_RESET)\n"

.PHONY: restart
restart: ## Restart all services
	@printf "$(COLOR_BLUE)→ Restarting all services...$(COLOR_RESET)\n"
	$(COMPOSE) restart
	@printf "$(COLOR_GREEN)✓ All services restarted$(COLOR_RESET)\n"

.PHONY: restart-services
restart-services: ## Restart only application services
	@printf "$(COLOR_BLUE)→ Restarting application services...$(COLOR_RESET)\n"
	$(COMPOSE) restart $(APP_SERVICES)
	@printf "$(COLOR_GREEN)✓ Application services restarted$(COLOR_RESET)\n"

.PHONY: stop
stop: ## Stop all services (without removing)
	@printf "$(COLOR_YELLOW)→ Stopping all services...$(COLOR_RESET)\n"
	$(COMPOSE) stop
	@printf "$(COLOR_GREEN)✓ All services stopped$(COLOR_RESET)\n"

.PHONY: start
start: ## Start stopped services
	@printf "$(COLOR_BLUE)→ Starting services...$(COLOR_RESET)\n"
	$(COMPOSE) start
	@printf "$(COLOR_GREEN)✓ Services started$(COLOR_RESET)\n"

# =============================================================================
##@ Updates & Images
# =============================================================================

.PHONY: pull
pull: ## Pull latest images for all services
	@printf "$(COLOR_BLUE)→ Pulling latest images...$(COLOR_RESET)\n"
	$(COMPOSE) pull
	@printf "$(COLOR_GREEN)✓ Images updated$(COLOR_RESET)\n"

.PHONY: pull-services
pull-services: ## Pull latest images for application services only
	@printf "$(COLOR_BLUE)→ Pulling latest application images...$(COLOR_RESET)\n"
	$(COMPOSE) pull $(APP_SERVICES)
	@printf "$(COLOR_GREEN)✓ Application images updated$(COLOR_RESET)\n"

.PHONY: upgrade
upgrade: pull ## Pull latest images and redeploy
	@printf "$(COLOR_BLUE)→ Upgrading stack...$(COLOR_RESET)\n"
	$(COMPOSE) up -d
	@printf "$(COLOR_GREEN)✓ Stack upgraded$(COLOR_RESET)\n"

.PHONY: upgrade-services
upgrade-services: pull-services ## Pull and redeploy application services
	@printf "$(COLOR_BLUE)→ Upgrading application services...$(COLOR_RESET)\n"
	$(COMPOSE) up -d $(APP_SERVICES)
	@printf "$(COLOR_GREEN)✓ Application services upgraded$(COLOR_RESET)\n"

# =============================================================================
##@ Monitoring & Logs
# =============================================================================

.PHONY: status
status: ## Show status of all services
	@printf "$(COLOR_BOLD)Service Status:$(COLOR_RESET)\n"
	@$(COMPOSE) ps -a

.PHONY: ps
ps: status ## Alias for status

.PHONY: health
health: ## Check health of all services
	@printf "$(COLOR_BOLD)Health Check:$(COLOR_RESET)\n"
	@for svc in $(ALL_SERVICES); do \
		status=$$($(COMPOSE) ps -q $$svc 2>/dev/null | xargs -r docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck"); \
		if [ "$$status" = "healthy" ]; then \
			printf "$(COLOR_GREEN)✓ %-30s healthy$(COLOR_RESET)\n" "$$svc"; \
		elif [ "$$status" = "unhealthy" ]; then \
			printf "$(COLOR_RED)✗ %-30s unhealthy$(COLOR_RESET)\n" "$$svc"; \
		elif [ "$$status" = "starting" ]; then \
			printf "$(COLOR_YELLOW)◐ %-30s starting$(COLOR_RESET)\n" "$$svc"; \
		else \
			printf "$(COLOR_BLUE)○ %-30s $$status$(COLOR_RESET)\n" "$$svc"; \
		fi \
	done

.PHONY: logs
logs: ## Follow logs for all services
	$(COMPOSE) logs -f

.PHONY: logs-infra
logs-infra: ## Follow logs for infrastructure services
	$(COMPOSE) logs -f $(INFRA_SERVICES)

.PHONY: logs-observability
logs-observability: ## Follow logs for observability services
	$(COMPOSE) logs -f $(OBSERVABILITY_SERVICES)

.PHONY: logs-services
logs-services: ## Follow logs for application services
	$(COMPOSE) logs -f $(APP_SERVICES)

.PHONY: logs-service
logs-service: ## Follow logs for a specific service (usage: make logs-service SVC=auth-service)
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make logs-service SVC=<service-name>\n"
	@printf "Available services: $(ALL_SERVICES)\n"
	@exit 1
endif
	$(COMPOSE) logs -f $(SVC)

# =============================================================================
##@ Maintenance
# =============================================================================

.PHONY: clean
clean: ## Remove stopped containers and unused images
	@printf "$(COLOR_BLUE)→ Cleaning up...$(COLOR_RESET)\n"
	docker system prune -f
	@printf "$(COLOR_GREEN)✓ Cleanup complete$(COLOR_RESET)\n"

.PHONY: clean-all
clean-all: ## Remove all unused Docker resources (⚠️ affects other projects)
	@printf "$(COLOR_RED)⚠️  WARNING: This affects ALL Docker resources!$(COLOR_RESET)\n"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	docker system prune -a -f --volumes
	@printf "$(COLOR_GREEN)✓ Full cleanup complete$(COLOR_RESET)\n"

.PHONY: backup-volumes
backup-volumes: ## Backup data volumes to ./backups/
	@printf "$(COLOR_BLUE)→ Creating backup...$(COLOR_RESET)\n"
	@mkdir -p backups
	@timestamp=$$(date +%Y%m%d_%H%M%S)
	@for vol in mongo_data kafka_data minio_data prometheus_data tempo_data loki_data grafana_data; do \
		printf "  Backing up $$vol...\n"; \
		docker run --rm -v ecommerce_$$vol:/data -v $$(pwd)/backups:/backup alpine \
			tar czf /backup/$${vol}_$${timestamp}.tar.gz -C /data . 2>/dev/null || true; \
	done
	@printf "$(COLOR_GREEN)✓ Backup complete: ./backups/$(COLOR_RESET)\n"

# =============================================================================
##@ Configuration
# =============================================================================

.PHONY: check-env
check-env: ## Verify .env file exists and has required variables
	@if [ ! -f .env ]; then \
		printf "$(COLOR_RED)Error: .env file not found$(COLOR_RESET)\n"; \
		printf "Copy .env.example to .env and fill in the values:\n"; \
		printf "  cp .env.example .env\n"; \
		exit 1; \
	fi
	@missing=""; \
	for var in DOMAIN MONGO_ROOT_PASSWORD MINIO_ROOT_PASSWORD AUTH_TOKEN_PRIVATE_KEY AUTH_TOKEN_PUBLIC_KEY GRAFANA_ADMIN_PASSWORD IMGPROXY_KEY IMGPROXY_SALT; do \
		val=$$(grep -E "^$$var=" .env | cut -d'=' -f2-); \
		if [ -z "$$val" ] || [ "$$val" = "CHANGE_ME_STRONG_PASSWORD" ] || [ "$$val" = "CHANGE_ME_STRONG_PASSWORD_HERE" ]; then \
			missing="$$missing $$var"; \
		fi; \
	done; \
	if [ -n "$$missing" ]; then \
		printf "$(COLOR_RED)Error: Missing or default values for:$$missing$(COLOR_RESET)\n"; \
		exit 1; \
	fi
	@printf "$(COLOR_GREEN)✓ Environment configuration valid$(COLOR_RESET)\n"

.PHONY: show-config
show-config: ## Show current configuration (without secrets)
	@printf "$(COLOR_BOLD)Current Configuration:$(COLOR_RESET)\n"
	@printf "  Domain: $$(grep -E '^DOMAIN=' .env | cut -d'=' -f2)\n"
	@printf "  ACME Email: $$(grep -E '^ACME_EMAIL=' .env | cut -d'=' -f2)\n"
	@printf "  Admin Email: $$(grep -E '^ADMIN_EMAIL=' .env | cut -d'=' -f2)\n"
	@printf "\n$(COLOR_BOLD)Image Tags:$(COLOR_RESET)\n"
	@grep -E '_TAG=' .env | while read line; do printf "  $$line\n"; done

.PHONY: generate-secrets
generate-secrets: ## Generate secure random values for secrets
	@printf "$(COLOR_BOLD)Generated Secrets (copy to .env):$(COLOR_RESET)\n\n"
	@printf "# MongoDB\n"
	@printf "MONGO_ROOT_PASSWORD=$$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)\n\n"
	@printf "# MinIO\n"
	@printf "MINIO_ROOT_PASSWORD=$$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)\n\n"
	@printf "# imgproxy\n"
	@printf "IMGPROXY_KEY=$$(openssl rand -hex 32)\n"
	@printf "IMGPROXY_SALT=$$(openssl rand -hex 32)\n\n"
	@printf "# Auth tokens (use your service's keygen tool for production)\n"
	@printf "# AUTH_TOKEN_PRIVATE_KEY=<generate with auth-service keygen>\n"
	@printf "# AUTH_TOKEN_PUBLIC_KEY=<generate with auth-service keygen>\n\n"
	@printf "# Grafana\n"
	@printf "GRAFANA_ADMIN_PASSWORD=$$(openssl rand -base64 32 | tr -d '/+=' | head -c 24)\n\n"
	@printf "# Kafka Cluster ID\n"
	@printf "KAFKA_CLUSTER_ID=$$(openssl rand -base64 22 | tr -d '/+=' | head -c 22)\n"

# =============================================================================
##@ Quick Access
# =============================================================================

.PHONY: shell-mongo
shell-mongo: ## Open MongoDB shell
	@$(COMPOSE) exec mongo mongosh -u $$(grep MONGO_ROOT_USERNAME .env | cut -d'=' -f2) -p $$(grep MONGO_ROOT_PASSWORD .env | cut -d'=' -f2)

.PHONY: shell-kafka
shell-kafka: ## Open Kafka container shell
	@$(COMPOSE) exec kafka /bin/bash

.PHONY: urls
urls: ## Show service URLs
	@domain=$$(grep -E '^DOMAIN=' .env | cut -d'=' -f2)
	@printf "$(COLOR_BOLD)Service URLs:$(COLOR_RESET)\n"
	@printf "  $(COLOR_GREEN)Main UI:$(COLOR_RESET)        https://$$domain\n"
	@printf "  $(COLOR_GREEN)Admin UI:$(COLOR_RESET)       https://admin.$$domain\n"
	@printf "  $(COLOR_GREEN)API:$(COLOR_RESET)            https://api.$$domain/api/v1/\n"
	@printf "  $(COLOR_GREEN)Grafana:$(COLOR_RESET)        https://grafana.$$domain\n"
	@printf "  $(COLOR_GREEN)Traefik:$(COLOR_RESET)        https://traefik.$$domain\n"
