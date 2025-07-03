THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
LOKI_VALUES := $(THIS_DIR)values.yaml
NAMESPACE := monitoring

.PHONY: all
all: install

.PHONY: install
install:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update
	helm upgrade --install loki grafana/loki-stack \
		--namespace $(NAMESPACE) \
		-f $(LOKI_VALUES) \
		--set grafana.enabled=true \
		--set promtail.enabled=true

.PHONY: upgrade
upgrade:
	helm upgrade loki grafana/loki-stack \
		--namespace $(NAMESPACE) \
		-f $(LOKI_VALUES) \
		--set grafana.enabled=true \
		--set promtail.enabled=true

.PHONY: uninstall
uninstall:
	helm uninstall loki --namespace $(NAMESPACE)

.PHONY: port-forward
port-forward:
	kubectl port-forward -n monitoring svc/loki-grafana 3000:80