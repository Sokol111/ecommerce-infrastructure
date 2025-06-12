export JS_GEN_DIR OPENAPI_FILE NPM_PACKAGE_NAME VERSION PROJECT_NAME AUTHOR REPOSITORY_URL

REQUIRED_VARS := JS_GEN_DIR OPENAPI_FILE NPM_PACKAGE_NAME VERSION PROJECT_NAME AUTHOR REPOSITORY_URL

VERSION_NO_V := $(VERSION:v%=%)

TEMPLATES_URL:=https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/templates/

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
	@echo "JS_GEN_DIR        = $(JS_GEN_DIR)"
	@echo "OPENAPI_FILE      = $(OPENAPI_FILE)"
	@echo "NPM_PACKAGE_NAME  = $(NPM_PACKAGE_NAME)"
	@echo "VERSION           = $(VERSION)"
	@echo "VERSION_NO_V      = $(VERSION_NO_V)"
	@echo "PROJECT_NAME      = $(PROJECT_NAME)"
	@echo "AUTHOR            = $(AUTHOR)"
	@echo "REPOSITORY_URL	 = $(REPOSITORY_URL)"

install-tools:
	@which openapi-generator-cli >/dev/null || (echo "Installing openapi-generator-cli..."; \
		npm install -g @openapitools/openapi-generator-cli@2.20.2)
	@which envsub >/dev/null || (echo "Installing envsub..."; \
		npm install -g envsub@4.1.0)

create-gen-dir:
	@mkdir -p $(JS_GEN_DIR)

js-generate: install-tools create-gen-dir
	@echo "Generating JS client..."
	openapi-generator-cli generate \
		-i $(OPENAPI_FILE) \
		-g typescript-axios \
		-o $(JS_GEN_DIR) \
		--additional-properties=useSingleRequestParameter=true

js-package: install-tools create-gen-dir
	@echo "Downloading package.json.template from GitHub..."
	curl -sSfL $(TEMPLATES_URL)package.json.template -o package.json.template || { echo "Failed to download package.json.template"; exit 1; }

	@echo "Generating package.json..."
	envsub package.json.template $(JS_GEN_DIR)/package.json

js-tsconfig: install-tools
	@echo "Downloading tsconfig.json from GitHub..."
	curl -sSfL $(TEMPLATES_URL)tsconfig.json.template -o $(JS_GEN_DIR)/tsconfig.json || { echo "Failed to download tsconfig.json"; exit 1; }

js-build: install-tools
	@echo "Installing JS dependencies and building JS package..."
	cd $(JS_GEN_DIR) && npm install && npm run build
	@echo "JS client is ready"
	@echo "Generated package.json:"
	@cat $(JS_GEN_DIR)/package.json

generate-js-api: check-vars print-vars clean js-generate js-package js-tsconfig js-build
	@echo "JS API generated successfully."

clean:
	@echo "Cleaning JS client files..."
	@rm -rf $(JS_GEN_DIR)