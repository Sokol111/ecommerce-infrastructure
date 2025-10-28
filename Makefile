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
	@echo -e "\033[36m→ Checking required tools...\033[0m"
	@missing=0; \
	for tool in k3d kubectl skaffold helm stern docker; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo -e "  \033[31m✗ $$tool\033[0m not found in PATH"; \
			missing=1; \
		else \
			echo -e "  \033[32m✓ $$tool\033[0m"; \
		fi; \
	done; \
	if ! docker compose version >/dev/null 2>&1; then \
		echo -e "  \033[31m✗ docker compose\033[0m not available"; \
		missing=1; \
	else \
		echo -e "  \033[32m✓ docker compose\033[0m"; \
	fi; \
	if [ $$missing -eq 1 ]; then \
		echo -e "\033[31m✗ Some tools are missing\033[0m"; \
		exit 1; \
	fi
	@echo -e "\033[32m✓ All required tools are installed\033[0m"

.PHONY: check-env
check-env: ## Запустити комплексну перевірку середовища розробки (інструменти, конфіги, доступність портів)
	@bash $(THIS_DIR)scripts/check-env.sh

.PHONY: status
status: ## Показати статус кластера, нод, деплойментів та сервісів у namespace 'dev'
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

# =============================================================================
# K3d Cluster Management
# =============================================================================

.PHONY: cluster-create
cluster-create: tools-check ## Створити k3d кластер на основі k3d-cluster.yaml конфігурації з портами та налаштуваннями
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
cluster-delete: ## Повністю видалити k3d кластер разом з контекстом kubectl та всіма даними
	@echo -e "\033[33m→ Deleting cluster '$(CLUSTER_NAME)'\033[0m"
	@k3d cluster delete "$(CLUSTER_NAME)" 2>/dev/null || true
	@kubectl config delete-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-cluster "$(K3D_CONTEXT)" 2>/dev/null || true
	@kubectl config delete-user "admin@$(K3D_CONTEXT)" 2>/dev/null || true
	@echo -e "\033[32m✓ Cluster deleted\033[0m"

.PHONY: cluster-restart
cluster-restart: cluster-stop cluster-start ## Перезапустити k3d кластер (зупинити та знову запустити без видалення даних)

.PHONY: cluster-stop
cluster-stop: ## Зупинити k3d кластер (контейнери зупиняються, але дані зберігаються)
	@echo -e "\033[36m→ Stopping cluster '$(CLUSTER_NAME)'\033[0m"
	@k3d cluster stop "$(CLUSTER_NAME)"
	@echo -e "\033[32m✓ Cluster stopped\033[0m"

.PHONY: cluster-start
cluster-start: ## Запустити зупинений k3d кластер та автоматично переключити kubectl контекст
	@echo -e "\033[36m→ Starting cluster '$(CLUSTER_NAME)'\033[0m"
	@k3d cluster start "$(CLUSTER_NAME)"
	@kubectl config use-context "$(K3D_CONTEXT)" 2>/dev/null || true
	@echo -e "\033[32m✓ Cluster started\033[0m"

.PHONY: cluster-reset
cluster-reset: cluster-delete cluster-create ## Повністю видалити та заново створити кластер (очищення всіх даних та стану)
	@echo -e "\033[32m✓ Cluster reset complete\033[0m"

# =============================================================================
# Skaffold Deployment
# =============================================================================

.PHONY: dev
dev: cluster-create ## Запустити режим розробки з автоматичною пересборкою, деплоєм та показом логів при змінах коду
	@echo -e "\033[36m→ Starting Skaffold dev mode\033[0m"
	@skaffold dev -f "$(SKAFFOLD_CONFIG)" $(if $(SKAFFOLD_PROFILE),-p $(SKAFFOLD_PROFILE),)

.PHONY: dev-debug
dev-debug: cluster-create ## Запустити режим розробки з підтримкою дебагу через Delve (порти 2345-2349 для різних сервісів)
	@echo -e "\033[36m→ Starting Skaffold dev mode with DEBUG profile\033[0m"
	@echo -e "\033[33m  Debug ports: 2345-2349 (product, category, product-query, category-query, image)\033[0m"
	@skaffold dev -f "$(SKAFFOLD_CONFIG)" -p debug

.PHONY: build
build: cluster-create ## Побудувати Docker образи для всіх сервісів без деплою в кластер
	@echo -e "\033[36m→ Building images\033[0m"
	@skaffold build -f "$(SKAFFOLD_CONFIG)"

.PHONY: deploy
deploy: cluster-create ## Одноразовий деплой всіх сервісів в кластер через Skaffold та Helm
	@echo -e "\033[36m→ Deploying to cluster\033[0m"
	@skaffold run -f "$(SKAFFOLD_CONFIG)" --status-check $(if $(SKAFFOLD_PROFILE),-p $(SKAFFOLD_PROFILE),)
	@echo -e "\033[32m✓ Deployment complete\033[0m"

.PHONY: deploy-debug
deploy-debug: cluster-create ## Одноразовий деплой з активованим режимом дебагу (Delve debugger у всіх сервісах)
	@echo -e "\033[36m→ Deploying in DEBUG mode\033[0m"
	@skaffold run -f "$(SKAFFOLD_CONFIG)" -p debug --status-check
	@echo -e "\033[32m✓ Debug deployment complete\033[0m"

