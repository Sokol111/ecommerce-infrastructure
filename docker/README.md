# Docker Build Configuration

## Dockerfiles

### Dockerfile.local

Multi-mode Dockerfile що підтримує два режими збірки:

#### 1. DEV mode (default)

- **Оптимізована збірка** без debug символів
- **Швидша збірка** (без Delve та debug info)
- **CGO_ENABLED=1** (потрібно для confluent-kafka-go)
- **Без Delve debugger**

```bash
# Через Skaffold
make dev

# Через Docker напряму
docker build \
  --build-arg SERVICE_DIR=ecommerce-product-service \
  --build-arg BUILD_MODE=dev \
  -f docker/Dockerfile.local \
  -t product-service:dev .
```

#### 2. DEBUG mode

- **Збірка з debug символами** (`-gcflags="all=-N -l"`)
- **Включає Delve debugger** (`/dlv`)
- **CGO_ENABLED=1** для підтримки debug
- **Port 2345** для remote debugging

```bash
# Через Skaffold
make dev-debug

# Через Docker напряму
docker build \
  --build-arg SERVICE_DIR=ecommerce-product-service \
  --build-arg BUILD_MODE=debug \
  -f docker/Dockerfile.local \
  -t product-service:debug .
```

## Build Arguments

| Argument        | Required | Default             | Description                                         |
| --------------- | -------- | ------------------- | --------------------------------------------------- |
| `SERVICE_DIR`   | ✅ Yes   | `service-dir`       | Шлях до сервісу (e.g., `ecommerce-product-service`) |
| `COMMONS_DIR`   | No       | `ecommerce-commons` | Шлях до спільного коду                              |
| `BUILD_MODE`    | No       | `dev`               | Режим збірки: `dev` або `debug`                     |
| `GO_IMAGE`      | No       | `golang:1.24.2`     | Base Go image                                       |
| `RUNTIME_IMAGE` | No       | `ubuntu:24.04`      | Runtime image                                       |

## Порівняння режимів

| Характеристика   | DEV mode                     | DEBUG mode         |
| ---------------- | ---------------------------- | ------------------ |
| Debug символи    | ❌ Ні                        | ✅ Так             |
| Delve debugger   | ❌ Ні                        | ✅ Так (`/dlv`)    |
| CGO              | Enabled (confluent-kafka-go) | Enabled            |
| Розмір image     | Менший (~350MB)              | Більший (~400MB)   |
| Швидкість збірки | Швидше                       | Повільніше         |
| Оптимізація      | ✅ Так                       | ❌ Ні              |
| Remote debugging | ❌ Ні                        | ✅ Так (port 2345) |

## Використання в Skaffold

### DEV mode (default)

```yaml
build:
  artifacts:
    - image: sokol111/ecommerce-product-service
      docker:
        buildArgs:
          SERVICE_DIR: ecommerce-product-service
          BUILD_MODE: dev # або без цього рядка (default)
```

### DEBUG mode (profile)

```yaml
profiles:
  - name: debug
    build:
      artifacts:
        - image: sokol111/ecommerce-product-service
          docker:
            buildArgs:
              BUILD_MODE: debug
```

## Debug Workflow

### 1. Запуск в debug режимі

```bash
make dev-debug
# або
skaffold dev -p debug
```

### 2. Підключення debugger

**VS Code:**

```json
{
  "name": "Attach to K3D (product-service)",
  "type": "go",
  "request": "attach",
  "mode": "remote",
  "remotePath": "/src/svc",
  "port": 2345,
  "host": "localhost"
}
```

**Delve CLI:**

```bash
dlv connect localhost:2345
```

### 3. Debug порти

| Service                | Port |
| ---------------------- | ---- |
| product-service        | 2345 |
| category-service       | 2346 |
| product-query-service  | 2347 |
| category-query-service | 2348 |
| image-service          | 2349 |

## Dockerfile.go

Продакшн Dockerfile (якщо потрібен):

- Multi-stage build
- Мінімальний runtime image (alpine/scratch)
- Оптимізована збірка
- Без debug інструментів

## Структура

```
docker/
├── Dockerfile.local      # Dev + Debug modes
├── Dockerfile.go         # Production (if needed)
└── compose/              # Docker Compose для локальної інфраструктури
    ├── mongo.yml
    ├── kafka.yml
    └── .env.example
```

## Важливо: CGO залежності

Проект використовує `confluent-kafka-go`, який потребує CGO. Тому:

- ✅ CGO **завжди** увімкнений (`CGO_ENABLED=1`) в обох режимах
- ⚠️ Runtime image має бути Ubuntu/Debian (не alpine/scratch)
- 📦 Librdkafka має бути встановлена в runtime image

Якщо у майбутньому потрібен static binary без CGO:

1. Замініть `confluent-kafka-go` на pure Go Kafka client (наприклад, `segmentio/kafka-go`)
2. Використовуйте `CGO_ENABLED=0` для DEV mode
3. Розгляньте alpine/scratch як runtime image

## Tips

### Швидка збірка

```bash
# Використовувати BuildKit
export DOCKER_BUILDKIT=1

# Або в daemon.json
{
  "features": {
    "buildkit": true
  }
}
```

### Cache оптимізація

Dockerfile вже оптимізований:

1. Спочатку копіюємо `go.mod`/`go.sum`
2. `go mod download` (кешується якщо dependencies не змінились)
3. Потім копіюємо код

### Перевірка BUILD_MODE

```bash
# В контейнері
docker run --rm product-service:dev /server --version

# Перевірити чи є Delve
docker run --rm product-service:debug ls -la /dlv
```

## Troubleshooting

### Delve не встановлюється

```dockerfile
# Перевірте версію Go
ARG GO_IMAGE=golang:1.24.2  # Має підтримувати Delve
```

### Image занадто великий

- Використовуйте DEV mode замість DEBUG
- Розгляньте alpine/scratch для production
- Видаліть непотрібні файли у runtime stage

### Debug не працює

```bash
# Перевірте порт
make debug-check

# Перевірте чи запущений Delve
kubectl logs <pod-name> -n dev | grep dlv

# Перевірте BUILD_MODE
docker inspect <image> | grep BUILD_MODE
```
