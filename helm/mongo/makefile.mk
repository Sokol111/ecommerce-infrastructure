THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

NAMESPACE := dev
RELEASE := mongo
CHART := bitnami/mongodb
VALUES := $(THIS_DIR)mongo-values.yaml
SERVICE := $(THIS_DIR)service.yaml

MONGO_POD = $(shell kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE) -o jsonpath="{.items[0].metadata.name}")

.PHONY: create-dev-namespace install-mongo install-mongo-svc upgrade-mongo uninstall-mongo status-dev-namespace port-forward-mongo create-mongo-user connect-mongo

create-dev-namespace:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

install-mongo: create-dev-namespace
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	helm install $(RELEASE) $(CHART) -f $(VALUES) --namespace $(NAMESPACE)

install-mongo-svc:
	kubectl apply -f $(SERVICE)

upgrade-mongo:
	helm upgrade $(RELEASE) $(CHART) -f $(VALUES) --namespace $(NAMESPACE)

uninstall-mongo:
	helm uninstall $(RELEASE) --namespace $(NAMESPACE)

status-dev-namespace:
	kubectl get all -n $(NAMESPACE)

port-forward-mongo:
	kubectl port-forward pod/mongo-mongodb-0 27017:27017 -n $(NAMESPACE)
	kubectl port-forward svc/$(RELEASE) 27017:27017 -n $(NAMESPACE)

# Usage: make create-mongo-user DB=mydb USER=myuser PASS=mypass
create-mongo-user:
	@if [ -z "$(DB)" ] || [ -z "$(USER)" ] || [ -z "$(PASS)" ]; then \
		echo "❌ Must set up DB=, USER=, PASS="; \
		exit 1; \
	fi
	@ROOT_PASS=$$(kubectl get secret --namespace $(NAMESPACE) $(RELEASE)-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode); \
	echo "🚀 Creating user '$(USER)' for database '$(DB)'..."; \
	kubectl exec -n $(NAMESPACE) $(MONGO_POD) -- \
		mongo admin -u root -p $$ROOT_PASS --eval "\
			db = db.getSiblingDB('$(DB)'); \
			db.createUser({ user: '$(USER)', pwd: '$(PASS)', roles: [ { role: 'readWrite', db: '$(DB)' } ] }); \
			print('✔ User $(USER) created for DB $(DB)');"

connect-mongo:
	kubectl exec -it $(RELEASE)-0 -n $(NAMESPACE) -- \
	mongosh -u root -p $(kubectl get secret --namespace $(NAMESPACE) $(RELEASE)-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode) \
	--authenticationDatabase admin