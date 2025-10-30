# Observability Stack (Docker Compose)

Спрощений observability стек для локальної розробки з Grafana, Prometheus та Tempo.

## 🏗️ Архітектура

```
┌─────────────────────────────────────────────────────────┐
│              Docker Compose (shared-network)             │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌────────┐                │
│  │ Grafana  │  │Prometheus│  │ Tempo  │                 │
│  │  :3000   │  │  :9090   │  │ :3200  │                 │
│  └────┬─────┘  └────▲─────┘  └───▲────┘                 │
│       │             │            │                       │
│       └─────────────┴────────────┘                       │
│                     │            │                       │
└─────────────────────┼────────────┼───────────────────────┘
                      │            │
                      ▼            ▼
         ┌────────────────────────────────────────────┐
         │     K3d Cluster (shared-network)           │
         ├────────────────────────────────────────────┤
         │                                             │
         │  ┌──────────────────────────────────────┐  │
         │  │      OTel Collector (DaemonSet)     │  │
         │  │   - Приймає traces/metrics           │  │
         │  │   - Відправляє в docker-compose      │  │
         │  └──────────────────────────────────────┘  │
         │              ▲                              │
         │              │                              │
         │  ┌───────────┴───────────┐                 │
         │  │  Application Pods      │                 │
         │  │  - product-service     │                 │
         │  │  - category-service    │                 │
         │  │  - image-service       │                 │
         │  │  - *-query-service     │                 │
         │  └────────────────────────┘                 │
         └────────────────────────────────────────────┘
```

## 📦 Компоненти

### Grafana (порт 3000)
- **Призначення**: Візуалізація метрик та traces
- **Доступ**: http://localhost:3000
- **Логін**: admin / admin
- **Datasources**: Автоматично налаштовані Prometheus та Tempo

### Prometheus (порт 9090)
- **Призначення**: Збір та зберігання метрик
- **Джерела метрик**:
  - OTel Collector (OTLP)
  - Kubernetes API
  - Tempo metrics generator
- **Remote Write**: Enabled для прийому метрик

### Tempo (порт 3200)
- **Призначення**: Distributed tracing
- **Протоколи**: 
  - OTLP gRPC: 4317
  - OTLP HTTP: 4318
- **Metrics Generator**: Service graphs + span metrics → Prometheus
- **Retention**: 7 днів

## 💡 Логи

Для **локальної розробки логи не збираються централізовано**. Використовуйте:

```bash
# Логи конкретного сервісу
make logs SVC=product-service

# Всі логи в namespace
make logs-all

# Логи конкретного pod
kubectl logs <pod-name> -n dev

# З фільтрацією через stern
stern product -n dev
```

## 🚀 Швидкий старт

### 1. Запустити observability стек

```bash
cd /home/ihsokolo/projects/ecommerce/ecommerce-infrastructure

# Запустити всю інфраструктуру (включно з observability)
make infra-up
```

### 2. Перевірити статус

```bash
# Перевірити запущені контейнери
make observability-status

# Або безпосередньо
docker compose -f docker/compose/observability.yml ps
```

### 3. Відкрити Grafana

```bash
make grafana
# Або відкрийте браузер: http://localhost:3000
# Логін: admin, Пароль: admin
```

## 📊 Використання

### Перегляд traces

1. В Grafana перейдіть в **Explore**
2. Виберіть datasource **Tempo**
3. Шукайте trace за:
   - Trace ID
   - Service name
   - Duration
4. **Service Graph**: Візуалізація зв'язків між сервісами

### Перегляд метрик

1. В Grafana перейдіть в **Explore**
2. Виберіть datasource **Prometheus**
3. Запити:
   ```promql
   # Request rate
   rate(http_requests_total{namespace="dev"}[5m])
   
   # Error rate
   rate(http_requests_total{status=~"5.."}[5m])
   
   # Service graph metrics (від Tempo)
   traces_service_graph_request_total
   
   # Latency p95
   histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   ```

## 🔄 Workflow з k3d

### OTel Collector в k3d

OTel Collector запущений як DaemonSet в k3d та:
1. Приймає OTLP traces/metrics від applications
2. Відправляє дані в docker-compose сервіси через `shared-network`

Конфігурація: `helm/values/observability/otelcol.yaml`

### Application Services

Ваші Go сервіси повинні відправляти telemetry на OTel Collector:

```yaml
# В конфігах сервісів (config.dev.yaml)
observability:
  metrics-enabled: true
  traces-enabled: true
  otlp-endpoint: "otel-collector-opentelemetry-collector.observability.svc:4317"
```

## 🛠️ Команди Makefile

```bash
# Запустити observability стек
make infra-up

# Зупинити observability стек
make infra-down

# Перезапустити
make infra-restart

# Повне очищення (включно з volumes)
make infra-clean

# Відкрити Grafana
make grafana

# Відкрити Prometheus
make prometheus

# Показати інформацію про Tempo
make tempo

# Статус observability стеку
make observability-status

# Логи інфраструктури
make infra-logs

# Логи сервісів
make logs SVC=product-service
make logs-all
```

