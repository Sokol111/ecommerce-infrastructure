THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
K3D_CONFIG := $(THIS_DIR)k3d-cluster.yaml
CLUSTER_NAME=dev-cluster

.PHONY: create-k3d delete-k3d status-k3d logs-k3d

create-k3d:
	k3d cluster create --config $(K3D_CONFIG)

delete-k3d:
	k3d cluster delete $(CLUSTER_NAME)

status-k3d:
	kubectl get nodes

logs-k3d:
	k3d cluster list
