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

# Skaffold
SKAFFOLD_CONFIG ?= $(ENV_DIR)/skaffold.yaml
SKAFFOLD_PROFILE ?=

# Namespaces
NAMESPACE ?= dev
OBS_NS ?= observability
TRAEFIK_NS ?= traefik
MINIO_NS ?= minio

# Umbrella chart
CHART_PATH ?= $(THIS_DIR)helm/ecommerce-go-service

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

# =============================================================================
# Help & Information
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
tools-check: ## Перевірити наявність усіх необхідних інструментів (k3d, kubectl, skaffold, helm, stern, docker)
	@printf "\033[36m→ Checking required tools...\033[0m\n"
	@missing=0; \
	for tool in k3d kubectl skaffold helm stern docker; do \
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

.PHONY: check-env
check-env: ## Запустити комплексну перевірку середовища розробки (інструменти, конфіги, доступність портів)
	@bash $(THIS_DIR)scripts/setup/check-env.sh

.PHONY: status
status: ## Показати статус кластера, нод, деплойментів та сервісів у namespace 'dev'
	@printf "\033[36m→ K3d Cluster Status:\033[0m\n"
	@if cluster_info=$$(k3d cluster list 2>/dev/null | grep "$(CLUSTER_NAME)"); then \
		echo "$$cluster_info"; \
		echo ""; \
		printf "\033[36m→ Kubernetes Context:\033[0m\n"; \
		kubectl config current-context 2>/dev/null || echo "  No context set"; \
		echo ""; \
		printf "\033[36m→ Nodes:\033[0m\n"; \
		kubectl get nodes -o wide 2>/dev/null || echo "  Cluster not accessible"; \
		echo ""; \
		printf "\033[36m→ Deployments in '$(NAMESPACE)':\033[0m\n"; \
		kubectl get deployments -n "$(NAMESPACE)" 2>/dev/null || echo "  Namespace not found"; \
		echo ""; \
		printf "\033[36m→ Services in '$(NAMESPACE)':\033[0m\n"; \
		kubectl get services -n "$(NAMESPACE)" 2>/dev/null || echo "  Namespace not found"; \
	else \
		echo "  \033[33mCluster '$(CLUSTER_NAME)' not found\033[0m"; \
	fi

# =============================================================================
# K3d Cluster Management
# =============================================================================

.PHONY: cluster-create
cluster-create: tools-check ## Створити k3d кластер на основі k3d-cluster.yaml конфігурації з портами та налаштуваннями
	@if [ ! -f "$(K3D_CONFIG)" ]; then \
		printf "\033[31m✗ Missing config: $(K3D_CONFIG)\033[0m\n"; \
		exit 1; \
	fi
	@if k3d cluster list 2>/dev/null | grep -q "$(CLUSTER_NAME)"; then \
		printf "\033[33m✓ Cluster '$(CLUSTER_NAME)' already exists — skipping\033[0m\n"; \
	else \
		printf "\033[36m→ Creating cluster '$(CLUSTER_NAME)' from $(K3D_CONFIG)\033[0m\n"; \
		k3d cluster create --config "$(K3D_CONFIG)"; \
		printf "\033[32m✓ Cluster created\033[0m\n"; \
	fi
	@kubectl config use-context "$(K3D_CONTEXT)" 2>/dev/null || true

.PHONY: cluster-delete
cluster-delete: ## Повністю видалити k3d кластер разом з контекстом kubectl та всіма даними
	@printf "\033[33m→ Deleting cluster '$(CLUSTER_NAME)'\033[0m\n"
	@k3d cluster delete "$(CLUSTER_NAME)" 2>/dev/null || true
	@kubectl config delete-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-cluster "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-user "admin@$(K3D_CONTEXT)" 2>/dev/null || true
	@printf "\033[32m✓ Cluster deleted\033[0m\n"

.PHONY: cluster-restart
cluster-restart: cluster-stop cluster-start ## Перезапустити k3d кластер (зупинити та знову запустити без видалення даних)