## 📝 Troubleshooting

### OTel Collector не може підключитися до Tempo/Prometheus

1. Перевірте, що k3d використовує `shared-network`:
   ```bash
   docker network inspect shared-network
   ```

2. Перевірте, що OTel Collector pod має `hostNetwork: true`

3. Перевірте DNS resolution:
   ```bash
   kubectl exec -it <otel-pod> -n observability -- nslookup tempo
   ```

### Grafana не показує дані

1. Перевірте health endpoints:
   - Prometheus: http://localhost:9090/-/healthy
   - Tempo: http://localhost:3200/ready

2. Перевірте datasources в Grafana:
   - Settings → Data sources
   - Test connection для кожного

## 🔍 Корисні запити

### PromQL (Prometheus)

```promql
# Request rate per service
sum by (service_name) (rate(http_requests_total[5m]))

# Error rate
sum by (service_name) (rate(http_requests_total{status=~"5.."}[5m]))

# Latency p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Memory usage
container_memory_usage_bytes{namespace="dev"}
```

## 📚 Посилання

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Tempo Tracing](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)


## 🏗️ Архітектура

```
┌─────────────────────────────────────────────────────────┐
│              Docker Compose (shared-network)             │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ Grafana  │  │   Loki   │  │Prometheus│  │ Tempo  │  │
│  │  :3000   │  │  :3100   │  │  :9090   │  │ :3200  │  │
│  └────┬─────┘  └────▲─────┘  └────▲─────┘  └───▲────┘  │
│       │             │              │            │        │
│       └─────────────┴──────────────┴────────────┘        │
│                     │              │            │        │
│              ┌──────┴──────┐       │            │        │
│              │  Promtail   │       │            │        │
│              │ (log agent) │       │            │        │
│              └──────┬──────┘       │            │        │
│                     │              │            │        │
└─────────────────────┼──────────────┼────────────┼────────┘
                      │              │            │
                      ▼              ▼            ▼
         ┌────────────────────────────────────────────┐
         │     K3d Cluster (shared-network)           │
         ├────────────────────────────────────────────┤
         │                                             │
         │  ┌──────────────────────────────────────┐  │
         │  │      OTel Collector (DaemonSet)     │  │
         │  │   - Збирає логи з pods               │  │
         │  │   - Приймає traces/metrics           │  │
         │  │   - Відправляє в docker-compose      │  │
         │  └──────────────────────────────────────┘  │
         │              ▲                              │
         │              │                              │
         │  ┌───────────┴───────────┐                 │
         │  │  Application Pods      │                 │
         │  │  - product-service     │                 │
         │  │  - category-service    │                 │
         │  │  - image-service       │                 │
         │  │  - *-query-service     │                 │
         │  └────────────────────────┘                 │
         └────────────────────────────────────────────┘
```

## 📦 Компоненти

### Grafana (порт 3000)
- **Призначення**: Візуалізація метрик, логів та traces
- **Доступ**: http://localhost:3000
- **Логін**: admin / admin
- **Datasources**: Автоматично налаштовані Loki, Prometheus, Tempo

### Loki (порт 3100)
- **Призначення**: Агрегація та зберігання логів
- **Джерела логів**:
  - Promtail → Docker контейнери k3d
  - OTel Collector → Application logs з k8s pods
- **Retention**: 7 днів (168h)

### Promtail
- **Призначення**: Збір логів з Docker контейнерів
- **Джерела**:
  - k3d-dev-cluster контейнери
  - Ecommerce application сервіси
  - System компоненти (traefik, coredns)
- **Фічі**:
  - JSON parsing
  - Trace correlation (trace_id → Tempo)
  - Kubernetes labels enrichment

### Prometheus (порт 9090)
- **Призначення**: Збір та зберігання метрик
- **Джерела метрик**:
  - OTel Collector (OTLP)
  - Kubernetes API
  - Tempo metrics generator
- **Remote Write**: Enabled для прийому метрик

### Tempo (порт 3200)
- **Призначення**: Distributed tracing
- **Протоколи**: 
  - OTLP gRPC: 4317
  - OTLP HTTP: 4318
- **Metrics Generator**: Service graphs + span metrics → Prometheus
- **Retention**: 7 днів

## 🚀 Швидкий старт

### 1. Запустити observability стек

```bash
cd /home/ihsokolo/projects/ecommerce/ecommerce-infrastructure

# Запустити всю інфраструктуру (включно з observability)
make infra-up
```

### 2. Перевірити статус

```bash
# Перевірити запущені контейнери
make observability-status

# Або безпосередньо
docker compose -f docker/compose/observability.yml ps
```

### 3. Відкрити Grafana

```bash
make grafana
# Або відкрийте браузер: http://localhost:3000
# Логін: admin, Пароль: admin
```

## 📊 Використання

### Перегляд логів

