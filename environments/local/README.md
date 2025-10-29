# Local Development Environment

Це середовище для локальної розробки з використанням K3d (Kubernetes in Docker).

## 📋 Компоненти

- **k3d-cluster.yaml** - конфігурація K3d кластера
- **skaffold.yaml** - конфігурація Skaffold для build/deploy/debug

## 🚀 Використання

### Запуск кластера

```bash
make cluster-create
```

### Розробка

```bash
make dev          # Звичайний режим з hot reload
make dev-debug    # Debug режим з Delve
```

### Деплой

```bash
make deploy       # Одноразовий деплой
```

## 🔧 Налаштування

### K3d кластер

- **Servers**: 1
- **Agents**: 2
- **Network**: shared-network
- **Ports**: 80, 443 (для Ingress)

### Skaffold

- **Build**: Local build без push
- **Deploy**: Helm charts
- **Debug**: Delve на портах 2345-2349

## 📝 Примітки

- Кластер використовує shared network для інтеграції з Docker Compose
- Traefik деактивований на рівні K3s (використовуємо свій Helm chart)
