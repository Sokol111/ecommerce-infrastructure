# Build AsyncAPI Messaging API Makefile
# This file is meant to be included/used by project-specific Makefiles

.PHONY: build-messaging-api clean-messaging-api validate-asyncapi validate-avro

# Default values - override these in your project Makefile
ASYNCAPI_FILE ?= asyncapi/asyncapi.yaml
AVRO_DIR ?= avro
GO_GEN_DIR ?= api
PACKAGE ?= events
SCHEMA_REGISTRY_URL ?= http://localhost:8081

# Tools
AVROGEN := $(shell go env GOPATH)/bin/avrogen
ASYNCAPI := npx @asyncapi/cli

build-messaging-api: validate-asyncapi validate-avro generate-avro-go generate-helpers embed-resources
	@echo "✓ Messaging API build complete"

validate-asyncapi:
	@echo "→ Validating AsyncAPI specification..."
	@command -v asyncapi >/dev/null 2>&1 || npm install -g @asyncapi/cli
	@asyncapi validate $(ASYNCAPI_FILE)

validate-avro:
	@echo "→ Validating Avro schemas..."
	@for schema in $(AVRO_DIR)/*.avsc; do \
		echo "  Checking $$schema..."; \
		jq empty "$$schema" || exit 1; \
	done

generate-avro-go: install-avrogen
	@echo "→ Generating Go code from Avro schemas..."
	@mkdir -p $(GO_GEN_DIR)
	@for schema in $(AVRO_DIR)/*.avsc; do \
		basename=$$(basename "$$schema" .avsc); \
		echo "  Generating $$basename..."; \
		$(AVROGEN) -pkg $(PACKAGE) \
			-o "$(GO_GEN_DIR)/$${basename}.gen.go" \
			-tags json \
			"$$schema"; \
	done

generate-helpers:
	@echo "→ Generating serialization helpers..."
	@cat > $(GO_GEN_DIR)/serializer.gen.go << 'EOFHELPER'
package $(PACKAGE)

import (
	"bytes"
	"fmt"

	"github.com/hamba/avro/v2"
)

// AvroSerializer handles Avro serialization/deserialization
type AvroSerializer struct {
	schemas map[string]avro.Schema
}

// NewAvroSerializer creates a new Avro serializer
func NewAvroSerializer() (*AvroSerializer, error) {
	return &AvroSerializer{
		schemas: make(map[string]avro.Schema),
	}, nil
}

// RegisterSchema registers an Avro schema
func (s *AvroSerializer) RegisterSchema(name string, schemaJSON string) error {
	schema, err := avro.Parse(schemaJSON)
	if err != nil {
		return fmt.Errorf("failed to parse schema %s: %w", name, err)
	}
	s.schemas[name] = schema
	return nil
}

// Serialize encodes data using Avro
func (s *AvroSerializer) Serialize(schemaName string, data interface{}) ([]byte, error) {
	schema, ok := s.schemas[schemaName]
	if !ok {
		return nil, fmt.Errorf("schema %s not registered", schemaName)
	}
	
	var buf bytes.Buffer
	encoder := avro.NewEncoder(schema, &buf)
	if err := encoder.Encode(data); err != nil {
		return nil, fmt.Errorf("failed to encode: %w", err)
	}
	
	return buf.Bytes(), nil
}

// Deserialize decodes Avro data
func (s *AvroSerializer) Deserialize(schemaName string, data []byte, v interface{}) error {
	schema, ok := s.schemas[schemaName]
	if !ok {
		return fmt.Errorf("schema %s not registered", schemaName)
	}
	
	reader := bytes.NewReader(data)
	decoder := avro.NewDecoder(schema, reader)
	if err := decoder.Decode(v); err != nil {
		return fmt.Errorf("failed to decode: %w", err)
	}
	
	return nil
}
EOFHELPER

embed-resources:
	@echo "→ Embedding resources..."
	@mkdir -p $(GO_GEN_DIR)/schemas
	@cp $(ASYNCAPI_FILE) $(GO_GEN_DIR)/asyncapi.yaml
	@cp $(AVRO_DIR)/*.avsc $(GO_GEN_DIR)/schemas/
	@cat > $(GO_GEN_DIR)/schemas.gen.go << 'EOFEMBED'
package $(PACKAGE)

import _ "embed"

//go:embed asyncapi.yaml
var AsyncAPISpec []byte

EOFEMBED
	@for schema in $(AVRO_DIR)/*.avsc; do \
		basename=$$(basename "$$schema" .avsc); \
		varname=$$(echo "$$basename" | sed -E 's/(^|_)([a-z])/\U\2/g'); \
		echo "//go:embed schemas/$${basename}.avsc" >> $(GO_GEN_DIR)/schemas.gen.go; \
		echo "var $${varname}Schema []byte" >> $(GO_GEN_DIR)/schemas.gen.go; \
		echo "" >> $(GO_GEN_DIR)/schemas.gen.go; \
	done

install-avrogen:
	@echo "→ Ensuring avrogen is installed..."
	@command -v $(AVROGEN) >/dev/null 2>&1 || go install github.com/hamba/avro/v2/cmd/avrogen@latest

publish-schemas:
	@echo "→ Publishing schemas to Schema Registry at $(SCHEMA_REGISTRY_URL)..."
	@for schema in $(AVRO_DIR)/*.avsc; do \
		subject=$$(basename "$$schema" .avsc); \
		echo "  Publishing $$subject..."; \
		schema_json=$$(cat "$$schema" | jq -c tostring); \
		curl -X POST \
			-H "Content-Type: application/vnd.schemaregistry.v1+json" \
			--data "{\"schema\": $$schema_json}" \
			"$(SCHEMA_REGISTRY_URL)/subjects/$${subject}-value/versions" \
			|| echo "  Failed to publish $$subject"; \
	done

clean-messaging-api:
	@echo "→ Cleaning generated files..."
	@rm -rf $(GO_GEN_DIR)

.DEFAULT_GOAL := build-messaging-api
