# Schema Registry Deployment Guide

## Overview

Schema Registry для Kafka з підтримкою Avro схем в Kubernetes.

## Docker Compose (Development)

Schema Registry вже додано в `docker/compose/kafka.yml`:

```yaml
schema-registry:
  image: confluentinc/cp-schema-registry:7.8.0
  ports:
    - 8081:8081
  environment:
    SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:29092
```

**URL:** http://localhost:8081

## Kubernetes Deployment

### Option 1: Використати Confluent Helm Chart (Recommended)

```bash
# Add Confluent Helm repo
helm repo add confluentinc https://confluentinc.github.io/cp-helm-charts/
helm repo update

# Install Schema Registry
helm install schema-registry confluentinc/cp-schema-registry \
  --namespace dev \
  --set kafka.bootstrapServers=PLAINTEXT://kafka:9092 \
  --set replicaCount=1
```

### Option 2: Custom Deployment

Створіть `helm/values/infrastructure/schema-registry.yaml`:

```yaml
schemaRegistry:
  enabled: true
  replicaCount: 1
  
  image:
    repository: confluentinc/cp-schema-registry
    tag: 7.8.0
    pullPolicy: IfNotPresent

  service:
    type: ClusterIP
    port: 8081

  env:
    - name: SCHEMA_REGISTRY_HOST_NAME
      value: schema-registry
    - name: SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS
      value: PLAINTEXT://kafka:9092
    - name: SCHEMA_REGISTRY_LISTENERS
      value: http://0.0.0.0:8081
    - name: SCHEMA_REGISTRY_KAFKASTORE_TOPIC
      value: _schemas
    - name: SCHEMA_REGISTRY_KAFKASTORE_TOPIC_REPLICATION_FACTOR
      value: "1"

  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"

  livenessProbe:
    httpGet:
      path: /subjects
      port: 8081
    initialDelaySeconds: 30
    periodSeconds: 10

  readinessProbe:
    httpGet:
      path: /subjects
      port: 8081
    initialDelaySeconds: 10
    periodSeconds: 5
```

## Usage in Services

### 1. Update Go service config

```yaml
# configs/config.yaml
messaging:
  kafka:
    brokers:
      - kafka:9092
    schema_registry:
      url: http://schema-registry:8081
```

### 2. Use in ecommerce-commons

Додайте Schema Registry клієнт:

```go
package kafka

import (
    "github.com/riferrei/srclient"
)

type SchemaRegistryConfig struct {
    URL string
}

func NewSchemaRegistryClient(cfg SchemaRegistryConfig) *srclient.SchemaRegistryClient {
    return srclient.CreateSchemaRegistryClient(cfg.URL)
}
```

### 3. Producer з Avro

```go
import (
    "github.com/Sokol111/ecommerce-product-messaging-api/api/events"
)

// Register schema on first use
schema, err := schemaRegistry.CreateSchema(
    "ProductCreatedEvent-value",
    string(events.ProductCreatedSchema),
    srclient.Avro,
)

// Serialize with Avro
serializer := events.NewAvroSerializer()
serializer.RegisterSchema("ProductCreatedEvent", string(events.ProductCreatedSchema))

data, err := serializer.Serialize("ProductCreatedEvent", event)

// Send to Kafka
err = producer.Send(ctx, "product.events", data)
```

### 4. Consumer з Avro

```go
// Deserialize from Kafka
var event events.ProductCreatedEvent
err := serializer.Deserialize("ProductCreatedEvent", message.Value, &event)
```

## Testing

### Check Schema Registry Health

```bash
# Docker Compose
curl http://localhost:8081/subjects

# Kubernetes
kubectl port-forward -n dev svc/schema-registry 8081:8081
curl http://localhost:8081/subjects
```

### List Registered Schemas

```bash
curl http://localhost:8081/subjects
```

### Get Schema by Subject

```bash
curl http://localhost:8081/subjects/ProductCreatedEvent-value/versions/latest
```

### Register Schema Manually

```bash
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{...}"}' \
  http://localhost:8081/subjects/ProductCreatedEvent-value/versions
```

## Schema Compatibility

Schema Registry підтримує різні рівні сумісності:

- `BACKWARD` (default) - нові схеми можуть читати старі дані
- `FORWARD` - старі схеми можуть читати нові дані
- `FULL` - обидва напрямки
- `NONE` - без перевірки

Налаштування:

```bash
# Global compatibility
curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"compatibility": "BACKWARD"}' \
  http://localhost:8081/config

# Per-subject compatibility
curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"compatibility": "FULL"}' \
  http://localhost:8081/config/ProductCreatedEvent-value
```

## Best Practices

1. **Version Everything** - кожна зміна схеми = нова версія
2. **Use Defaults** - додавайте default values для нових полів
3. **Test Compatibility** - перевіряйте сумісність перед deploy
4. **Document Changes** - описуйте зміни в схемах
5. **Automate Publishing** - використовуйте CI/CD для публікації схем

## CI/CD Integration

GitHub Actions автоматично публікує схеми при push:

```yaml
- name: Publish schemas to Schema Registry
  run: make publish-schemas SCHEMA_REGISTRY_URL=${{ secrets.SCHEMA_REGISTRY_URL }}
```

## Monitoring

Додайте метрики Schema Registry в Prometheus:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'schema-registry'
    static_configs:
      - targets: ['schema-registry:8081']
```

## Troubleshooting

### Schema Registry не стартує

```bash
# Check logs
docker logs schema-registry
kubectl logs -n dev deployment/schema-registry

# Check Kafka connectivity
kubectl exec -it schema-registry -- curl kafka:9092
```

### Схема не публікується

```bash
# Check schema validity
cat avro/product_created.avsc | jq

# Test registration manually
curl -v -X POST http://localhost:8081/subjects/test-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"string\"}"}'
```

## Migration from JSON to Avro

1. Створити Avro схеми з існуючих Go structs
2. Реєструвати схеми в Schema Registry
3. Поступово переводити продюсери на Avro
4. Підтримувати backward compatibility
5. Переводити консюмери на Avro
6. Видалити JSON серіалізацію

## Resources

- [Confluent Schema Registry Docs](https://docs.confluent.io/platform/current/schema-registry/index.html)
- [Avro Specification](https://avro.apache.org/docs/current/spec.html)
- [AsyncAPI Specification](https://www.asyncapi.com/docs/reference/specification/v3.0.0)
