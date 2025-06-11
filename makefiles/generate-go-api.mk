OAPI_GEN := $(HOME)/go/bin/oapi-codegen
OPENAPI_FILE := openapi/openapi.yml
GEN_DIR := api
PACKAGE := api

.PHONY: install-tools create-gen-dir types server client generate-go-api clean

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

generate-go-api: clean types server client
	@echo "Go API generated successfully."

clean:
	@echo "Cleaning Go generated files..."
	@rm -rf $(GEN_DIR)