THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
K3D_CONFIG := $(THIS_DIR)k3d-cluster.yaml
CLUSTER_NAME=dev-cluster

.PHONY: all
all: create-k3d

.PHONY: create-k3d
create-k3d:
	k3d cluster create --config $(K3D_CONFIG)

.PHONY: delete-k3d
delete-k3d:
	k3d cluster delete $(CLUSTER_NAME)
	kubectl config delete-context k3d-$(CLUSTER_NAME)

.PHONY: status-k3d
status-k3d:
	kubectl get nodes

.PHONY: logs-k3d
logs-k3d:
	k3d cluster list
