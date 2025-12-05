# Quick Start Guide

Швидкий старт для локальної розробки з ecommerce-infrastructure.

## 📋 Передумови

### Необхідні інструменти

- **Docker** (v24+) та Docker Compose
- **k3d** (v5.x)
- **kubectl** (v1.28+)
- **Skaffold** (v2.x)
- **Helm** (v3.x)
- **stern** (опціонально, для логів)
- **make**

### Перевірка інструментів

```bash
make tools-check
```

## 🚀 Швидкий старт (5 хвилин)

### 1. Клонування репозиторію

```bash
cd /path/to/your/workspace
# Проект вже має бути клонований у вашій workspace
```

### 2. Повна ініціалізація

```bash
make init
```

Ця команда:

- ✅ Створить K3d кластер
- ✅ Запустить локальну інфраструктуру (MongoDB, Kafka)
- ✅ Задеплоїть всі сервіси та observability stack

**Час виконання:** ~3-5 хвилин

### 3. Перевірка статусу

```bash
make status
```

Очікуваний вивід:

```
→ K3d Cluster Status:
NAME          SERVERS   AGENTS   LOADBALANCER
dev-cluster   1/1       2/2      true

→ Deployments in 'dev':
NAME                              READY   UP-TO-DATE   AVAILABLE
ecommerce-product-service         1/1     1            1
ecommerce-category-service        1/1     1            1
...
```

## 💻 Режими роботи

### Development Mode (рекомендований)

Автоматична пересборка та деплой при зміні коду:

```bash
make dev
```

**Що відбувається:**

- Skaffold спостерігає за змінами в коді
- При зміні автоматично:
  - Пересобирає Docker image
  - Оновлює pod в Kubernetes
  - Показує логи

**Вихід:** `Ctrl+C`

### Debug Mode

З підтримкою Delve debugger:

```bash
make dev-debug
```

**Debug порти:**

- `localhost:2345` → product-service
- `localhost:2346` → category-service
- `localhost:2347` → product-query-service
- `localhost:2348` → category-query-service
- `localhost:2349` → image-service

**VS Code:** Використовуйте конфігурацію "Attach to K3D" з `.vscode/launch.json`

## 🔍 Корисні команди

### Перегляд логів

```bash
# Логи конкретного сервісу
make logs SVC=product

# Всі логи
make logs-all

# Інтерактивний вибір
make logs-select
```

### Управління подами

```bash
# Список подів
make pods

# Деталі пода
make describe POD=ecommerce-product-service-xxx

# Shell в поді
make exec POD=ecommerce-product-service-xxx

# Перезапуск deployment
make restart DEP=ecommerce-product-service
```

### Observability

```bash
# Grafana
make grafana
# Відкрити: http://localhost:3000

# Prometheus
make prometheus
# Відкрити: http://localhost:9090

# Traefik Dashboard
make traefik
# Відкрити: http://localhost:9000

# MinIO Console
make minio
# Відкрити: http://localhost:9001
```

## 🌐 Доступ до сервісів

### Через Ingress (Traefik)

- Product Service: http://ecommerce-product-service.127.0.0.1.nip.io
- Category Service: http://ecommerce-category-service.127.0.0.1.nip.io
- Product Query: http://ecommerce-product-query-service.127.0.0.1.nip.io
- Category Query: http://ecommerce-category-query-service.127.0.0.1.nip.io

### Локальна інфраструктура

- MongoDB: `mongodb://localhost:27017`
- Kafka: `localhost:9092`
- Kafka UI: http://localhost:9093

## 🛠️ Управління інфраструктурою

### Локальні сервіси (Docker Compose)

```bash
# Запуск
make infra-up

# Зупинка
make infra-down

# Перезапуск
make infra-restart

# Логи
make infra-logs

# Повне очищення (видалити volumes)
make infra-clean
```

### Kubernetes кластер

```bash
# Запустити
make cluster-start

# Зупинити
make cluster-stop

# Пересворити
make cluster-reset

# Видалити
make cluster-delete
```

## 📝 Щоденний Workflow

### Початок дня

```bash
# Запустити все
make up

# Або окремо
make cluster-start
make infra-up
make dev
```

### Робота з кодом

1. Внести зміни в сервісі
2. Skaffold автоматично пересобере та задеплоїть
3. Перевірити логи: `make logs SVC=product`
4. Тестувати через Ingress URL

### Завершення дня

```bash
# Зупинити все
make down

# Або тільки кластер
make cluster-stop
```

## 🐛 Troubleshooting

### Проблема: Порти зайняті

```bash
# Перевірити що використовує порти
sudo lsof -i :80
sudo lsof -i :443

# Або
make status
```

### Проблема: Pods не стартують

```bash
# Перевірити статус
make pods

# Подивитися події
make events

# Деталі пода
make describe POD=<pod-name>

# Логи
make logs SVC=<service-name>
```

### Проблема: Build помилки

```bash
# Повний reset
make cluster-reset

# Перезапустити dev mode
make dev
```

### Проблема: Немає доступу до сервісів

```bash
# Перевірити Ingress
make ingress

# Перевірити сервіси
make services

# Перевірити Traefik
kubectl get pods -n traefik
```

## 🧹 Очищення

### Видалити деплоймент

```bash
make undeploy
```

### Повне очищення

```bash
make clean
```

Це видалить:

- Kubernetes кластер
- Docker Compose volumes
- Всі дані

### Повний reset

```bash
make reset
```

Еквівалент: `make clean && make init`

## 📚 Наступні кроки

- Ознайомтесь з [Architecture](../../ARCHITECTURE.md)
- Прочитайте [Troubleshooting Guide](../runbooks/troubleshooting.md)
- Налаштуйте Debug в VS Code
- Додайте custom Grafana дашборди

## 💡 Поради

1. **Використовуйте `stern`** для зручного перегляду логів:

   ```bash
   stern product -n dev
   ```

2. **Налаштуйте aliases** в `.bashrc` / `.zshrc`:

   ```bash
   alias k='kubectl'
   alias kgp='kubectl get pods -n dev'
   alias kgs='kubectl get services -n dev'
   ```

3. **Використовуйте `watch`** для моніторингу:

   ```bash
   watch -n 2 'kubectl get pods -n dev'
   ```

4. **Збережіть контекст**:
   ```bash
   kubectl config use-context k3d-dev-cluster
   ```

## ❓ Потрібна допомога?

- Перевірте [Troubleshooting](../runbooks/troubleshooting.md)
- Запустіть `make help` для списку команд
- Перевірте логи: `make logs-all`
