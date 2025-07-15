THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
K3D_CONFIG := $(THIS_DIR)k3d-cluster.yaml
CLUSTER_NAME=dev-cluster

.PHONY: all
all: create-k3d

.PHONY: clean
clean: delete-k3d

.PHONY: create-k3d
create-k3d:
	@if k3d cluster list | grep -q '^$(CLUSTER_NAME)\s'; then \
		echo "Cluster '$(CLUSTER_NAME)' already exists. Skipping creation."; \
	else \
		k3d cluster create --config $(K3D_CONFIG); \
	fi

.PHONY: delete-k3d
delete-k3d:
	k3d cluster delete $(CLUSTER_NAME)
	kubectl config delete-context k3d-$(CLUSTER_NAME) || true
	kubectl config unset users.k3d-$(CLUSTER_NAME) || true
	kubectl config unset clusters.k3d-$(CLUSTER_NAME) || true

.PHONY: status-k3d
status-k3d:
	kubectl get nodes

.PHONY: logs-k3d
logs-k3d:
	k3d cluster list

.PHONY: stop-k3d
stop-k3d:
	k3d cluster stop $(CLUSTER_NAME)

.PHONY: start-k3d
start-k3d:
	k3d cluster start $(CLUSTER_NAME)