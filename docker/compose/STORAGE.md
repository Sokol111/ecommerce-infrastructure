# Storage Stack (Docker Compose)

MinIO та imgproxy для локальної розробки через Docker Compose.

## 🏗️ Архітектура

```
┌─────────────────────────────────────────────────────────┐
│              Docker Compose (shared-network)             │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐         ┌──────────────┐              │
│  │    MinIO     │         │   imgproxy   │              │
│  │  API: 9000   │◄────────│   port: 8081 │              │
│  │  Console:    │         │              │              │
│  │  9001        │         └──────────────┘              │
│  └──────────────┘                                        │
│                                                          │
└─────────────────────┼────────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────────────────────────┐
         │     K3d Cluster (shared-network)           │
         ├────────────────────────────────────────────┤
         │                                             │
         │  ┌──────────────────────────────────────┐  │
         │  │     ecommerce-image-service         │  │
         │  │   - Використовує MinIO через         │  │
         │  │     host.k3d.internal:9000           │  │
         │  │   - Генерує imgproxy URLs            │  │
         │  │     host.k3d.internal:8081           │  │
         │  └──────────────────────────────────────┘  │
         └────────────────────────────────────────────┘
```

## 📦 Компоненти

### MinIO (порти 9000, 9001)
- **Призначення**: S3-сумісне об'єктне сховище для зображень
- **Образ**: `minio/minio:latest`
- **API доступ**: http://localhost:9000
- **Console доступ**: http://localhost:9001
- **Логін**: minioadmin / minioadmin123
- **Бакет**: `products` (створюється автоматично)
- **Volume**: Persistent storage в `minio_data`

### MinIO Init Container
- **Призначення**: Автоматична ініціалізація MinIO
- **Образ**: `minio/mc:latest` (MinIO Client)
- **Дії**:
  - Створює alias для MinIO сервера
  - Створює бакет `products`
  - Встановлює policy `none` (приватний доступ)

### imgproxy (порт 8081)
- **Призначення**: On-the-fly обробка та оптимізація зображень
- **Образ**: `darthsim/imgproxy:v3.25`
- **Доступ**: http://localhost:8081
- **Джерело**: MinIO S3 bucket `products`
- **Features**:
  - WebP та AVIF detection
  - Resize, crop, blur, watermarks
  - Format conversion
  - URL signing для безпеки

## 🚀 Швидкий старт

### 1. Запустити storage стек

```bash
cd /home/ihsokolo/projects/ecommerce/ecommerce-infrastructure

# Запустити всю інфраструктуру (включно з storage)
make infra-up
```

### 2. Перевірити статус

```bash
# Перевірити запущені контейнери
docker compose -f docker/compose/storage.yml ps

# Або через загальну команду
docker ps | grep -E "minio|imgproxy"
```

### 3. Відкрити MinIO Console

```bash
make minio
# Або відкрийте браузер: http://localhost:9001
# Логін: minioadmin, Пароль: minioadmin123
```

## 📊 Використання

### MinIO - завантаження зображення

```bash
# Використовуючи AWS CLI
aws --endpoint-url http://localhost:9000 \
    s3 cp image.jpg s3://products/test/image.jpg

# Використовуючи MinIO Client (mc)
mc alias set myminio http://localhost:9000 minioadmin minioadmin123
mc cp image.jpg myminio/products/test/image.jpg
```

### MinIO - перегляд файлів

```bash
# Список файлів у бакеті
mc ls myminio/products

# Видалення файлу
mc rm myminio/products/test/image.jpg
```

### imgproxy - обробка зображень

```bash
# Health check
curl http://localhost:8081/health

# Resize зображення (300x200, fill mode)
# URL format: /insecure/{processing_options}/plain/s3://{bucket}/{key}
curl http://localhost:8081/insecure/rs:fill:300:200/plain/s3://products/test/image.jpg -o resized.jpg

# WebP conversion з resize
curl http://localhost:8081/insecure/rs:fit:800:600/plain/s3://products/test/image.jpg@webp -o image.webp

# Більше опцій: blur, watermark, crop, quality
# https://docs.imgproxy.net/
```

## 🔄 Workflow з K3d

### Доступ з Kubernetes pods

Сервіси в k3d кластері можуть звертатися до MinIO та imgproxy через `host.k3d.internal`:

```yaml
# config.dev.yaml в ecommerce-image-service
s3:
  endpoint: "http://host.k3d.internal:9000"
  bucket: "products"
  access-key-id: "minioadmin"
  secret-key: "minioadmin123"

imgproxy:
  base-url: "http://host.k3d.internal:8081"
```