.PHONY: cluster-stop
cluster-stop: ## Зупинити k3d кластер (контейнери зупиняються, але дані зберігаються)
	@printf "\033[36m→ Stopping cluster '$(CLUSTER_NAME)'\033[0m\n"
	@k3d cluster stop "$(CLUSTER_NAME)"
	@printf "\033[32m✓ Cluster stopped\033[0m\n"

.PHONY: cluster-start
cluster-start: ## Запустити зупинений k3d кластер та автоматично переключити kubectl контекст
	@printf "\033[36m→ Starting cluster '$(CLUSTER_NAME)'\033[0m\n"
	@k3d cluster start "$(CLUSTER_NAME)"
	@kubectl config use-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@printf "\033[32m✓ Cluster started\033[0m\n"

.PHONY: cluster-reset
cluster-reset: cluster-delete cluster-create ## Повністю видалити та заново створити кластер (очищення всіх даних та стану)
	@printf "\033[32m✓ Cluster reset complete\033[0m\n"

# =============================================================================
# Skaffold Deployment
# =============================================================================

.PHONY: dev
dev: cluster-create ## Запустити режим розробки з автоматичною пересборкою, деплоєм та показом логів при змінах коду (включає debug режим з Delve)
	@printf "\033[36m→ Starting Skaffold dev mode (debug-enabled)\033[0m\n"
	@printf "\033[33m  Debug ports: 2345-2349 (product, category, product-query, category-query, image)\033[0m\n"
	@skaffold dev -f "$(SKAFFOLD_CONFIG)" $(if $(SKAFFOLD_PROFILE),-p $(SKAFFOLD_PROFILE),)



.PHONY: build
build: cluster-create ## Побудувати Docker образи для всіх сервісів без деплою в кластер
	@printf "\033[36m→ Building images\033[0m\n"
	@skaffold build -f "$(SKAFFOLD_CONFIG)"

.PHONY: deploy
deploy: cluster-create ## Одноразовий деплой всіх сервісів в кластер через Skaffold та Helm (debug-enabled з Delve)
	@printf "\033[36m→ Deploying to cluster (debug-enabled)\033[0m\n"
	@skaffold run -f "$(SKAFFOLD_CONFIG)" --status-check $(if $(SKAFFOLD_PROFILE),-p $(SKAFFOLD_PROFILE),)
	@printf "\033[32m✓ Deployment complete\033[0m\n"



.PHONY: undeploy
undeploy: ## Видалити всі сервіси та Helm релізи, які були задеплоєні через Skaffold
	@printf "\033[33m→ Removing Skaffold deployments\033[0m\n"
	@skaffold delete -f "$(SKAFFOLD_CONFIG)" || true
	@printf "\033[32m✓ Deployments removed\033[0m\n"

.PHONY: redeploy
redeploy: undeploy deploy ## Видалити поточний деплоймент та заново задеплоїти всі сервіси (чистий деплой)

# =============================================================================
# Local Infrastructure (Docker Compose)
# =============================================================================

.PHONY: infra-up
infra-up: tools-check ## Запустити локальну інфраструктуру через Docker Compose (MongoDB, Kafka, Storage, Observability stack)
	@printf "\033[36m→ Starting local infrastructure\033[0m\n"
	@docker network inspect "$(DOCKER_NETWORK)" >/dev/null 2>&1 || \
		(printf "  Creating network '$(DOCKER_NETWORK)'\n" && docker network create "$(DOCKER_NETWORK)")
	@printf "  Starting MongoDB...\n"
	@docker compose -f "$(MONGO_COMPOSE)" up -d
	@printf "  Starting Kafka...\n"
	@docker compose -f "$(KAFKA_COMPOSE)" up -d
	@printf "  Starting Storage (MinIO, imgproxy)...\n"
	@docker compose -f "$(STORAGE_COMPOSE)" up -d
	@printf "  Starting Observability stack (Grafana, Prometheus, Tempo)...\n"
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" up -d
	@printf "\033[32m✓ Infrastructure started\033[0m\n"
	@printf "\n\033[36mServices:\033[0m\n"
	@printf "  MongoDB:          mongodb://localhost:27017\n"
	@printf "  Kafka:            localhost:9092\n"
	@printf "  Kafka UI:         http://localhost:9093\n"
	@printf "  Schema Registry:  http://localhost:8084\n"
	@printf "  MinIO API:        http://localhost:9000\n"
	@printf "  MinIO Console:    $(MINIO_CONSOLE_URL) (minioadmin/minioadmin123)\n"
	@printf "  imgproxy:         $(IMGPROXY_URL)\n"
	@printf "  Grafana:          $(GRAFANA_URL) (admin/admin)\n"
	@printf "  Prometheus:       $(PROMETHEUS_URL)\n"
	@printf "  Tempo:            $(TEMPO_URL)\n"
	@printf "\n\033[33m⚠  Note: Services may take a few seconds to become ready\033[0m\n"

