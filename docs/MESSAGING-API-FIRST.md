# API-First підхід для Kafka Messaging

## Огляд рішення

Створено комплексну архітектуру для API-First підходу до Kafka messaging з використанням:

1. **AsyncAPI 3.0** - документування Kafka topics, channels, operations
2. **Avro schemas** - типобезпечна серіалізація подій
3. **Schema Registry** - версіонування та валідація схем
4. **Автогенерація Go коду** - з AsyncAPI та Avro схем через GitHub Actions

## Структура проекту

```
ecommerce-product-service-api/
├── openapi/
│   └── openapi.yml                # REST API specification
├── asyncapi/
│   └── asyncapi.yaml              # AsyncAPI специфікація
├── avro/
│   ├── base_event.avsc            # Базова event структура
│   ├── product_created.avsc       # ProductCreated Avro схема
│   └── product_updated.avsc       # ProductUpdated Avro схема
├── .github/workflows/
│   └── release.yml                # CI/CD для REST + Events
├── Makefile                       # Генерація REST + Events
├── VERSION                        # Семантичне версіонування
└── README.md                      # Документація
```

## Що було створено

### 1. ecommerce-product-service-api (оновлений проект)

✅ **REST API** (`openapi/openapi.yml`):
- Endpoints для CRUD операцій з продуктами
- OpenAPI 3.0 специфікація

✅ **AsyncAPI специфікація** (`asyncapi/asyncapi.yaml`):
- Channels: `product.events`
- Messages: `ProductCreated`, `ProductUpdated`
- Operations: publish/subscribe з документацією
- Headers: event metadata (trace_id, correlation_id, тощо)

✅ **Avro схеми** (`avro/*.avsc`):
- `base_event.avsc` - спільна структура для всіх подій
- `product_created.avsc` - схема для ProductCreated з вкладеним payload
- `product_updated.avsc` - схема для ProductUpdated
- Підтримка logical types (timestamp-millis)
- Optional fields з default values

✅ **GitHub Workflow** (`.github/workflows/release.yml`):
- Автоматична генерація REST API (Go server/client, JS client)
- Автоматична валідація AsyncAPI та Avro схем
- Генерація Go коду з Avro (structs + JSON tags)
- Генерація serializer helpers (Avro encoding/decoding)
- Вбудовування схем як embedded resources
- Публікація схем в Schema Registry
- Створення GitHub releases з версіонуванням

✅ **Makefile** з командами:
- `make gen-go` - генерація REST API Go коду
- `make gen-js` - генерація JS клієнта
- `make gen-events` - генерація Events API
- `make gen-all` - генерація всього
- `make validate` - валідація OpenAPI + AsyncAPI схем
- `make publish-schemas` - публікація в Schema Registry

### 2. Infrastructure Updates

✅ **Schema Registry в docker-compose** (`docker/compose/kafka.yml`):
```yaml
schema-registry:
  image: confluentinc/cp-schema-registry:7.8.0
  ports: 8081:8081
  # Інтегрований з Kafka та Kafka UI
```

✅ **GitHub Workflow для AsyncAPI** (`.github/workflows/build-asyncapi.yml`):
- Reusable workflow для всіх messaging-api проектів
- Підтримка AsyncAPI CLI, avrogen
- Автоматична генерація serializers
- Schema Registry публікація

✅ **Makefile для AsyncAPI** (`makefiles/build-asyncapi.mk`):
- Валідація AsyncAPI та Avro
- Генерація Go коду з Avro
- Генерація helpers (AvroSerializer)
- Embedded resources (схеми + AsyncAPI spec)

✅ **Документація** (`docs/SCHEMA-REGISTRY.md`):
- Deployment guide для k8s та docker-compose
- Приклади використання з Go
- Schema evolution best practices
- Troubleshooting

✅ **Оновлений Makefile** infrastructure:
- Додано Schema Registry URL в `make infra-up`

## Workflow

### 1. Розробка Events

```bash
# 1. Додати/змінити AsyncAPI spec
vim asyncapi/asyncapi.yaml

# 2. Створити/оновити Avro схеми
vim avro/product_created.avsc

# 3. Валідувати локально
make validate

# 4. Генерувати Go код
make gen-go

# 5. Commit і push
git add .
git commit -m "feat: add new event"
git push
```

### 2. CI/CD Process

```
Push to GitHub
    ↓
GitHub Actions triggered
    ↓
1. Validate AsyncAPI spec
2. Validate Avro schemas
3. Generate Go code from Avro
4. Generate serializers
5. Embed schemas as Go resources
6. Publish to Schema Registry
7. Create GitHub Release
8. Commit generated code
```

