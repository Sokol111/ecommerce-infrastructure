THIS_DIR     := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
CHART_PATH   := $(THIS_DIR)

APP_NAME     := ecommerce-go-service
NAMESPACE    := dev
VALUES_FILE  := $(THIS_DIR)/values.yaml
KUBECONFIG   := ~/.k3d/kubeconfig-default.yaml

.PHONY: all
all: update deploy

.PHONY: deploy
deploy:
	helm upgrade --install $(APP_NAME) $(CHART_PATH) \
		-n $(NAMESPACE) \
		--create-namespace \
		-f $(VALUES_FILE) \
		--kubeconfig $(KUBECONFIG)

.PHONY: uninstall
uninstall:
	helm uninstall $(APP_NAME) -n $(NAMESPACE) --kubeconfig $(KUBECONFIG)

.PHONY: lint
lint:
	helm lint $(CHART_PATH)

.PHONY: update
update:
	helm dependency update $(CHART_PATH)