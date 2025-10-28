# ecommerce-infrastructure

Infrastructure as Code для E-commerce мікросервісної платформи на базі K3d + Skaffold + Helm.

## 📋 Вимоги

- Docker & Docker Compose
- k3d (v5.x)
- kubectl
- Skaffold (v2.x)
- Helm (v3.x)
- stern (опціонально, для логів)
- make

Перевірити наявність інструментів:

```bash
make tools-check
```

## 🚀 Швидкий старт

### Повна ініціалізація

```bash
# Створити кластер, запустити інфраструктуру та деплой
make init
```

### Розробка

```bash
# Звичайний режим
make dev

# Debug режим з Delve
make dev-debug
```

## 📚 Основні команди

### Управління кластером

```bash
make cluster-create   # Створити k3d кластер
make cluster-start    # Запустити кластер
make cluster-stop     # Зупинити кластер
make cluster-delete   # Видалити кластер
make cluster-reset    # Пересворити кластер
make status           # Показати статус кластера
```

### Deployment

```bash
make dev              # Development режим (live reload)
make dev-debug        # Development + Debug (Delve)
make deploy           # Одноразовий деплой
make deploy-debug     # Деплой в debug режимі
make undeploy         # Видалити деплоймент
make redeploy         # Передеплоїти
```

### Локальна інфраструктура (MongoDB, Kafka)

```bash
make infra-up         # Запустити
make infra-down       # Зупинити
make infra-logs       # Показати логи
make infra-restart    # Перезапустити
make infra-clean      # Видалити з volumes
```

### Kubernetes

```bash
make pods             # Список podів
make pods-all         # Всі pods в усіх namespace
make services         # Список сервісів
make ingress          # Список ingress
make logs SVC=name    # Логи сервісу
make logs-all         # Всі логи в namespace
make describe POD=name # Деталі пода
make exec POD=name    # Shell в pod
make restart DEP=name # Рестарт deployment
make events           # Події в namespace
```

### Observability

```bash
make grafana          # Port-forward Grafana (http://localhost:3000)
make prometheus       # Port-forward Prometheus (http://localhost:9090)
make minio            # Port-forward MinIO Console (http://localhost:9001)
make traefik          # Port-forward Traefik Dashboard (http://localhost:9000)
```

### Debug

```bash
make debug-info       # Інформація про debug порти
make debug-check      # Перевірити доступність портів
```

### Helm

```bash
make helm-list        # Список релізів
make helm-status      # Статус релізу
make helm-values      # Показати values
make helm-template    # Показати rendered templates
```

### Моніторинг

```bash
make health           # Перевірка здоров'я сервісів
make resources        # Використання ресурсів
make namespaces       # Список namespaces
make context          # Поточний контекст
```

### Швидкі команди

```bash
make up               # Запустити кластер + інфру
make down             # Зупинити інфру + кластер
make ps               # Alias для pods
make svc              # Alias для services
```

### Utilities

```bash
make clean            # Повне очищення
make reset            # Повний reset (clean + init)
make help             # Показати всі команди
```

## 🐛 Debugging

### Налаштування

Debug режим використовує [Delve](https://github.com/go-delve/delve) debugger.

### Запуск debug режиму

1. Запустити Skaffold в debug режимі:

```bash
make dev-debug
```

2. Debug порти автоматично пробрасуються:

   - `localhost:2345` → ecommerce-product-service
   - `localhost:2346` → ecommerce-category-service
   - `localhost:2347` → ecommerce-product-query-service
   - `localhost:2348` → ecommerce-category-query-service
   - `localhost:2349` → ecommerce-image-service

3. У VS Code:
   - Відкрити потрібний сервіс
   - Вибрати конфігурацію "Attach to K3D (service-name)"
   - Натиснути F5 або запустити дебаг
   - Встановити breakpoints

### Перевірка debug портів

```bash
make debug-check
```

## 🏗️ Структура

```
ecommerce-infrastructure/
├── docker/
│   ├── Dockerfile.local       # Dockerfile з Delve для debug
│   └── docker-compose/        # Локальна інфраструктура
│       ├── mongo.yml
│       └── kafka.yml
├── helm/
│   ├── ecommerce-go-service/  # Umbrella chart
│   │   ├── values.yaml        # Основні values
│   │   ├── values.debug.yaml  # Debug конфігурація
│   │   └── charts/            # Subcharts для кожного сервісу
│   ├── shared-helpers/        # Shared Helm templates
│   └── helm-values/           # Values для сторонніх charts
├── k3d-cluster.yaml           # K3d конфігурація
├── skaffold.yaml              # Skaffold конфігурація
└── Makefile                   # Makefile з усіма командами
```

## 🔄 Workflow

### Щоденна розробка

```bash
# Старт дня
make up                # Запустити кластер та інфраструктуру
make dev               # Запустити dev режим

# В процесі розробки
make logs SVC=product  # Дивитись логи
make pods              # Перевірити стан
make grafana           # Відкрити метрики

# Завершення дня
make down              # Зупинити все
```

### Debugging сесія

```bash
make dev-debug         # Запустити в debug режимі
# В VS Code: F5 для підключення
make debug-check       # Перевірити порти
```

### Проблеми?

```bash
make status            # Загальний статус
make events            # Останні події
make logs-all          # Всі логи
make cluster-reset     # Повний reset кластера
```

## 🌐 Доступ до сервісів

Після деплою сервіси доступні через Traefik Ingress:

- Product Service: http://ecommerce-product-service.127.0.0.1.nip.io
- Category Service: http://ecommerce-category-service.127.0.0.1.nip.io
- Product Query Service: http://ecommerce-product-query-service.127.0.0.1.nip.io
- Category Query Service: http://ecommerce-category-query-service.127.0.0.1.nip.io

Observability:

- Grafana: `make grafana` → http://localhost:3000
- Prometheus: `make prometheus` → http://localhost:9090
- Traefik Dashboard: `make traefik` → http://localhost:9000
- MinIO Console: `make minio` → http://localhost:9001

## 💡 Корисні поради

1. **Швидкий перегляд статусу**: `make status`
2. **Моніторинг логів**: Використовуйте `stern` через `make logs SVC=<name>`
3. **Debug в VS Code**: Конфігурації вже налаштовані в кожному сервісі
4. **Проблеми з build**: `make cluster-reset` для чистого старту
5. **Порти зайняті**: Перевірте `docker ps` та `kubectl get pods -A`

## 📝 Профілі Skaffold

- **default**: Звичайний режим без debug
- **debug**: Запуск через Delve debugger

Використання профілю:

```bash
skaffold dev -p debug
# або
make dev-debug
```
