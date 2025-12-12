# ---- Config ----
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Environment
ENV ?= local
ENV_DIR := $(THIS_DIR)environments/$(ENV)

# K3d
K3D_CONFIG ?= $(ENV_DIR)/k3d-cluster.yaml
CLUSTER_NAME ?= dev-cluster
K3D_CONTEXT := k3d-$(CLUSTER_NAME)

# Namespaces
NAMESPACE ?= dev
OBS_NS ?= observability
TRAEFIK_NS ?= traefik

# Infrastructure Helm charts
TRAEFIK_VALUES ?= $(THIS_DIR)helm/values/infrastructure/traefik.yaml
OTELCOL_VALUES ?= $(THIS_DIR)helm/values/observability/otelcol.yaml

# Docker compose
COMPOSE_DIR := $(THIS_DIR)docker/compose
MONGO_COMPOSE := $(COMPOSE_DIR)/mongo.yml
KAFKA_COMPOSE := $(COMPOSE_DIR)/kafka.yml
OBSERVABILITY_COMPOSE := $(COMPOSE_DIR)/observability.yml
STORAGE_COMPOSE := $(COMPOSE_DIR)/storage.yml
DOCKER_NETWORK := shared-network

# Observability services (docker-compose)
GRAFANA_URL ?= http://localhost:3000
PROMETHEUS_URL ?= http://localhost:9090
TEMPO_URL ?= http://localhost:3200

# Storage services (docker-compose)
MINIO_CONSOLE_URL ?= http://localhost:9001
IMGPROXY_URL ?= http://localhost:8083

.DEFAULT_GOAL := help

# ---- Include Modules ----
include $(THIS_DIR)makefiles/cluster.mk
include $(THIS_DIR)makefiles/docker.mk
include $(THIS_DIR)makefiles/infra.mk
include $(THIS_DIR)makefiles/tilt.mk
include $(THIS_DIR)makefiles/lifecycle.mk

# =============================================================================
# Help & Tools
# =============================================================================

.PHONY: help
help: ## Show available commands
	@printf "\033[1m%s - Available targets:\033[0m\n\n" "ecommerce-infrastructure"
	@awk 'BEGIN {FS = ":.*?## "; category = ""} \
		/^# =+$$/ {getline; if ($$0 ~ /^# /) {gsub(/^# /, "", $$0); gsub(/ *$$/, "", $$0); category = $$0}} \
		/^[a-zA-Z_-]+:.*?## / { \
			if (category != last_category) { \
				if (last_category != "") printf "\n"; \
				printf "\033[1;33m%s:\033[0m\n", category; \
				last_category = category \
			} \
			printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)
	@echo ""

.PHONY: tools-check
tools-check: ## Verify required tools are installed
	@printf "\033[36m→ Checking required tools...\033[0m\n"
	@missing=0; \
	for tool in k3d kubectl tilt helm docker; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			printf "  \033[31m✗ $$tool\033[0m not found in PATH\n"; \
			missing=1; \
		else \
			printf "  \033[32m✓ $$tool\033[0m\n"; \
		fi; \
	done; \
	if ! docker compose version >/dev/null 2>&1; then \
		printf "  \033[31m✗ docker compose\033[0m not available\n"; \
		missing=1; \
	else \
		printf "  \033[32m✓ docker compose\033[0m\n"; \
	fi; \
	if [ $$missing -eq 1 ]; then \
		printf "\033[31m✗ Some tools are missing\033[0m\n"; \
		exit 1; \
	fi
	@printf "\033[32m✓ All required tools are installed\033[0m\n"

.PHONY: urls
urls: ## Show all service URLs available in browser
	@printf "\033[1m%s - Service URLs:\033[0m\n\n" "ecommerce-infrastructure"
	@printf "\033[1;33mApplication Services (via Traefik Ingress):\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s\n" "Product Service API:" "http://ecommerce-product-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Category Service API:" "http://ecommerce-category-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Product Query API:" "http://ecommerce-product-query-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Category Query API:" "http://ecommerce-category-query-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Image Service API:" "http://ecommerce-image-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Admin UI:" "http://admin.127.0.0.1.nip.io"
	@printf "\n\033[1;33mDevelopment Tools:\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s\n" "Tilt Dashboard:" "http://localhost:10350"
	@printf "\n\033[1;33mKafka & Messaging:\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s\n" "Kafka UI:" "http://localhost:9093"
	@printf "  \033[36m%-35s\033[0m %s\n" "Schema Registry:" "http://localhost:8084"
	@printf "\n\033[1;33mStorage:\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s (minioadmin/minioadmin123)\n" "MinIO Console:" "$(MINIO_CONSOLE_URL)"
	@printf "  \033[36m%-35s\033[0m %s\n" "imgproxy:" "$(IMGPROXY_URL)"
	@printf "\n\033[1;33mObservability:\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s (admin/admin)\n" "Grafana:" "$(GRAFANA_URL)"
	@printf "  \033[36m%-35s\033[0m %s\n" "Prometheus:" "$(PROMETHEUS_URL)"
	@printf "  \033[36m%-35s\033[0m %s\n" "Tempo:" "$(TEMPO_URL)"
	@printf "\n\033[1;33mDirect Port Forwards (when Tilt is running):\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s\n" "Product Service:" "http://localhost:8081"
	@printf "  \033[36m%-35s\033[0m %s\n" "Category Service:" "http://localhost:8082"
	@printf "  \033[36m%-35s\033[0m %s\n" "Product Query Service:" "http://localhost:8083"
	@printf "  \033[36m%-35s\033[0m %s\n" "Category Query Service:" "http://localhost:8084"
	@printf "  \033[36m%-35s\033[0m %s\n" "Image Service:" "http://localhost:8085"
	@printf "  \033[36m%-35s\033[0m %s\n" "Admin UI:" "http://localhost:3000"
	@printf "\n"

# =============================================================================
# Demo Data Seeder
# =============================================================================

SEEDER_DIR := $(THIS_DIR)cmd/seeder
SEEDER_BIN := $(SEEDER_DIR)/seeder

.PHONY: seed-build
seed-build: ## Build the demo data seeder
	@printf "\033[36m→ Building seeder...\033[0m\n"
	cd $(SEEDER_DIR) && go build -o seeder .
	@printf "\033[32m✓ Seeder built successfully\033[0m\n"

.PHONY: seed
seed: seed-build ## Seed the database with demo data
	@printf "\033[36m→ Seeding demo data...\033[0m\n"
	cd $(SEEDER_DIR) && ./seeder -verbose