.PHONY: undeploy
undeploy: ## Видалити всі сервіси та Helm релізи, які були задеплоєні через Skaffold
	@echo -e "\033[33m→ Removing Skaffold deployments\033[0m"
	@skaffold delete -f "$(SKAFFOLD_CONFIG)" || true
	@echo -e "\033[32m✓ Deployments removed\033[0m"

.PHONY: redeploy
redeploy: undeploy deploy ## Видалити поточний деплоймент та заново задеплоїти всі сервіси (чистий деплой)

# =============================================================================
# Local Infrastructure (Docker Compose)
# =============================================================================

.PHONY: infra-up
infra-up: tools-check ## Запустити локальну інфраструктуру через Docker Compose (MongoDB на :27017, Kafka на :9092)
	@echo -e "\033[36m→ Starting local infrastructure\033[0m"
	@docker network inspect "$(DOCKER_NETWORK)" >/dev/null 2>&1 || \
		(echo "  Creating network '$(DOCKER_NETWORK)'" && docker network create "$(DOCKER_NETWORK)")
	@docker compose -f "$(MONGO_COMPOSE)" up -d
	@docker compose -f "$(KAFKA_COMPOSE)" up -d
	@echo -e "\033[32m✓ Infrastructure started\033[0m"
	@echo "  MongoDB: mongodb://localhost:27017"
	@echo "  Kafka: localhost:9092"

.PHONY: infra-down
infra-down: ## Зупинити локальну інфраструктуру (контейнери зупиняються, volumes залишаються)
	@echo -e "\033[33m→ Stopping local infrastructure\033[0m"
	@docker compose -f "$(MONGO_COMPOSE)" down
	@docker compose -f "$(KAFKA_COMPOSE)" down
	@echo -e "\033[32m✓ Infrastructure stopped\033[0m"

.PHONY: infra-logs
infra-logs: ## Показати логи MongoDB та Kafka в реальному часі (Ctrl+C для виходу)
	@echo -e "\033[36m→ Infrastructure logs (Ctrl+C to stop)\033[0m"
	@docker compose -f "$(MONGO_COMPOSE)" -f "$(KAFKA_COMPOSE)" logs -f

.PHONY: infra-restart
infra-restart: infra-down infra-up ## Перезапустити локальну інфраструктуру (зупинити та знову запустити з збереженням даних)

.PHONY: infra-clean
infra-clean: infra-down ## Зупинити інфраструктуру та видалити всі Docker volumes (повне очищення баз даних)
	@echo -e "\033[33m→ Cleaning infrastructure volumes\033[0m"
	@docker compose -f "$(MONGO_COMPOSE)" down -v
	@docker compose -f "$(KAFKA_COMPOSE)" down -v
	@echo -e "\033[32m✓ Volumes removed\033[0m"

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
	@echo -e "\033[31m✗ Usage: make describe POD=<pod-name>\033[0m"
	@exit 1
endif
	@kubectl describe pod "$(POD)" -n "$(NAMESPACE)"

.PHONY: logs
logs: ## Показати логи сервісу в реальному часі через stern (всі поди сервісу): make logs SVC=<service-name>
ifndef SVC
	@echo -e "\033[31m✗ Usage: make logs SVC=<service-name>\033[0m"
	@exit 1
endif
	@echo -e "\033[36m→ Tailing logs for '$(SVC)' (Ctrl+C to stop)\033[0m"
	@stern "$(SVC)" -n "$(NAMESPACE)"

.PHONY: logs-all
logs-all: ## Показати логи всіх сервісів у namespace 'dev' одночасно (агрегований вивід)
	@echo -e "\033[36m→ Tailing all logs in '$(NAMESPACE)' (Ctrl+C to stop)\033[0m"
	@stern ".*" -n "$(NAMESPACE)"

.PHONY: logs-select
logs-select: ## Інтерактивний вибір сервісу для перегляду логів (меню з доступними сервісами)
	@bash $(THIS_DIR)scripts/logs.sh

.PHONY: exec
exec: ## Підключитися до shell у поді для інтерактивної роботи: make exec POD=<pod-name>
ifndef POD
	@echo -e "\033[31m✗ Usage: make exec POD=<pod-name>\033[0m"
	@exit 1
endif
	@kubectl exec -it "$(POD)" -n "$(NAMESPACE)" -- /bin/sh

.PHONY: restart
restart: ## Перезапустити deployment (rolling restart всіх подів): make restart DEP=<deployment-name>
ifndef DEP
	@echo -e "\033[31m✗ Usage: make restart DEP=<deployment-name>\033[0m"
	@exit 1
endif
	@echo -e "\033[36m→ Restarting deployment '$(DEP)'\033[0m"
	@kubectl rollout restart deployment/"$(DEP)" -n "$(NAMESPACE)"
	@kubectl rollout status deployment/"$(DEP)" -n "$(NAMESPACE)"
	@echo -e "\033[32m✓ Deployment restarted\033[0m"