### Чому не в Kubernetes?

Переваги Docker Compose для storage:
- ✅ **Простіше**: Не потрібні Helm charts, PV, PVC
- ✅ **Швидше**: Миттєвий старт без деплоїв в k8s
- ✅ **Ізольовано**: Не займає ресурси кластера
- ✅ **Персистентність**: Volumes зберігаються між перезапусками
- ✅ **Доступність**: Прямий доступ з host машини

## 🛠️ Команди Makefile

```bash
# Запустити storage стек (частина infra-up)
make infra-up

# Зупинити storage стек
make infra-down

# Перезапустити
make infra-restart

# Повне очищення (включно з volumes)
make infra-clean

# Відкрити MinIO Console
make minio

# Показати інформацію про imgproxy
make imgproxy-info

# Логи storage сервісів
make infra-logs
```

## 🔧 Конфігурація

### MinIO Environment Variables

```yaml
MINIO_ROOT_USER: minioadmin
MINIO_ROOT_PASSWORD: minioadmin123
MINIO_REGION_NAME: us-east-1
```

### imgproxy Environment Variables

```yaml
# S3 Config
IMGPROXY_USE_S3: "true"
IMGPROXY_S3_ENDPOINT: http://minio:9000
IMGPROXY_S3_REGION: us-east-1

# Security (для development використовуються тестові ключі)
IMGPROXY_KEY: "0000...0000"
IMGPROXY_SALT: "1111...1111"

# Features
IMGPROXY_ENABLE_WEBP_DETECTION: "true"
IMGPROXY_ENABLE_AVIF_DETECTION: "true"
```

## 📝 Troubleshooting

### MinIO не запускається

1. Перевірте, чи зайнятий порт 9000 або 9001:
   ```bash
   lsof -i :9000
   lsof -i :9001
   ```

2. Перевірте логи:
   ```bash
   docker logs minio
   ```

### imgproxy не може підключитися до MinIO

1. Перевірте health MinIO:
   ```bash
   curl http://localhost:9000/minio/health/live
   ```

2. Перевірте мережу:
   ```bash
   docker network inspect shared-network
   ```

3. Перевірте логи imgproxy:
   ```bash
   docker logs imgproxy
   ```

### image-service не може підключитися до MinIO

1. Переконайтеся, що k3d використовує `shared-network`:
   ```bash
   docker inspect k3d-dev-cluster-server-0 | grep NetworkMode
   ```

2. Перевірте DNS з поду:
   ```bash
   kubectl exec -it <image-service-pod> -n dev -- nslookup host.k3d.internal
   ```

3. Перевірте доступність з поду:
   ```bash
   kubectl exec -it <image-service-pod> -n dev -- curl http://host.k3d.internal:9000/minio/health/live
   ```

## 🔍 Корисні команди

### MinIO Client (mc)

```bash
# Налаштування alias
mc alias set myminio http://localhost:9000 minioadmin minioadmin123

# Створення бакета
mc mb myminio/newbucket

# Встановлення anonymous policy
mc anonymous set download myminio/products

# Статистика використання
mc admin info myminio
```

### imgproxy testing

```bash
# Тест URL signing (для production)
# Generate signature: https://docs.imgproxy.net/usage/signing_url

# Development (insecure URLs)
curl http://localhost:8081/insecure/rs:fill:100:100/plain/s3://products/test.jpg
```

## 🔐 Security Notes

⚠️ **Важливо для production:**

1. **MinIO credentials**: Змініть `minioadmin/minioadmin123` на сильні паролі
2. **imgproxy keys**: Згенерутйе нові KEY та SALT (не `0000...` та `1111...`)
3. **Network exposure**: Не експозьте MinIO/imgproxy публічно без TLS
4. **Bucket policies**: Налаштуйте правильні access policies

```bash
# Генерація ключів для imgproxy
echo $(xxd -g 2 -l 64 -p /dev/random | tr -d '\n')  # KEY
echo $(xxd -g 2 -l 64 -p /dev/random | tr -d '\n')  # SALT
```

## 📚 Посилання

- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [MinIO Client (mc) Guide](https://min.io/docs/minio/linux/reference/minio-mc.html)
- [imgproxy Documentation](https://docs.imgproxy.net/)
- [imgproxy Processing Options](https://docs.imgproxy.net/usage/processing)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