.PHONY: infra-down
infra-down: ## Зупинити локальну інфраструктуру (контейнери зупиняються, volumes залишаються)
	@printf "\033[33m→ Stopping local infrastructure\033[0m\n"
	@docker compose -f "$(MONGO_COMPOSE)" down
	@docker compose -f "$(KAFKA_COMPOSE)" down
	@docker compose -f "$(STORAGE_COMPOSE)" down
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" down
	@printf "\033[32m✓ Infrastructure stopped\033[0m\n"

.PHONY: infra-logs
infra-logs: ## Показати логи MongoDB, Kafka, Storage та Observability stack в реальному часі (Ctrl+C для виходу)
	@printf "\033[36m→ Infrastructure logs (Ctrl+C to stop)\033[0m\n"
	@docker compose -f "$(MONGO_COMPOSE)" -f "$(KAFKA_COMPOSE)" -f "$(STORAGE_COMPOSE)" -f "$(OBSERVABILITY_COMPOSE)" logs -f

.PHONY: infra-restart
infra-restart: infra-down infra-up ## Перезапустити локальну інфраструктуру (зупинити та знову запустити з збереженням даних)

.PHONY: infra-clean
infra-clean: infra-down ## Зупинити інфраструктуру та видалити всі Docker volumes (повне очищення баз даних та логів)
	@printf "\033[33m→ Cleaning infrastructure volumes\033[0m\n"
	@docker compose -f "$(MONGO_COMPOSE)" down -v
	@docker compose -f "$(KAFKA_COMPOSE)" down -v
	@docker compose -f "$(STORAGE_COMPOSE)" down -v
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" down -v
	@printf "\033[32m✓ Volumes removed\033[0m\n"

# =============================================================================
# Kubernetes Helpers
# =============================================================================

.PHONY: pods
pods: ## Показати список всіх подів у namespace 'dev' з детальною інформацією (IP, Node, статус)
	@kubectl get pods -n "$(NAMESPACE)" -o wide

.PHONY: pods-all
pods-all: ## Показати список всіх подів у всіх namespace (включаючи системні сервіси)
	@kubectl get pods -A -o wide

.PHONY: services
services: ## Показати список всіх Kubernetes сервісів у namespace 'dev' (ClusterIP, NodePort, LoadBalancer)
	@kubectl get services -n "$(NAMESPACE)"

.PHONY: ingress
ingress: ## Показати список всіх Ingress правил у namespace 'dev' (маршрутизація HTTP/HTTPS трафіку)
	@kubectl get ingress -n "$(NAMESPACE)"

.PHONY: describe
describe: ## Показати детальну інформацію про под (events, статус, ресурси): make describe POD=<pod-name>
ifndef POD
	@printf "\033[31m✗ Usage: make describe POD=<pod-name>\033[0m\n"
	@exit 1
endif
	@if ! kubectl get pod "$(POD)" -n "$(NAMESPACE)" >/dev/null 2>&1; then \
		printf "\033[31m✗ Pod '$(POD)' not found in namespace '$(NAMESPACE)'\033[0m\n"; \
		exit 1; \
	fi
	@kubectl describe pod "$(POD)" -n "$(NAMESPACE)"

.PHONY: logs
logs: ## Показати логи сервісу в реальному часі через stern (всі поди сервісу): make logs SVC=<service-name>
ifndef SVC
	@printf "\033[31m✗ Usage: make logs SVC=<service-name>\033[0m\n"
	@exit 1
