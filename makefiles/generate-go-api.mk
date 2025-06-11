export OPENAPI_FILE GEN_DIR PACKAGE

REQUIRED_VARS := OPENAPI_FILE GEN_DIR PACKAGE

OAPI_GEN := $(HOME)/go/bin/oapi-codegen

.PHONY: check-vars print-vars install-tools create-gen-dir types server client generate-go-api clean

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
	@echo "OPENAPI_FILE		= $(OPENAPI_FILE)"
	@echo "GEN_DIR        	= $(GEN_DIR)"
	@echo "PACKAGE      	= $(PACKAGE)"

install-tools:
	@which oapi-codegen >/dev/null || (echo "Installing Go tools..."; \
		go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1)

create-gen-dir:
	@mkdir -p $(GEN_DIR)

types: install-tools create-gen-dir
	@echo "Generating Go types (models)..."
	$(OAPI_GEN) -generate types -package $(PACKAGE) -o $(GEN_DIR)/models.gen.go $(OPENAPI_FILE)

server: install-tools create-gen-dir
	@echo "Generating Go server..."
	$(OAPI_GEN) -generate gin-server,strict-server -package $(PACKAGE) -o $(GEN_DIR)/server.gen.go $(OPENAPI_FILE)

client: install-tools create-gen-dir
	@echo "Generating Go client..."
	$(OAPI_GEN) -generate client -package $(PACKAGE) -o $(GEN_DIR)/client.gen.go $(OPENAPI_FILE)

generate-go-api: check-vars print-vars clean types server client
	@echo "Go API generated successfully."

clean:
	@echo "Cleaning Go generated files..."
	@rm -rf $(GEN_DIR)