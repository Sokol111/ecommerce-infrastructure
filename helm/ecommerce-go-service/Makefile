THIS_DIR       := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
CHART_PATH     := $(THIS_DIR)

APP_NAME       := ecommerce-go-service
NAMESPACE      := dev
VALUES_FILE    := $(THIS_DIR)values.yaml

HOST_IP        := 127.0.0.1
HOSTS_FILE     := /etc/hosts
TEMPLATE_FILE  := $(CHART_PATH)rendered.yaml

.PHONY: all
all: update deploy add-hosts

.PHONY: deploy
deploy:
	helm upgrade --install $(APP_NAME) $(CHART_PATH) \
		-n $(NAMESPACE) \
		--create-namespace \
		-f $(VALUES_FILE)

.PHONY: uninstall
uninstall:
	helm uninstall $(APP_NAME) -n $(NAMESPACE)

.PHONY: lint
lint:
	helm lint $(CHART_PATH)

.PHONY: update
update:
	helm dependency update $(CHART_PATH)

.PHONY: render
render:
	helm template $(APP_NAME) $(CHART_PATH) \
		-n $(NAMESPACE) \
		-f $(VALUES_FILE) > $(TEMPLATE_FILE)

.PHONY: add-hosts
add-hosts:
	@echo "⏳ Rendering Helm templates to $(TEMPLATE_FILE)..."
	@helm template $(APP_NAME) $(CHART_PATH) -f $(VALUES_FILE) > $(TEMPLATE_FILE)

	@echo "🔍 Found Ingress hosts:"
	@grep -E '[ -]+host:' $(TEMPLATE_FILE) \
	| sed -E 's/.*host:[[:space:]]*"?([^"]+)"?/\1/' \
	| grep -v '^#' | grep -v '^$$' \
	| sort -u \
	| tee /tmp/_hosts_to_add.txt

	@echo "🛠️  Adding DNS names to /etc/hosts if missing..."
	@cat /tmp/_hosts_to_add.txt | while read host; do \
		if ! grep -q "$$host" $(HOSTS_FILE); then \
			echo "$(HOST_IP) $$host" | sudo tee -a $(HOSTS_FILE) > /dev/null; \
			echo "✅ Added: $$host"; \
		else \
			echo "🔁 Already exists: $$host"; \
		fi; \
	done