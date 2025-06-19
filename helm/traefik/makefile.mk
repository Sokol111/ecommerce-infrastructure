THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

TRAEFIK_VALUES := $(THIS_DIR)traefik-values.yaml
TRAEFIK_INGRESS := $(THIS_DIR)traefik-ingress.yaml

.PHONY: install-traefik upgrade-traefik uninstall-traefik apply-ingress

install-traefik:
	kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -
	helm repo add traefik https://helm.traefik.io/traefik
	helm repo update
	helm install traefik traefik/traefik --namespace traefik -f $(TRAEFIK_VALUES) --set installCRDs=true

upgrade-traefik:
	helm upgrade traefik traefik/traefik --namespace traefik -f $(TRAEFIK_VALUES) --set installCRDs=true

uninstall-traefik:
	helm uninstall traefik --namespace traefik

apply-ingress:
	kubectl apply -f $(TRAEFIK_INGRESS)
