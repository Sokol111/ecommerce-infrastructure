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
help: ## Показати довідку з усіма доступними командами та їх описами
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
tools-check: ## Перевірити наявність усіх необхідних інструментів (k3d, kubectl, tilt, helm, stern, docker)
	@printf "\033[36m→ Checking required tools...\033[0m\n"
	@missing=0; \
	for tool in k3d kubectl tilt helm stern docker; do \
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
