THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

TRAEFIK_VALUES := $(THIS_DIR)values.yaml

.PHONY: all
all: install

.PHONY: install
install:
	kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -
	helm repo add traefik https://helm.traefik.io/traefik
	helm repo update
	helm upgrade --install traefik traefik/traefik --namespace traefik -f $(TRAEFIK_VALUES) --set installCRDs=true

.PHONY: upgrade
upgrade:
	helm upgrade traefik traefik/traefik --namespace traefik -f $(TRAEFIK_VALUES) --set installCRDs=true

.PHONY: uninstall
uninstall:
	helm uninstall traefik --namespace traefik
