export PACKAGE_NAME VERSION PROJECT_NAME AUTHOR REPOSITORY_URL

REQUIRED_VARS := PACKAGE_NAME VERSION PROJECT_NAME AUTHOR REPOSITORY_URL

OPENAPI_FILE := openapi/openapi.yml
GEN_DIR := js-client
VERSION_NO_V := $(VERSION:v%=%)
TEMPLATE_DIR := templates

PACKAGE_JSON_TEMPLATE_URL:=https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/templates/package.json.template
PACKAGE_JSON_TEMPLATE_LOCAL_PATH:=$(TEMPLATE_DIR)/package.json.template

TSCONFIG_TEMPLATE_URL:=https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/templates/tsconfig.json.template
TSCONFIG_TEMPLATE_LOCAL_PATH:=$(TEMPLATE_DIR)/tsconfig.json.template

.PHONY: check-vars print-vars install-tools create-gen-dir js-generate js-package js-tsconfig js-build generate-js-api clean

check-vars:
	@missing=""; \
	for var in $(REQUIRED_VARS); do \
		if [ -z "$${!var}" ]; then \
			echo "❌ ERROR: $$var is not set"; \
			missing=1; \
		fi; \
	done; \
	if [ "$$missing" = "1" ]; then \
		echo "💡 Tip: you can set variables via environment"; \
		exit 1; \
	fi

print-vars:
	@echo "📦 PACKAGE_NAME      = $(PACKAGE_NAME)"
	@echo "🧪 VERSION           = $(VERSION)"
	@echo "🔢 VERSION_NO_V      = $(VERSION_NO_V)"
	@echo "📁 PROJECT_NAME      = $(PROJECT_NAME)"
	@echo "👤 AUTHOR            = $(AUTHOR)"
	@echo "🌐 REPOSITORY_URL    = $(REPOSITORY_URL)"

install-tools:
	@which openapi-generator-cli >/dev/null || (echo "Installing openapi-generator-cli..."; \
		npm install -g @openapitools/openapi-generator-cli@2.20.2)
	@which envsub >/dev/null || (echo "Installing envsub..."; \
		npm install -g envsub@4.1.0)

create-gen-dir:
	@mkdir -p $(GEN_DIR)

js-generate: install-tools create-gen-dir
	@echo "Generating JS client..."
	openapi-generator-cli generate \
		-i $(OPENAPI_FILE) \
		-g typescript-axios \
		-o $(GEN_DIR) \
		--additional-properties=useSingleRequestParameter=true

js-package: install-tools create-gen-dir
	@echo "Downloading package.json.template from GitHub..."
	curl -sSfL $(PACKAGE_JSON_TEMPLATE_URL) -o $(PACKAGE_JSON_TEMPLATE_LOCAL_PATH) || { echo "Failed to download package.json.template"; exit 1; }

	@echo "Generating package.json..."
	envsub $(PACKAGE_JSON_TEMPLATE_LOCAL_PATH) $(GEN_DIR)/package.json

js-tsconfig: install-tools
	@echo "Downloading tsconfig.json.template from GitHub..."
	curl -sSfL $(TSCONFIG_TEMPLATE_URL) -o $(TSCONFIG_TEMPLATE_LOCAL_PATH) || { echo "Failed to download tsconfig.json.template"; exit 1; }

	@echo "Generating tsconfig.json..."
	cp $(TSCONFIG_TEMPLATE_LOCAL_PATH) $(GEN_DIR)/tsconfig.json

js-build: install-tools
	@echo "Installing JS dependencies and building JS package..."
	cd $(GEN_DIR) && npm install && npm run build
	@echo "JS client is ready"
	@echo "Generated package.json:"
	@cat $(GEN_DIR)/package.json

generate-js-api: check-vars print-vars clean js-generate js-package js-tsconfig js-build
	@echo "JS API generated successfully."

clean:
	@echo "Cleaning JS client files..."
	@rm -rf $(GEN_DIR)