endif
	@if ! kubectl get pods -n "$(NAMESPACE)" -l "app.kubernetes.io/name=$(SVC)" 2>/dev/null | grep -q .; then \
		printf "\033[33m⚠ No pods found for service '$(SVC)' in namespace '$(NAMESPACE)'\033[0m\n"; \
		printf "\033[36m  Trying pattern-based search...\033[0m\n"; \
	fi
	@printf "\033[36m→ Tailing logs for '$(SVC)' (Ctrl+C to stop)\033[0m\n"
	@stern "$(SVC)" -n "$(NAMESPACE)"

.PHONY: logs-all
logs-all: ## Показати логи всіх сервісів у namespace 'dev' одночасно (агрегований вивід)
	@printf "\033[36m→ Tailing all logs in '$(NAMESPACE)' (Ctrl+C to stop)\033[0m\n"
	@stern ".*" -n "$(NAMESPACE)"

.PHONY: logs-select
logs-select: ## Інтерактивний вибір сервісу для перегляду логів (меню з доступними сервісами)
	@bash $(THIS_DIR)scripts/monitoring/logs.sh

.PHONY: logs-error
logs-error: ## Фільтрувати логи за рівнем ERROR для сервісу: make logs-error SVC=<service-name>
ifndef SVC
	@printf "\033[31m✗ Usage: make logs-error SVC=<service-name>\033[0m\n"
	@exit 1
endif
	@printf "\033[36m→ Filtering ERROR logs for '$(SVC)' (Ctrl+C to stop)\033[0m\n"
	@stern "$(SVC)" -n "$(NAMESPACE)" --since 1h | grep -i "error"

.PHONY: logs-warn
logs-warn: ## Фільтрувати логи за рівнем WARN для сервісу: make logs-warn SVC=<service-name>
ifndef SVC
	@printf "\033[31m✗ Usage: make logs-warn SVC=<service-name>\033[0m\n"
	@exit 1
endif
	@printf "\033[36m→ Filtering WARN logs for '$(SVC)' (Ctrl+C to stop)\033[0m\n"
	@stern "$(SVC)" -n "$(NAMESPACE)" --since 1h | grep -i "warn"

.PHONY: logs-filter
logs-filter: ## Фільтрувати логи за власним pattern: make logs-filter SVC=<service> PATTERN=<pattern>
ifndef SVC
	@printf "\033[31m✗ Usage: make logs-filter SVC=<service-name> PATTERN=<pattern>\033[0m\n"
	@exit 1
endif
ifndef PATTERN
	@printf "\033[31m✗ Usage: make logs-filter SVC=<service-name> PATTERN=<pattern>\033[0m\n"
	@exit 1
endif
	@printf "\033[36m→ Filtering logs for '$(SVC)' with pattern '$(PATTERN)' (Ctrl+C to stop)\033[0m\n"
	@stern "$(SVC)" -n "$(NAMESPACE)" --since 1h | grep -i "$(PATTERN)"

.PHONY: logs-exclude
logs-exclude: ## Виключити рядки з логів за pattern: make logs-exclude SVC=<service> PATTERN=<pattern>
ifndef SVC
	@printf "\033[31m✗ Usage: make logs-exclude SVC=<service-name> PATTERN=<pattern>\033[0m\n"
	@exit 1
endif
ifndef PATTERN
	@printf "\033[31m✗ Usage: make logs-exclude SVC=<service-name> PATTERN=<pattern>\033[0m\n"
	@exit 1
endif
	@printf "\033[36m→ Excluding '$(PATTERN)' from logs for '$(SVC)' (Ctrl+C to stop)\033[0m\n"
	@stern "$(SVC)" -n "$(NAMESPACE)" --since 1h | grep -v -i "$(PATTERN)"

.PHONY: logs-json
logs-json: ## Показати логи у JSON форматі з фільтруванням: make logs-json SVC=<service> [FIELD=<field>]
ifndef SVC
	@printf "\033[31m✗ Usage: make logs-json SVC=<service-name> [FIELD=<field>]\033[0m\n"
	@exit 1