### 3. Використання в сервісах

```go
import "github.com/Sokol111/ecommerce-product-messaging-api/api/events"

// Ініціалізація
serializer, _ := events.NewAvroSerializer()
serializer.RegisterSchema("ProductCreatedEvent", string(events.ProductCreatedSchema))

// Producer
event := &events.ProductCreatedEvent{
    EventID:   uuid.New().String(),
    EventType: "ProductCreated",
    Source:    "ecommerce-product-service",
    Topic:     "product.events",
    Payload: &events.ProductCreatedPayload{
        ProductID: product.ID,
        Name:      product.Name,
        // ...
    },
}

data, _ := serializer.Serialize("ProductCreatedEvent", event)
producer.Send(ctx, "product.events", data)

// Consumer
var event events.ProductCreatedEvent
serializer.Deserialize("ProductCreatedEvent", message.Value, &event)
```

## Переваги цього підходу

### ✅ Порівняно з поточним JSON підходом:

1. **Типобезпека на рівні схеми**:
   - Avro забезпечує строгу типізацію
   - Schema Registry валідує сумісність
   - Генерований Go код з повною типобезпекою

2. **Компактна серіалізація**:
   - Avro binary формат менший за JSON
   - Важливо для high-throughput систем

3. **Schema Evolution**:
   - Backward/Forward compatibility
   - Версіонування схем
   - Безпечні апгрейди

4. **Документація**:
   - AsyncAPI як single source of truth
   - Автоматична документація events
   - Візуалізація через AsyncAPI Studio

5. **Code Generation**:
   - Автогенерація Go structs
   - Serialization helpers
   - Зменшення boilerplate коду

6. **Contract Testing**:
   - Схеми як контракти
   - Валідація на CI/CD
   - Захист від breaking changes

## Що далі?

### Наступні кроки:

1. **Додати AsyncAPI/Avro в інші *-api проекти**:
   ```
   ecommerce-category-service-api
   ecommerce-image-service-api
   ecommerce-product-query-service-api
   ecommerce-category-query-service-api
   ```

2. **Оновити ecommerce-commons**:
   - Додати Schema Registry клієнт
   - Інтегрувати Avro serialization
   - Оновити producer/consumer для Avro

3. **Міграція існуючих events**:
   - Створити Avro схеми з поточних Go structs
   - Паралельна підтримка JSON + Avro
   - Поступовий перехід consumers

4. **K8s Integration**:
   - Deploy Schema Registry в dev namespace
   - Налаштувати Helm chart
   - Додати monitoring

5. **Testing**:
   - Contract tests з схемами
   - Schema compatibility tests
   - Integration tests з Avro

## Альтернативи та компроміси

### AsyncAPI + Avro vs Protobuf + gRPC:

| Критерій | AsyncAPI + Avro | Protobuf + gRPC |
|----------|-----------------|-----------------|
| Async messaging | ✅ Відмінно | ⚠️ Потрібен streaming |
| Schema evolution | ✅ Built-in | ✅ Built-in |
| Tooling | ⚠️ Менше mature | ✅ Відмінний екосистема |
| Learning curve | ⚠️ Середній | ⚠️ Середній |
| Kafka integration | ✅ Native | ⚠️ Потрібен wrapper |
| REST API | ⚠️ N/A | ✅ gRPC-Gateway |

**Вибір AsyncAPI + Avro правильний для Kafka-based архітектури!**

### JSON Schema vs Avro:

- **JSON Schema**: легше читати, гірша валідація, більший розмір
- **Avro**: компактніший, строга типізація, binary format

Можна підтримувати обидва через AsyncAPI (contentType).

## Ресурси

- [AsyncAPI Specification](https://www.asyncapi.com/docs/reference/specification/v3.0.0)
- [Apache Avro Documentation](https://avro.apache.org/docs/current/)
- [Confluent Schema Registry](https://docs.confluent.io/platform/current/schema-registry/)
- [Example: ecommerce-product-service-api](https://github.com/Sokol111/ecommerce-product-service-api)
- [Schema Registry Guide](./SCHEMA-REGISTRY.md)

## Summary

✅ **Створено повноцінний API-First підхід для Kafka**:
- AsyncAPI для документування
- Avro для серіалізації
- Schema Registry для версіонування
- GitHub Actions для автоматизації
- Go code generation

Це рішення забезпечує:
- Type safety
- Schema evolution
- Documentation
- Automation
- Best practices для event-driven architecture

Твій оригінальний план був правильний! 🎉
