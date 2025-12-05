# Troubleshooting Guide

Посібник з вирішення типових проблем при роботі з ecommerce-infrastructure.

## 🔍 Діагностика

### Швидка перевірка системи

```bash
# Статус кластера
make status

# Події
make events

# Ресурси
make resources
```

## 🚨 Типові проблеми

### 1. Кластер не створюється

#### Симптоми

```bash
$ make cluster
Error: Failed to create cluster 'dev-cluster'
```

#### Можливі причини та рішення

**A. Docker не запущений**

```bash
# Перевірка
docker ps

# Рішення
sudo systemctl start docker
# або
open -a Docker  # macOS
```

**B. Порти вже зайняті**

```bash
# Перевірка
sudo lsof -i :80
sudo lsof -i :443

# Рішення: Зупинити процеси на портах або змінити порти в k3d-cluster.yaml
```

**C. Старий кластер існує**

```bash
# Перевірка
k3d cluster list

# Рішення
make cluster-delete
make cluster
```

---

### 2. Pods не стартують

#### Симптоми

```bash
$ make pods
NAME                                    READY   STATUS             RESTARTS
ecommerce-product-service-xxx           0/1     CrashLoopBackOff   5
```

#### Діагностика

```bash
# 1. Подивитися деталі
make describe POD=ecommerce-product-service-xxx

# 2. Подивитися логи
make logs SVC=product

# 3. Події
make events
```

#### Можливі причини

**A. Image не може побудуватись**

```bash
# Логи Skaffold
# При `make dev` дивіться output

# Рішення: Перевірте Dockerfile та build context
```

**B. Проблеми з конфігурацією**

```bash
# Перевірте ConfigMap/Secrets
kubectl get configmap -n dev
kubectl describe configmap <name> -n dev

# Перевірте змінні середовища
kubectl describe pod <pod-name> -n dev | grep -A 20 "Environment"
```

**C. Недостатньо ресурсів**

```bash
# Перевірка
make resources

# Рішення: Збільшити ресурси Docker Desktop
# Settings → Resources → Memory/CPU
```

**D. MongoDB/Kafka недоступні**

```bash
# Перевірка локальної інфраструктури
docker ps | grep mongo
docker ps | grep kafka

# Рішення
make infra-restart
```

---

### 3. Skaffold dev падає

#### Симптоми

```bash
$ make dev
Error: build failed
```

#### Рішення

**A. Очистити build cache**

```bash
# Docker
docker system prune -a

# Skaffold
skaffold cache clean
```

**B. Перевірити context**

```bash
# Має бути відносний шлях від skaffold.yaml
# В environments/local/skaffold.yaml:
context: ../..  # Вказує на root проекту
```

**C. Перевірити шляхи в artifacts**

```yaml
artifacts:
  - image: sokol111/ecommerce-product-service
    context: ../.. # Від skaffold.yaml до root
    docker:
      dockerfile: ecommerce-infrastructure/docker/Dockerfile.local
```

---

### 4. Ingress не працює

#### Симптоми

```bash
# Не доступний через URL
$ curl http://ecommerce-product-service.127.0.0.1.nip.io
curl: (7) Failed to connect
```

#### Діагностика

```bash
# Перевірити Traefik
kubectl get pods -n traefik
make ingress

# Перевірити правила
kubectl describe ingress -n dev
```

#### Рішення

**A. Traefik не запущений**

```bash
# Перевірка
kubectl get pods -n traefik

# Перезапуск
kubectl rollout restart deployment/traefik -n traefik
```

**B. Порти не прокинуті**

```bash
# Перевірка K3d конфігурації
cat environments/local/k3d-cluster.yaml

# Має бути:
ports:
  - port: "80:80"
    nodeFilters:
      - loadbalancer
  - port: "443:443"
    nodeFilters:
      - loadbalancer
```

**C. Service не існує**

```bash
# Перевірка
make services

# Якщо немає - перевірити Helm chart
helm list -n dev
helm get values ecommerce -n dev
```

---

### 5. Debug порти недоступні

#### Симптоми

```bash
$ make debug-check
✗ Port 2345 - not accessible
```

#### Рішення

**A. Запустити в debug режимі**

```bash
make dev-debug
```

**B. Перевірити port-forward в skaffold.yaml**

```yaml
portForward:
  - resourceType: service
    resourceName: ecommerce-product-service
    namespace: dev
    port: 2345
    localPort: 2345
```

**C. Перевірити що Delve запущений в поді**

```bash
# Логи пода
make logs SVC=product

# Очікуємо:
# API server listening at: [::]:2345
```

---

### 6. MongoDB connection failed

#### Симптоми

```
Error: failed to connect to MongoDB: no reachable servers
```

#### Діагностика

```bash
# Перевірка MongoDB
docker ps | grep mongo
docker logs mongo

# Перевірка connection string в сервісі
kubectl get pod <pod-name> -n dev -o yaml | grep MONGO
```

#### Рішення

**A. MongoDB не запущений**

```bash
make infra-up
```

**B. Replica set не ініціалізований**

```bash
# Перевірка
docker exec -it mongo mongosh --eval "rs.status()"

# Ініціалізація (має відбуватися автоматично через healthcheck)
docker compose -f docker/compose/mongo.yml restart
```

**C. Network проблеми**