endif
	@printf "\033[36m→ JSON logs for '$(SVC)' (Ctrl+C to stop)\033[0m\n"
	@if [ -n "$(FIELD)" ]; then \
		stern "$(SVC)" -n "$(NAMESPACE)" --since 1h --output json | jq -r '.message | fromjson | .$(FIELD)' 2>/dev/null || stern "$(SVC)" -n "$(NAMESPACE)" --since 1h; \
	else \
		stern "$(SVC)" -n "$(NAMESPACE)" --since 1h --output json | jq; \
	fi

.PHONY: logs-tail
logs-tail: ## Показати останні N рядків логів: make logs-tail SVC=<service> [LINES=100]
ifndef SVC
	@printf "\033[31m✗ Usage: make logs-tail SVC=<service-name> [LINES=100]\033[0m\n"
	@exit 1
endif
	@LINES=$${LINES:-100}; \
	printf "\033[36m→ Last $$LINES lines for '$(SVC)'\033[0m\n"; \
	stern "$(SVC)" -n "$(NAMESPACE)" --tail $$LINES --since 1h

.PHONY: exec
exec: ## Підключитися до shell у поді для інтерактивної роботи: make exec POD=<pod-name>
ifndef POD
	@printf "\033[31m✗ Usage: make exec POD=<pod-name>\033[0m\n"
	@exit 1
endif
	@if ! kubectl get pod "$(POD)" -n "$(NAMESPACE)" >/dev/null 2>&1; then \
		printf "\033[31m✗ Pod '$(POD)' not found in namespace '$(NAMESPACE)'\033[0m\n"; \
		exit 1; \
	fi
	@kubectl exec -it "$(POD)" -n "$(NAMESPACE)" -- /bin/sh

.PHONY: restart
restart: ## Перезапустити deployment (rolling restart всіх подів): make restart DEP=<deployment-name>
ifndef DEP
	@printf "\033[31m✗ Usage: make restart DEP=<deployment-name>\033[0m\n"
	@exit 1
endif
	@if ! kubectl get deployment "$(DEP)" -n "$(NAMESPACE)" >/dev/null 2>&1; then \
		printf "\033[31m✗ Deployment '$(DEP)' not found in namespace '$(NAMESPACE)'\033[0m\n"; \
		exit 1; \
	fi
	@printf "\033[36m→ Restarting deployment '$(DEP)'\033[0m\n"
	@kubectl rollout restart deployment/"$(DEP)" -n "$(NAMESPACE)"
	@kubectl rollout status deployment/"$(DEP)" -n "$(NAMESPACE)"
	@printf "\033[32m✓ Deployment restarted\033[0m\n"

.PHONY: events
events: ## Показати останні 20 подій Kubernetes у namespace 'dev' (для діагностики проблем)
	@kubectl get events -n "$(NAMESPACE)" --sort-by='.lastTimestamp' | tail -20

# =============================================================================
# Observability & Port Forwarding
# =============================================================================

.PHONY: grafana
grafana: ## Відкрити Grafana в браузері (docker-compose, http://localhost:3000)
	@printf "\033[36m→ Opening Grafana: $(GRAFANA_URL)\033[0m\n"
	@printf "\033[33m  Login: admin / admin\033[0m\n"
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "$(GRAFANA_URL)" 2>/dev/null || true; \
	elif command -v open >/dev/null 2>&1; then \
		open "$(GRAFANA_URL)" 2>/dev/null || true; \
	fi
	@printf "\033[32m  URL: $(GRAFANA_URL)\033[0m\n"

.PHONY: prometheus
prometheus: ## Відкрити Prometheus в браузері (docker-compose, http://localhost:9090)
	@printf "\033[36m→ Opening Prometheus: $(PROMETHEUS_URL)\033[0m\n"
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "$(PROMETHEUS_URL)" 2>/dev/null || true; \
	elif command -v open >/dev/null 2>&1; then \
		open "$(PROMETHEUS_URL)" 2>/dev/null || true; \
	fi
	@printf "\033[32m  URL: $(PROMETHEUS_URL)\033[0m\n"

