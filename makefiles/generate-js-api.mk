export JS_GEN_DIR OPENAPI_FILE NPM_PACKAGE_NAME VERSION PROJECT_NAME AUTHOR REPOSITORY_URL

REQUIRED_VARS := JS_GEN_DIR OPENAPI_FILE NPM_PACKAGE_NAME VERSION PROJECT_NAME AUTHOR REPOSITORY_URL

VERSION_NO_V := $(VERSION:v%=%)

TEMPLATES_URL:=https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/templates/

.PHONY: check-js-vars print-js-vars create-js-gen-dir js-generate js-package js-tsconfig js-build generate-js-api clean-js

check-js-vars:
	@bash -c '\
	missing=""; \
	for var in $(REQUIRED_VARS); do \
		if [ -z "$${!var}" ]; then \
			echo "❌ ERROR: $$var is not set"; \
			missing=1; \
		fi; \
	done; \
	if [ "$$missing" = "1" ]; then \
		echo "💡 Tip: you can set variables via environment"; \
		exit 1; \
	fi'

print-js-vars:
	@echo "JS_GEN_DIR        = $(JS_GEN_DIR)"
	@echo "OPENAPI_FILE      = $(OPENAPI_FILE)"
	@echo "NPM_PACKAGE_NAME  = $(NPM_PACKAGE_NAME)"
	@echo "VERSION           = $(VERSION)"
	@echo "VERSION_NO_V      = $(VERSION_NO_V)"
	@echo "PROJECT_NAME      = $(PROJECT_NAME)"
	@echo "AUTHOR            = $(AUTHOR)"
	@echo "REPOSITORY_URL	 = $(REPOSITORY_URL)"

create-js-gen-dir:
	@mkdir -p $(JS_GEN_DIR)

js-generate: create-js-gen-dir
	@echo "Generating JS client..."
	npx @openapitools/openapi-generator-cli@2.20.2 generate \
		-i $(OPENAPI_FILE) \
		-g typescript-axios \
		-o $(JS_GEN_DIR) \
		--additional-properties=useSingleRequestParameter=true

js-package: create-js-gen-dir
	@echo "Downloading package.json.template from GitHub..."
	curl -sSfL $(TEMPLATES_URL)package.json.template -o package.json.template || { echo "Failed to download package.json.template"; exit 1; }

	@echo "Generating package.json..."
	npx envsub@4.1.0 package.json.template $(JS_GEN_DIR)/package.json

js-tsconfig:
	@echo "Downloading tsconfig.json from GitHub..."
	curl -sSfL $(TEMPLATES_URL)tsconfig.json.template -o $(JS_GEN_DIR)/tsconfig.json || { echo "Failed to download tsconfig.json"; exit 1; }

js-build:
	@echo "Installing JS dependencies and building JS package..."
	cd $(JS_GEN_DIR) && npm install && npm run build
	@echo "JS client is ready"
	@echo "Generated package.json:"
	@cat $(JS_GEN_DIR)/package.json

generate-js-api: check-js-vars print-js-vars clean-js js-generate js-package js-tsconfig js-build
	@echo "JS API generated successfully."

clean-js:
	@echo "Cleaning JS client files..."
	@rm -rf $(JS_GEN_DIR)