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
	@printf "  \033[36m%-35s\033[0m %s\n" "Catalog Service API:" "http://ecommerce-catalog-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Product Query API:" "http://ecommerce-product-query-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Category Query API:" "http://ecommerce-category-query-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Image Service API:" "http://ecommerce-image-service.127.0.0.1.nip.io"
	@printf "  \033[36m%-35s\033[0m %s\n" "Admin UI:" "http://admin.127.0.0.1.nip.io"
	@printf "\n\033[1;33mDevelopment Tools:\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s\n" "Tilt Dashboard:" "http://localhost:10350"
	@printf "\n\033[1;33mKafka & Messaging:\033[0m\n"
	@printf "  \033[36m%-35s\033[0m %s\n" "Redpanda Console:" "http://localhost:9093"
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
# Profiling (pprof)
# =============================================================================

PPROF_UI_PORT ?= 8081

# Pprof ports per service (must match Tiltfile pprof_port)
PPROF_PORT_catalog   := 6060
PPROF_PORT_product   := 6061
PPROF_PORT_category  := 6062
PPROF_PORT_image     := 6063
PPROF_PORT_auth      := 6064

.PHONY: pprof-heap pprof-cpu pprof-goroutine pprof-allocs pprof

pprof: ## Show available pprof commands
	@printf "\033[1mPprof profiling targets:\033[0m\n\n"
	@printf "  \033[36mmake pprof-heap SVC=catalog\033[0m      — memory profile\n"
	@printf "  \033[36mmake pprof-cpu SVC=catalog\033[0m       — CPU profile (30s)\n"
	@printf "  \033[36mmake pprof-allocs SVC=catalog\033[0m    — allocations profile\n"
	@printf "  \033[36mmake pprof-goroutine SVC=catalog\033[0m — goroutine profile\n"
	@printf "\n  Available SVC values: catalog, product, category, image, auth\n"
	@printf "  UI opens on: http://localhost:$(PPROF_UI_PORT)\n\n"

pprof-heap: ## Open heap (memory) profile in browser (SVC=catalog|product|category|image|auth)
	@go tool pprof -http=:$(PPROF_UI_PORT) http://localhost:$(PPROF_PORT_$(SVC))/debug/pprof/heap

pprof-cpu: ## Open CPU profile in browser - records for 30s (SVC=catalog|product|category|image|auth)
	@go tool pprof -http=:$(PPROF_UI_PORT) http://localhost:$(PPROF_PORT_$(SVC))/debug/pprof/profile?seconds=30

pprof-allocs: ## Open allocations profile in browser (SVC=catalog|product|category|image|auth)
	@go tool pprof -http=:$(PPROF_UI_PORT) http://localhost:$(PPROF_PORT_$(SVC))/debug/pprof/allocs

pprof-goroutine: ## Open goroutine profile in browser (SVC=catalog|product|category|image|auth)
	@go tool pprof -http=:$(PPROF_UI_PORT) http://localhost:$(PPROF_PORT_$(SVC))/debug/pprof/goroutine

# =============================================================================
# Demo Data Seeder
# =============================================================================

SEEDER_DIR := $(THIS_DIR)cmd/seeder
SEEDER_BIN := $(SEEDER_DIR)/seeder
AUTH_SERVICE_DIR := $(THIS_DIR)../ecommerce-auth-service
SEEDER_PRIVATE_KEY := e9bc26b8119fa3ccd616e3bd05603507fd308cb30a0a99c4b858c621dd147f1beb6ebefd6a2b0a304d43c2ccca329aef0a1439d429dbe8ca9b6190622ce38341

.PHONY: seed-build
seed-build: ## Build the demo data seeder
	@printf "\033[36m→ Building seeder...\033[0m\n"
	cd $(SEEDER_DIR) && go build -o seeder .
	@printf "\033[32m✓ Seeder built successfully\033[0m\n"

.PHONY: seed
seed: seed-build ## Seed the database with demo data
	@printf "\033[36m→ Generating service token...\033[0m\n"
	$(eval SEEDER_TOKEN := $(shell cd $(AUTH_SERVICE_DIR) && go run ./cmd/servicetoken \
		-private-key="$(SEEDER_PRIVATE_KEY)" \
		-name=seeder \
		-role=super_admin \
		-permissions="products:read,products:write,products:delete,categories:read,categories:write,categories:delete,attributes:read,attributes:write,attributes:delete" \
		-duration=87600h 2>/dev/null | tail -1))
	@printf "\033[36m→ Seeding demo data...\033[0m\n"
	cd $(SEEDER_DIR) && SEEDER_TOKEN="$(SEEDER_TOKEN)" ./seeder