.PHONY: loki
loki: ## Показати інформацію про перегляд логів (використовуйте kubectl logs або stern)
	@printf "\033[36mДля перегляду логів використовуйте:\033[0m\n"
	@printf "  \033[32mmake logs SVC=<service-name>\033[0m  - Логи конкретного сервісу\n"
	@printf "  \033[32mmake logs-all\033[0m                  - Всі логи в namespace dev\n"
	@printf "  \033[32mkubectl logs <pod-name> -n dev\033[0m - Логи конкретного pod\n"
	@printf "  \033[32mstern <pattern> -n dev\033[0m         - Логи з фільтром\n"
	@printf "\n\033[33m💡 Loki не використовується в dev середовищі для простоти\033[0m\n"

.PHONY: tempo
tempo: ## Показати Tempo endpoints та інформацію про доступ
	@printf "\033[36mTempo Information:\033[0m\n"
	@printf "  API URL:  $(TEMPO_URL)\n"
	@printf "  Health:   $(TEMPO_URL)/ready\n"
	@printf "  OTLP gRPC: localhost:4317\n"
	@printf "  OTLP HTTP: localhost:4318\n"
	@printf "\n\033[33m  Access through Grafana at $(GRAFANA_URL)\033[0m\n"

.PHONY: observability-status
observability-status: ## Перевірити статус observability стеку (docker-compose)
	@printf "\033[36m→ Observability stack status:\033[0m\n"
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" ps

.PHONY: minio-console
minio-console: ## Відкрити MinIO Console в браузері (docker-compose, http://localhost:9001)
	@printf "\033[36m→ Opening MinIO Console: $(MINIO_CONSOLE_URL)\033[0m\n"
	@printf "\033[33m  Login: minioadmin / minioadmin123\033[0m\n"
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "$(MINIO_CONSOLE_URL)" 2>/dev/null || true; \
	elif command -v open >/dev/null 2>&1; then \
		open "$(MINIO_CONSOLE_URL)" 2>/dev/null || true; \
	fi
	@printf "\033[32m  URL: $(MINIO_CONSOLE_URL)\033[0m\n"

.PHONY: imgproxy-info
imgproxy-info: ## Показати інформацію про imgproxy endpoints та приклад використання
	@printf "\033[36mimgproxy Information:\033[0m\n"
	@printf "  Base URL:  $(IMGPROXY_URL)\n"
	@printf "  Health:    $(IMGPROXY_URL)/health\n"
	@printf "\n\033[33mExample usage:\033[0m\n"
	@printf "  curl $(IMGPROXY_URL)/health\n"
	@printf "  $(IMGPROXY_URL)/insecure/rs:fill:300:200/plain/s3://products/image.jpg\n"

.PHONY: minio
minio: minio-console ## Скорочення для команди 'minio-console'

.PHONY: traefik
traefik: ## Відкрити доступ до Traefik Dashboard через port-forward на http://localhost:9000 (ingress контролер)
	@printf "\033[36m→ Forwarding Traefik Dashboard: http://localhost:9000\033[0m\n"
	@printf "\033[33m  Press Ctrl+C to stop\033[0m\n"
	@kubectl -n "$(TRAEFIK_NS)" port-forward "svc/traefik" 9000:9000

.PHONY: forward-all
forward-all: ## Показати список всіх доступних observability та storage сервісів та їх URLs
	@printf "\033[36mObservability Services (docker-compose):\033[0m\n"
	@printf "  \033[32mmake grafana\033[0m     - Grafana at $(GRAFANA_URL)\n"
	@printf "  \033[32mmake prometheus\033[0m  - Prometheus at $(PROMETHEUS_URL)\n"
	@printf "  \033[32mmake tempo\033[0m       - Tempo info (access via Grafana)\n"
	@printf "\n"
	@printf "\033[36mStorage Services (docker-compose):\033[0m\n"
	@printf "  \033[32mmake minio\033[0m       - MinIO Console at $(MINIO_CONSOLE_URL)\n"
	@printf "  \033[32mmake imgproxy-info\033[0m - imgproxy at $(IMGPROXY_URL)\n"
	@printf "\n"
	@printf "\033[36mOther Services:\033[0m\n"
	@printf "  \033[32mmake traefik\033[0m     - Traefik Dashboard (k8s port-forward)\n"
	@printf "\n"
	@printf "\033[36mLogs:\033[0m\n"
	@printf "  \033[32mmake logs SVC=<name>\033[0m - View service logs (kubectl/stern)\n"

