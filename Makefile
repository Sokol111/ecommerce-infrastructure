# ---- Config ----
SHELL := /bin/sh
.SHELLFLAGS := -eu -c
.ONESHELL:

THIS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# K3d
K3D_CONFIG ?= $(THIS_DIR)k3d-cluster.yaml
CLUSTER_NAME ?= dev-cluster
K3D_CONTEXT := k3d-$(CLUSTER_NAME)

# Skaffold
SKAFFOLD_CONFIG ?= $(THIS_DIR)skaffold.yaml

NAMESPACE ?= dev

# Umbrella chart
CHART_PATH ?= $(THIS_DIR)helm/ecommerce-go-service

# Docker compose
COMPOSE_DIR := $(THIS_DIR)docker/docker-compose
MONGO_COMPOSE := $(COMPOSE_DIR)/mongo.yml
KAFKA_COMPOSE := $(COMPOSE_DIR)/kafka.yml
DOCKER_NETWORK := shared-network

OBS_NS ?= observability
GRAFANA_SVC ?= grafana
GRAFANA_LOCAL_PORT ?= 3000
GRAFANA_SVC_PORT ?= 80

.DEFAULT_GOAL := help

# ---- Utils ----
.PHONY: help
help: ## List available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(lastword $(MAKEFILE_LIST)) | sort \
	| awk 'BEGIN {FS=":.*?## "}; {printf "\033[36m%-26s\033[0m %s\n", $$1, $$2}'

.PHONY: tools-check
tools-check: ## Verify required CLIs are installed (k3d, kubectl, skaffold, helm, stern, curl, docker)
	@for t in k3d kubectl skaffold helm stern curl docker; do \
	  command -v $$t >/dev/null || { echo "✗ $$t not found in $$PATH"; exit 1; }; \
	done

# ---- K3d ----
.PHONY: k3d-cluster-create
k3d-cluster-create: tools-check ## Create k3d cluster (from config)
	if [ ! -f "$(K3D_CONFIG)" ]; then
		echo "✗ Missing file: $(K3D_CONFIG)"; exit 1;
	fi
	if k3d cluster list -o json | grep -q "\"name\":\"$(CLUSTER_NAME)\""; then
		echo "✓ Cluster '$(CLUSTER_NAME)' already exists — skipping";
	else
		echo "→ Creating cluster '$(CLUSTER_NAME)' from $(K3D_CONFIG)";
		k3d cluster create --config "$(K3D_CONFIG)";
	fi
	kubectl config use-context "$(K3D_CONTEXT)" >/dev/null 2>&1 || true

.PHONY: k3d-cluster-delete
k3d-cluster-delete: tools-check ## Delete k3d cluster and kubeconfig entries
	echo "→ Deleting cluster '$(CLUSTER_NAME)'"
	k3d cluster delete "$(CLUSTER_NAME)" || true
	k3d kubeconfig delete "$(CLUSTER_NAME)" >/dev/null 2>&1 || true
	kubectl config delete-context "$(K3D_CONTEXT)" >/dev/null 2>&1 || true
	kubectl config delete-cluster "$(K3D_CONTEXT)" >/dev/null 2>&1 || true
	kubectl config delete-user "admin@$(K3D_CONTEXT)" >/dev/null 2>&1 || true
	echo "✓ Deleted"

.PHONY: k3d-cluster-nodes
k3d-cluster-nodes: tools-check ## Show k3d cluster nodes
	kubectl get nodes -o wide

.PHONY: k3d-cluster-stop
k3d-cluster-stop: tools-check ## Stop k3d cluster
	k3d cluster stop "$(CLUSTER_NAME)"

.PHONY: k3d-cluster-start
k3d-cluster-start: tools-check ## Start k3d cluster
	k3d cluster start "$(CLUSTER_NAME)"

# ---- Skaffold ----
.PHONY: skaffold-build
skaffold-build: k3d-cluster-create ## Build & push images (no deploy)
	skaffold build -f "$(SKAFFOLD_CONFIG)"

.PHONY: skaffold-dev
skaffold-dev: k3d-cluster-create ## Dev loop (rebuild/deploy/logs)
	skaffold dev -f "$(SKAFFOLD_CONFIG)"

.PHONY: skaffold-deploy
skaffold-deploy: k3d-cluster-create ## One-off deploy
	skaffold run -f "$(SKAFFOLD_CONFIG)"

.PHONY: skaffold-undeploy
skaffold-undeploy: ## Delete releases created by skaffold
	skaffold delete -f "$(SKAFFOLD_CONFIG)"

# ---- Local infra (Docker) ----
.PHONY: local-infra-up
local-infra-up: tools-check ## Start local infra (Mongo + Kafka)
	docker network inspect "$(DOCKER_NETWORK)" >/dev/null 2>&1 || docker network create "$(DOCKER_NETWORK)"
	docker compose -f "$(MONGO_COMPOSE)" up -d
	docker compose -f "$(KAFKA_COMPOSE)" up -d

.PHONY: local-infra-down
local-infra-down: tools-check ## Stop local infra (Mongo + Kafka)
	docker compose -f "$(MONGO_COMPOSE)" down
	docker compose -f "$(KAFKA_COMPOSE)" down

# ---- Kubectl helpers ----
.PHONY: k8s-pods
k8s-pods: tools-check ## List pods in namespace
	kubectl get pods -n "$(NAMESPACE)"

.PHONY: k8s-pod-describe
k8s-pod-describe: tools-check ## Describe a pod: make k8s-pod-describe POD=<pod-name>
ifndef POD
	$(error You must specify POD=<pod-name>)
endif
	kubectl describe pod "$(POD)" -n "$(NAMESPACE)"

.PHONY: k8s-logs-tail
k8s-logs-tail: tools-check ## Tail logs by pattern: make k8s-logs-tail SERVICE=<partial-pod-name>
ifndef SERVICE
	$(error You must specify SERVICE=<partial-pod-name>)
endif
	stern "$(SERVICE)" -n "$(NAMESPACE)"

.PHONY: k8s-port-forward-grafana
k8s-port-forward-grafana: tools-check ## Port-forward Grafana to http://localhost:3001 (Ctrl+C to stop)
	@echo "→ Forwarding http://localhost:$(GRAFANA_LOCAL_PORT) → svc/$(GRAFANA_SVC):$(GRAFANA_SVC_PORT) in $(OBS_NS) (Ctrl+C to stop)"
	exec kubectl -n "$(OBS_NS)" port-forward "svc/$(GRAFANA_SVC)" "$(GRAFANA_LOCAL_PORT):$(GRAFANA_SVC_PORT)"