.PHONY: events
events: ## Показати останні 20 подій Kubernetes у namespace 'dev' (для діагностики проблем)
	@kubectl get events -n "$(NAMESPACE)" --sort-by='.lastTimestamp' | tail -20

# =============================================================================
# Observability & Port Forwarding
# =============================================================================

.PHONY: grafana
grafana: ## Відкрити доступ до Grafana через port-forward на http://localhost:3000 (метрики та дашборди)
	@echo -e "\033[36m→ Forwarding Grafana: http://localhost:$(GRAFANA_LOCAL_PORT)\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(OBS_NS)" port-forward "svc/$(GRAFANA_SVC)" "$(GRAFANA_LOCAL_PORT):$(GRAFANA_SVC_PORT)"

.PHONY: prometheus
prometheus: ## Відкрити доступ до Prometheus через port-forward на http://localhost:9090 (збір та запити метрик)
	@echo -e "\033[36m→ Forwarding Prometheus: http://localhost:9090\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(OBS_NS)" port-forward "svc/prometheus-server" 9090:80

.PHONY: minio
minio: ## Відкрити доступ до MinIO Console через port-forward на http://localhost:9001 (S3 сховище)
	@echo -e "\033[36m→ Forwarding MinIO Console: http://localhost:9001\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(MINIO_NS)" port-forward "svc/minio-console" 9001:9001

.PHONY: traefik
traefik: ## Відкрити доступ до Traefik Dashboard через port-forward на http://localhost:9000 (ingress контролер)
	@echo -e "\033[36m→ Forwarding Traefik Dashboard: http://localhost:9000\033[0m"
	@echo -e "\033[33m  Press Ctrl+C to stop\033[0m"
	@kubectl -n "$(TRAEFIK_NS)" port-forward "svc/traefik" 9000:9000

.PHONY: forward-all
forward-all: ## Показати список всіх доступних port-forward команд для observability сервісів
	@echo -e "\033[36mAvailable port forwards:\033[0m"
	@echo "  \033[32mmake grafana\033[0m     - Grafana at http://localhost:3000"
	@echo "  \033[32mmake prometheus\033[0m  - Prometheus at http://localhost:9090"
	@echo "  \033[32mmake minio\033[0m       - MinIO Console at http://localhost:9001"
	@echo "  \033[32mmake traefik\033[0m     - Traefik Dashboard at http://localhost:9000"
	@echo ""
	@echo -e "\033[33mRun each in a separate terminal\033[0m"

# =============================================================================
# Debug Helpers
# =============================================================================

.PHONY: debug-info
debug-info: ## Показати інформацію про порти для підключення дебагера та інструкції по налаштуванню VS Code
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
debug-check: ## Перевірити доступність debug портів 2345-2349 (чи запущені сервіси в debug режимі)
	@echo -e "\033[36m→ Checking debug ports...\033[0m"
	@for port in 2345 2346 2347 2348 2349; do \
		if nc -z localhost $$port 2>/dev/null; then \
			echo "  \033[32m✓ Port $$port\033[0m - accessible"; \
		else \
			echo "  \033[31m✗ Port $$port\033[0m - not accessible"; \
		fi; \
	done

# =============================================================================
# Development Workflows
# =============================================================================

.PHONY: init
init: tools-check cluster-create infra-up deploy ## Повна ініціалізація середовища: створення кластера, запуск інфраструктури та деплой сервісів
	@echo ""
	@echo -e "\033[32m✓ Development environment ready!\033[0m"
	@echo ""
	@echo -e "\033[36mNext steps:\033[0m"
	@echo "  - Run \033[32mmake dev\033[0m to start development mode"
	@echo "  - Run \033[32mmake dev-debug\033[0m for debugging"
	@echo "  - Run \033[32mmake status\033[0m to check cluster status"
	@echo "  - Run \033[32mmake grafana\033[0m to access observability"

.PHONY: clean
clean: undeploy infra-clean cluster-delete ## Повне очищення: видалення кластера, інфраструктури та всіх volumes з даними
	@echo -e "\033[32m✓ Complete cleanup finished\033[0m"

.PHONY: reset
reset: clean init ## Повний reset середовища: очищення та повторна ініціалізація з нуля (clean + init)
	@echo -e "\033[32m✓ Environment reset complete\033[0m"

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
	@echo -e "\033[36m→ Upgrading Helm release\033[0m"
	@helm upgrade --install ecommerce "$(CHART_PATH)" -n "$(NAMESPACE)" --create-namespace
	@echo -e "\033[32m✓ Helm release upgraded\033[0m"

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
	@echo -e "\033[36m→ Checking service health...\033[0m"
	@kubectl get deployments -n "$(NAMESPACE)"

.PHONY: resources
resources: ## Показати використання ресурсів (CPU, Memory) на нодах та в подах namespace 'dev'
	@echo -e "\033[36m→ Node resource usage:\033[0m"
	@kubectl top nodes 2>/dev/null || echo "  \033[33mMetrics not available (metrics-server required)\033[0m"
	@echo ""
	@echo -e "\033[36m→ Pod resource usage in '$(NAMESPACE)':\033[0m"
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