# =============================================================================
# Debug Helpers
# =============================================================================

.PHONY: debug-forward
debug-forward: ## Запустити port-forwarding для всіх debug портів (2345-2349) для підключення дебагера
	@printf "\033[36m→ Starting debug port-forwarding\033[0m\n"
	@printf "  localhost:2345 → ecommerce-product-service\n"
	@printf "  localhost:2346 → ecommerce-category-service\n"
	@printf "  localhost:2347 → ecommerce-product-query-service\n"
	@printf "  localhost:2348 → ecommerce-category-query-service\n"
	@printf "  localhost:2349 → ecommerce-image-service\n"
	@printf "\n\033[33mPress Ctrl+C to stop\033[0m\n\n"
	@bash -c 'trap "exit" INT TERM; \
		kubectl port-forward -n $(NAMESPACE) svc/ecommerce-ecommerce-product-service 2345:2345 & \
		kubectl port-forward -n $(NAMESPACE) svc/ecommerce-ecommerce-category-service 2346:2345 & \
		kubectl port-forward -n $(NAMESPACE) svc/ecommerce-ecommerce-product-query-service 2347:2345 & \
		kubectl port-forward -n $(NAMESPACE) svc/ecommerce-ecommerce-category-query-service 2348:2345 & \
		kubectl port-forward -n $(NAMESPACE) svc/ecommerce-ecommerce-image-service 2349:2345 & \
		wait'

.PHONY: debug-info
debug-info: ## Показати інформацію про порти для підключення дебагера та інструкції по налаштуванню VS Code
	@printf "\033[36mDebug Port Mappings:\033[0m\n"
	@printf "  localhost:2345 → ecommerce-product-service\n"
	@printf "  localhost:2346 → ecommerce-category-service\n"
	@printf "  localhost:2347 → ecommerce-product-query-service\n"
	@printf "  localhost:2348 → ecommerce-category-query-service\n"
	@printf "  localhost:2349 → ecommerce-image-service\n"
	@printf "\n"
	@printf "\033[36mVS Code Debug Configuration:\033[0m\n"
	@printf "  Use 'Attach to K3D' configurations in launch.json\n"
	@printf "\n"
	@printf "\033[36mTo start debugging:\033[0m\n"
	@printf "  \033[1mOption 1 (dev mode with auto-reload):\033[0m\n"
	@printf "    1. Run: \033[32mmake dev\033[0m\n"
	@printf "    2. Wait for services to start\n"
	@printf "    3. In VS Code, select 'Attach to K3D' config and press F5\n"
	@printf "\n"
	@printf "  \033[1mOption 2 (deploy mode without auto-reload):\033[0m\n"
	@printf "    1. Run: \033[32mmake deploy\033[0m\n"
	@printf "    2. Run: \033[32mmake debug-forward\033[0m\n"
	@printf "    3. In VS Code, select 'Attach to K3D' config and press F5\n"

.PHONY: debug-check
debug-check: ## Перевірити доступність debug портів 2345-2349 (чи запущені сервіси в debug режимі)
	@printf "\033[36m→ Checking debug ports...\033[0m\n"
	@for port in 2345 2346 2347 2348 2349; do \
		if timeout 1 bash -c "echo >/dev/tcp/localhost/$$port" 2>/dev/null; then \
			printf "  \033[32m✓ Port $$port\033[0m - accessible\n"; \
		else \
			printf "  \033[31m✗ Port $$port\033[0m - not accessible\n"; \
		fi; \
	done

# =============================================================================
# Development Workflows
# =============================================================================

.PHONY: init
init: tools-check cluster-create infra-up deploy ## Повна ініціалізація середовища: створення кластера, запуск інфраструктури та деплой сервісів
	@echo ""
	@printf "\033[32m✓ Development environment ready!\033[0m\n"
	@echo ""
	@printf "\033[36mNext steps:\033[0m\n"
	@echo "  - Run \033[32mmake dev\033[0m to start development mode (debug-enabled)"
	@echo "  - Run \033[32mmake status\033[0m to check cluster status"
	@echo "  - Run \033[32mmake grafana\033[0m to access observability"
	@echo "  - Run \033[32mmake debug-info\033[0m for debugging instructions"