1. Відкрийте Grafana: http://localhost:3000
2. Перейдіть в **Explore**
3. Виберіть datasource **Loki**
4. Запити:
   ```logql
   # Всі логи з namespace dev
   {namespace="dev"}
   
   # Логи конкретного сервісу
   {service_name="ecommerce-product-service"}
   
   # Логи з помилками
   {namespace="dev"} |= "error"
   
   # Логи з trace_id (correlation з Tempo)
   {namespace="dev"} | json | trace_id != ""
   ```

### Перегляд traces

1. В Grafana перейдіть в **Explore**
2. Виберіть datasource **Tempo**
3. Шукайте trace за:
   - Trace ID
   - Service name
   - Duration
4. **Корреляція**: Клік на trace_id в логах → автоматичний перехід в Tempo

### Перегляд метрик

1. В Grafana перейдіть в **Explore**
2. Виберіть datasource **Prometheus**
3. Запити:
   ```promql
   # CPU usage по сервісах
   rate(container_cpu_usage_seconds_total{namespace="dev"}[5m])
   
   # HTTP request rate
   rate(http_requests_total{namespace="dev"}[5m])
   
   # Service graph metrics (від Tempo)
   traces_service_graph_request_total
   ```

## 🔧 Конфігурація

### Promtail Pipeline

Promtail автоматично:
- Фільтрує контейнери k3d кластера
- Парсить JSON логи
- Витягує `trace_id` та `span_id` для correlation
- Додає Kubernetes labels (namespace, pod, service)

Конфігурація: `docker/compose/config/promtail-config.yaml`

### Loki Retention

По замовчуванню логи зберігаються **7 днів**. Для зміни:

```yaml
# docker/compose/config/loki-config.yaml
limits_config:
  retention_period: 168h  # Змініть на потрібне значення
```

### Grafana Datasources

Datasources налаштовуються автоматично при старті:
- `docker/compose/config/grafana-datasources.yaml`

Корреляція між datasources вже налаштована:
- Loki ↔ Tempo (через trace_id)
- Tempo ↔ Prometheus (через exemplars)
- Tempo ↔ Loki (через service.name, namespace)

## 🔄 Workflow з k3d

### OTel Collector в k3d

OTel Collector запущений як DaemonSet в k3d та:
1. Збирає логи з `/var/log/pods`
2. Приймає OTLP traces/metrics від applications
3. Відправляє дані в docker-compose сервіси через `shared-network`

Конфігурація: `helm/values/observability/otelcol.yaml`

### Application Services

Ваші Go сервіси повинні відправляти telemetry на OTel Collector:

```yaml
# В конфігах сервісів (config.dev.yaml)
observability:
  metrics-enabled: true
  traces-enabled: true
  logs-enabled: true
  otlp-endpoint: "otel-collector-opentelemetry-collector.observability.svc:4317"
```

## 🛠️ Команди Makefile

```bash
# Запустити observability стек
make infra-up

# Зупинити observability стек
make infra-down

# Перезапустити
make infra-restart

# Повне очищення (включно з volumes)
make infra-clean

# Відкрити Grafana
make grafana

# Відкрити Prometheus
make prometheus

# Показати інформацію про Loki
make loki

# Показати інформацію про Tempo
make tempo

# Статус observability стеку
make observability-status

# Логи всієї інфраструктури
make infra-logs
```

## 📝 Troubleshooting

### Promtail не збирає логи

1. Перевірте доступ до Docker socket:
   ```bash
   docker compose -f docker/compose/observability.yml logs promtail
   ```

2. Перевірте фільтри в `promtail-config.yaml`

### OTel Collector не може підключитися до Loki/Tempo

1. Перевірте, що k3d використовує `shared-network`:
   ```bash
   docker network inspect shared-network
   ```

2. Перевірте, що OTel Collector pod має `hostNetwork: true`

3. Перевірте DNS resolution:
   ```bash
   kubectl exec -it <otel-pod> -n observability -- nslookup loki
   ```

### Grafana не показує дані

1. Перевірте health endpoints:
   - Loki: http://localhost:3100/ready
   - Prometheus: http://localhost:9090/-/healthy
   - Tempo: http://localhost:3200/ready

2. Перевірте datasources в Grafana:
   - Settings → Data sources
   - Test connection для кожного

## 🔍 Корисні запити

### LogQL (Loki)

```logql
# Всі логи з конкретного pod
{pod_name="ecommerce-product-service-xxx"}

# HTTP errors
{namespace="dev"} | json | level="error" | http_status >= 400

# Повільні запити
{namespace="dev"} | json | duration > 1s

# Trace correlation
{namespace="dev"} | json | trace_id="<trace-id>"
```

### PromQL (Prometheus)

```promql
# Request rate per service
sum by (service_name) (rate(http_requests_total[5m]))

# Error rate
sum by (service_name) (rate(http_requests_total{status=~"5.."}[5m]))

# Latency p95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

## 📚 Посилання

- [Grafana Documentation](https://grafana.com/docs/)
- [Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
- [Prometheus PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Tempo Tracing](https://grafana.com/docs/tempo/latest/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