```bash
# Перевірка network
docker network ls | grep shared-network

# Створити якщо немає
docker network create shared-network

# Перезапустити
make infra-restart
```

---

### 7. Kafka connection issues

#### Симптоми

```
Error: kafka: client has run out of available brokers
```

#### Рішення

**A. Kafka не запущений**

```bash
docker ps | grep kafka
make infra-up
```

**B. Перевірити порт**

```bash
# Kafka має бути на localhost:9092
netstat -an | grep 9092

# Або
lsof -i :9092
```

**C. Перевірити listeners**

```bash
docker logs kafka | grep -i listener
```

---

### 8. Helm chart помилки

#### Симптоми

```bash
Error: INSTALLATION FAILED: unable to build kubernetes objects
```

#### Діагностика

```bash
# Шаблон без деплою
make helm-template

# Перевірка values
make helm-values-all

# Lint
helm lint helm/ecommerce-go-service
```

#### Рішення

**A. Невалідний YAML**

```bash
# Перевірка синтаксису
yamllint helm/ecommerce-go-service/values.yaml
```

**B. Відсутні залежності**

```bash
# Оновити залежності
helm dependency update helm/ecommerce-go-service
```

**C. Невірні values files шляхи**

```bash
# Перевірити в skaffold.yaml
# Шляхи мають бути відносно root проекту
valuesFiles: [helm/values/observability/grafana.yaml]
```

---

### 9. Out of disk space

#### Симптоми

```
Error: no space left on device
```

#### Рішення

```bash
# Очистити Docker
docker system prune -a --volumes

# Очистити build cache
docker builder prune -a

# Очистити k3d volumes
make cluster-delete

# Перевірити розмір
docker system df
```

---

### 10. Повільна збірка

#### Оптимізація

**A. Використовувати BuildKit**

```bash
# Вже налаштовано в Dockerfile.local
# syntax=docker/dockerfile:1
```

**B. Multi-stage builds**

```dockerfile
# Вже використовується
FROM golang:1.23-alpine AS builder
# ...
FROM alpine:latest
```

**C. Cache dependencies**

```dockerfile
# Спочатку копіюємо go.mod/go.sum
COPY go.mod go.sum ./
RUN go mod download
# Потім код
COPY . .
```

---

## 🔧 Загальні команди діагностики

### Kubernetes

```bash
# Всі ресурси в namespace
kubectl get all -n dev

# Логи пода
kubectl logs <pod-name> -n dev -f

# Shell в поді
kubectl exec -it <pod-name> -n dev -- /bin/sh

# Describe для деталей
kubectl describe pod <pod-name> -n dev

# Top pods (потрібен metrics-server)
kubectl top pods -n dev

# События
kubectl get events -n dev --sort-by='.lastTimestamp'
```

### Docker

```bash
# Активні контейнери
docker ps

# Всі контейнери
docker ps -a

# Логи
docker logs <container-name> -f

# Інспекція
docker inspect <container-name>

# Networks
docker network ls
docker network inspect shared-network

# Volumes
docker volume ls
```

### Helm

```bash
# Список релізів
helm list -A

# Статус
helm status <release-name> -n <namespace>

# Values
helm get values <release-name> -n <namespace>

# Manifest
helm get manifest <release-name> -n <namespace>

# History
helm history <release-name> -n <namespace>

# Rollback
helm rollback <release-name> <revision> -n <namespace>
```

---

## 🆘 Коли нічого не допомагає

### Nuclear Option: Повний reset

```bash
# 1. Зупинити все
make down

# 2. Видалити кластер
make cluster-delete

# 3. Очистити Docker
docker system prune -a --volumes

# 4. Видалити volumes
make infra-clean

# 5. Перезапустити Docker
sudo systemctl restart docker

# 6. Почати з нуля
make init
```

---

## 📊 Моніторинг здоров'я системи

### Grafana Dashboards

```bash
make grafana
# → http://localhost:3000
```

Перевірте дашборди:

- **Kubernetes / Pods** - стан подів
- **Kubernetes / Nodes** - ресурси нод
- **Application Metrics** - метрики сервісів

### Prometheus Queries

```bash
make prometheus
# → http://localhost:9090
```

Корисні запити:

```promql
# CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# Pod restarts
kube_pod_container_status_restarts_total
```

---

## 📝 Логування проблем

При зверненні по допомогу, надайте:

```bash
# 1. Версії інструментів
make tools-check

# 2. Статус системи
make status

# 3. Логи проблемного сервісу
make logs SVC=<service-name> > service.log

# 4. Події
make events > events.log

# 5. Describe пода
kubectl describe pod <pod-name> -n dev > pod-describe.txt
```

---

## 💡 Превентивні заходи

1. **Регулярно оновлюйте інструменти**

   ```bash
   # Homebrew (macOS)
   brew upgrade k3d kubectl skaffold helm
   ```

2. **Очищайте build cache**

   ```bash
   # Раз на тиждень
   docker system prune
   ```

3. **Моніторте ресурси**

   ```bash
   make resources
   ```

4. **Перевіряйте логи**
   ```bash
   make logs-all
   ```

---

## 🔗 Додаткові ресурси

- [K3d Documentation](https://k3d.io/)
- [Skaffold Troubleshooting](https://skaffold.dev/docs/workflows/debug/)
- [Helm Troubleshooting](https://helm.sh/docs/faq/troubleshooting/)
- [Kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