.PHONY: clean
clean: undeploy infra-clean cluster-delete ## Повне очищення: видалення кластера, інфраструктури та всіх volumes з даними
	@printf "\033[32m✓ Complete cleanup finished\033[0m\n"

.PHONY: reset
reset: clean init ## Повний reset середовища: очищення та повторна ініціалізація з нуля (clean + init)
	@printf "\033[32m✓ Environment reset complete\033[0m\n"

# =============================================================================
# Helm Management
# =============================================================================

.PHONY: helm-list
helm-list: ## Показати список всіх Helm релізів у всіх namespace (назва, статус, версія, chart)
	@helm list -A

.PHONY: helm-status
helm-status: ## Показати детальний статус Helm релізу 'ecommerce' (ресурси, notes, статус деплою)
	@helm status ecommerce -n "$(NAMESPACE)"

.PHONY: helm-values
helm-values: ## Показати user-supplied values (параметри передані при деплої, без дефолтних)
	@helm get values ecommerce -n "$(NAMESPACE)"

.PHONY: helm-values-all
helm-values-all: ## Показати всі values релізу 'ecommerce' (дефолтні + перевизначені, повна конфігурація)
	@helm get values ecommerce -n "$(NAMESPACE)" --all

.PHONY: helm-template
helm-template: ## Показати згенеровані Kubernetes маніфести з Helm шаблонів (без деплою, для перевірки)
	@helm template ecommerce "$(CHART_PATH)"

.PHONY: helm-upgrade
helm-upgrade: ## Вручну оновити Helm chart (upgrade or install якщо не існує) з поточними values
	@printf "\033[36m→ Upgrading Helm release\033[0m\n"
	@helm upgrade --install ecommerce "$(CHART_PATH)" -n "$(NAMESPACE)" --create-namespace --wait --timeout 5m
	@printf "\033[32m✓ Helm release upgraded\033[0m\n"

# =============================================================================
# Quick Commands (Aliases)
# =============================================================================

.PHONY: up
up: cluster-start infra-up ## Швидкий старт: запустити кластер та локальну інфраструктуру (MongoDB, Kafka)

.PHONY: down
down: infra-down cluster-stop ## Швидка зупинка: зупинити інфраструктуру та кластер (дані зберігаються)

.PHONY: ps
ps: pods ## Скорочення для команди 'pods' - список подів у namespace 'dev'

.PHONY: svc
svc: services ## Скорочення для команди 'services' - список сервісів у namespace 'dev'

# =============================================================================
# Monitoring & Health Checks
# =============================================================================

.PHONY: health
health: ## Перевірити здоров'я всіх сервісів (кількість ready/desired реплік у deployments)
	@printf "\033[36m→ Checking service health...\033[0m\n"
	@kubectl get deployments -n "$(NAMESPACE)"

.PHONY: resources
resources: ## Показати використання ресурсів (CPU, Memory) на нодах та в подах namespace 'dev'
	@printf "\033[36m→ Node resource usage:\033[0m\n"
	@kubectl top nodes 2>/dev/null || echo "  \033[33mMetrics not available (metrics-server required)\033[0m"
	@echo ""
	@printf "\033[36m→ Pod resource usage in '$(NAMESPACE)':\033[0m\n"
	@kubectl top pods -n "$(NAMESPACE)" 2>/dev/null || echo "  \033[33mMetrics not available (metrics-server required)\033[0m"

.PHONY: namespaces
namespaces: ## Показати список всіх Kubernetes namespaces у кластері
	@kubectl get namespaces

.PHONY: context
context: ## Показати поточний активний kubectl контекст (на який кластер спрямовані команди)
	@kubectl config current-context

.PHONY: contexts
contexts: ## Показати список всіх доступних kubectl контекстів (різні кластери та namespace)
	@kubectl config get-contexts