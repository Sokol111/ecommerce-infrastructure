export OPENAPI_FILE GO_GEN_DIR PACKAGE

REQUIRED_VARS := OPENAPI_FILE GO_GEN_DIR PACKAGE

OAPI_GEN := $(HOME)/go/bin/oapi-codegen

.PHONY: check-go-vars print-go-vars install-go-tools create-go-gen-dir types server client build-go-api clean-go

check-go-vars:
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

print-go-vars:
	@echo "OPENAPI_FILE		= $(OPENAPI_FILE)"
	@echo "GO_GEN_DIR       = $(GO_GEN_DIR)"
	@echo "PACKAGE      	= $(PACKAGE)"

install-go-tools:
	@which oapi-codegen >/dev/null || (echo "Installing Go tools..."; \
		go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@v2.4.1)

create-go-gen-dir:
	@mkdir -p $(GO_GEN_DIR)

types: install-go-tools create-go-gen-dir
	@echo "Generating Go types (models)..."
	$(OAPI_GEN) -generate types -package $(PACKAGE) -o $(GO_GEN_DIR)/models.gen.go $(OPENAPI_FILE)

server: install-go-tools create-go-gen-dir
	@echo "Generating Go server..."
	$(OAPI_GEN) -generate gin-server,strict-server -package $(PACKAGE) -o $(GO_GEN_DIR)/server.gen.go $(OPENAPI_FILE)

client: install-go-tools create-go-gen-dir
	@echo "Generating Go client..."
	$(OAPI_GEN) -generate client -package $(PACKAGE) -o $(GO_GEN_DIR)/client.gen.go $(OPENAPI_FILE)

embed-openapi: install-go-tools create-go-gen-dir
	@echo "Copying $(OPENAPI_FILE) to $(GO_GEN_DIR)/openapi.yml"
	cp $(OPENAPI_FILE) $(GO_GEN_DIR)/openapi.yml
	@echo "Generating Go embedded openapi.gen.go..."
	@echo 'package $(PACKAGE)' > $(GO_GEN_DIR)/openapi.gen.go
	@echo '' >> $(GO_GEN_DIR)/openapi.gen.go
	@echo 'import _ "embed"' >> $(GO_GEN_DIR)/openapi.gen.go
	@echo '' >> $(GO_GEN_DIR)/openapi.gen.go
	@echo '//go:embed openapi.yml' >> $(GO_GEN_DIR)/openapi.gen.go
	@echo 'var OpenAPIDoc []byte' >> $(GO_GEN_DIR)/openapi.gen.go

build-go-api: check-go-vars print-go-vars clean-go types server client embed-openapi
	@echo "Go API generated successfully."

clean-go:
	@echo "Cleaning Go generated files..."
	@rm -rf $(GO_GEN_DIR)