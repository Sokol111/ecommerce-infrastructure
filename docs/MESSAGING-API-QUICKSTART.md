# Quick Start: Adding AsyncAPI/Avro to Existing API Project

Приклад додавання AsyncAPI та Avro схем до існуючого *-service-api проекту (на прикладі Category).

## 1. Створити структуру в існуючому проекті

```bash
cd ecommerce-category-service-api
mkdir -p asyncapi avro
```

## 2. AsyncAPI специфікація

`asyncapi/asyncapi.yaml`:
```yaml
asyncapi: 3.0.0
info:
  title: Category Messaging API
  version: 1.0.0
  description: AsyncAPI specification for Category service Kafka events

servers:
  development:
    host: localhost:9092
    protocol: kafka

defaultContentType: application/avro

channels:
  category.events:
    address: category.events
    messages:
      CategoryCreated:
        $ref: '#/components/messages/CategoryCreated'
      CategoryUpdated:
        $ref: '#/components/messages/CategoryUpdated'

components:
  messages:
    CategoryCreated:
      name: CategoryCreated
      title: Category Created Event
      payload:
        $ref: '#/components/schemas/CategoryCreatedPayload'
    CategoryUpdated:
      name: CategoryUpdated
      title: Category Updated Event
      payload:
        $ref: '#/components/schemas/CategoryUpdatedPayload'

  schemas:
    CategoryCreatedPayload:
      type: object
      required:
        - category_id
        - name
        - enabled
      properties:
        category_id:
          type: string
        name:
          type: string
        enabled:
          type: boolean
```

## 3. Avro схеми

`avro/category_created.avsc`:
```json
{
  "type": "record",
  "name": "CategoryCreatedEvent",
  "namespace": "com.ecommerce.events.category",
  "fields": [
    {
      "name": "event_id",
      "type": "string"
    },
    {
      "name": "event_type",
      "type": "string",
      "default": "CategoryCreated"
    },
    {
      "name": "payload",
      "type": {
        "type": "record",
        "name": "CategoryCreatedPayload",
        "fields": [
          {
            "name": "category_id",
            "type": "string"
          },
          {
            "name": "name",
            "type": "string"
          },
          {
            "name": "enabled",
            "type": "boolean"
          }
        ]
      }
    }
  ]
}
```

## 4. Оновити Makefile

Додати в існуючий Makefile:

```makefile
# Messaging API
ASYNCAPI_FILE ?= asyncapi/asyncapi.yaml
AVRO_DIR ?= avro
EVENTS_GEN_DIR ?= events
EVENTS_PACKAGE ?= events
SCHEMA_REGISTRY_URL ?= http://localhost:8081

update-makefiles:
	@echo "Updating includes in Makefile..."
	curl -sSL https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/makefiles/build-go-api.mk -o build-go-api.mk
	curl -sSL https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/makefiles/build-js-api.mk -o build-js-api.mk
	curl -sSL https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/makefiles/build-asyncapi.mk -o build-asyncapi.mk

gen-events: update-makefiles
	make -f build-asyncapi.mk build-messaging-api \
		ASYNCAPI_FILE=$(ASYNCAPI_FILE) \
		AVRO_DIR=$(AVRO_DIR) \
		GO_GEN_DIR=$(EVENTS_GEN_DIR) \
		PACKAGE=$(EVENTS_PACKAGE)

validate:
	asyncapi validate $(ASYNCAPI_FILE)

publish-schemas:
	make -f build-asyncapi.mk publish-schemas

gen-all: gen-go gen-js gen-events
```

## 5. Оновити GitHub Workflow

Оновити `.github/workflows/release.yml`:

```yaml
name: Release

on:
  workflow_dispatch:
  push:
    paths:
      - 'openapi/openapi.yml'
      - 'asyncapi/**'
      - 'avro/**'

jobs:
  release:
    uses: Sokol111/ecommerce-infrastructure/.github/workflows/build-and-release-go-js-api.yml@master

  build-events:
    uses: Sokol111/ecommerce-infrastructure/.github/workflows/build-asyncapi.yml@master
    with:
      asyncapi_file: asyncapi/asyncapi.yaml
      avro_dir: avro
      artifact: category-events-api
      artifact_dir: events
      package: events
```

## 6. Оновити .gitignore

Додати:

```
events/
build-asyncapi.mk
```

## 7. Використання

```bash
# Генерація REST API
make gen-go
make gen-js

# Генерація Events API
make gen-events

# Генерація всього
make gen-all

# Валідація
make validate

# Публікація схем
make publish-schemas SCHEMA_REGISTRY_URL=http://localhost:8081

# Push to GitHub (автоматично запуститься CI/CD)
git add .
git commit -m "feat: add AsyncAPI and Avro schemas"
git push
```

## 8. Інтеграція в сервіс

```go
import "github.com/Sokol111/ecommerce-category-service-api/events"

// Publisher
event := &events.CategoryCreatedEvent{
    EventID:   uuid.New().String(),
    EventType: "CategoryCreated",
    Payload: &events.CategoryCreatedPayload{
        CategoryID: category.ID,
        Name:       category.Name,
        Enabled:    category.Enabled,
    },
}

serializer, _ := events.NewAvroSerializer()
serializer.RegisterSchema("CategoryCreatedEvent", string(events.CategoryCreatedSchema))

data, _ := serializer.Serialize("CategoryCreatedEvent", event)
producer.Send(ctx, "category.events", data)
```

## Готово! 🎉

Тепер у вашому *-service-api проекті є:
- ✅ REST API (OpenAPI)
- ✅ Messaging API (AsyncAPI + Avro)
- ✅ Автогенерація Go коду для обох
- ✅ CI/CD pipeline
- ✅ Schema Registry integration
