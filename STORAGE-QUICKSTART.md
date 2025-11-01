# Швидкий старт з новою Storage конфігурацією

## 🚀 Що змінилося?

MinIO та imgproxy **перенесено з Kubernetes в Docker Compose** для спрощення локальної розробки.

## ⚡ Швидкий старт

```bash
cd /home/ihsokolo/projects/ecommerce/ecommerce-infrastructure

# 1. Запустити всю інфраструктуру (включно з MinIO та imgproxy)
make infra-up

# 2. Перевірити статус
docker compose -f docker/compose/storage.yml ps

# 3. Відкрити MinIO Console
make minio
# або http://localhost:9001 (minioadmin/minioadmin123)

# 4. Запустити сервіси в dev режимі
make dev
```

## 📦 Що запускається

**Docker Compose** (через `make infra-up`):
- ✅ MongoDB (порт 27017)
- ✅ Kafka + UI (порти 9092, 9093)
- ✅ **MinIO (порти 9000, 9001)** ← НОВЕ
- ✅ **imgproxy (порт 8081)** ← НОВЕ
- ✅ Observability (Grafana, Prometheus, Tempo)

**Kubernetes** (через `make dev` або `make deploy`):
- ✅ All ecommerce services
- ✅ Traefik ingress
- ✅ OTel Collector

## 🔗 Доступ до сервісів

| Сервіс | URL | Credentials |
|--------|-----|-------------|
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin123 |
| MinIO API | http://localhost:9000 | - |
| imgproxy | http://localhost:8081 | - |
| Grafana | http://localhost:3000 | admin / admin |
| Kafka UI | http://localhost:9093 | - |

## 📝 Корисні команди

```bash
# Перевірити всі контейнери
docker ps

# Логи storage сервісів
docker logs minio
docker logs imgproxy

# Логи всієї інфраструктури
make infra-logs

# Список файлів в MinIO
mc alias set myminio http://localhost:9000 minioadmin minioadmin123
mc ls myminio/products

# Завантажити файл в MinIO
mc cp image.jpg myminio/products/test/image.jpg

# Тест imgproxy
curl http://localhost:8081/health
curl http://localhost:8081/insecure/rs:fill:300:200/plain/s3://products/test/image.jpg -o resized.jpg
```

## 🔧 Конфігурація для сервісів

В `config.dev.yaml` для ecommerce-image-service:

```yaml
s3:
  endpoint: "http://host.k3d.internal:9000"  # ← через Docker network
  bucket: "products"
  
imgproxy:
  base-url: "http://host.k3d.internal:8081"  # ← через Docker network
```

## 📚 Детальна документація

- [STORAGE.md](docker/compose/STORAGE.md) - Повний гайд по storage стеку
- [MIGRATION-STORAGE.md](MIGRATION-STORAGE.md) - Деталі міграції з Kubernetes

## 🐛 Troubleshooting

**MinIO не доступний з pods:**
```bash
# Перевірити з поду
kubectl exec -it deployment/ecommerce-ecommerce-image-service -n dev -- \
  curl http://host.k3d.internal:9000/minio/health/live
```

**Порти зайняті:**
```bash
# Перевірити, що використовує порти
lsof -i :9000
lsof -i :9001
lsof -i :8081
```

**Повне очищення:**
```bash
make infra-clean  # Видаляє volumes
make infra-up     # Заново запускає
```

## ✅ Переваги нової архітектури

- 🚀 **Швидше**: MinIO стартує за секунди (vs хвилини в k8s)
- 💾 **Менше ресурсів**: Звільнено 350m CPU і 768Mi RAM в кластері
- 🔧 **Простіше**: Прямий доступ без port-forward
- 📦 **Персистентність**: Дані зберігаються в Docker volumes
- 🛠️ **Зручніше**: Легше дебажити та налаштовувати
