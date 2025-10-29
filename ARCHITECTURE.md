# E-commerce Infrastructure Architecture

## 🎯 Огляд

Інфраструктурний проект для мікросервісної e-commerce платформи на базі Kubernetes (K3d), Skaffold та Helm.

## 🏗️ Архітектурні принципи

### Infrastructure as Code

- **K3d** для локального Kubernetes кластера
- **Helm** для package management
- **Skaffold** для automation build/deploy циклу
- **Docker Compose** для локальних залежностей (MongoDB, Kafka)

### Observability First

- **Grafana** - візуалізація метрик та логів
- **Prometheus** - збір метрик
- **Loki** - агрегація логів
- **Tempo** - distributed tracing
- **OpenTelemetry Collector** - збір телеметрії

## 📊 Компоненти

### Kubernetes Cluster (K3d)

```
┌─────────────────────────────────────┐
│   K3d Cluster (dev-cluster)         │
├─────────────────────────────────────┤
│  • 1 Server node                    │
│  • 2 Agent nodes                    │
│  • Shared network з Docker          │
│  • Ports: 80, 443 (Ingress)         │
└─────────────────────────────────────┘
```

### Namespaces

| Namespace       | Призначення         | Сервіси                                  |
| --------------- | ------------------- | ---------------------------------------- |
| `dev`           | Application сервіси | product, category, image, query services |
| `observability` | Monitoring stack    | Grafana, Prometheus, Loki, Tempo, OTel   |
| `traefik`       | Ingress controller  | Traefik                                  |
| `minio`         | Object storage      | MinIO                                    |
| `imgproxy`      | Image processing    | ImgProxy                                 |

### Application Services

```
┌──────────────────────────────────────────────────┐
│              Application Layer                    │
├──────────────────────────────────────────────────┤
│                                                   │
│  ┌─────────────────┐  ┌──────────────────┐      │
│  │ Product Service │  │ Category Service │      │
│  │  (Command)      │  │   (Command)      │      │
│  └────────┬────────┘  └────────┬─────────┘      │
│           │                     │                 │
│           └──────────┬──────────┘                │
│                      │                            │
│            ┌─────────▼─────────┐                 │
│            │   Kafka (Events)  │                 │
│            └─────────┬─────────┘                 │
│                      │                            │
│           ┌──────────┴──────────┐                │
│           │                     │                 │
│  ┌────────▼────────┐  ┌────────▼────────┐       │
│  │ Product Query   │  │ Category Query  │       │
│  │    Service      │  │    Service      │       │
│  └─────────────────┘  └─────────────────┘       │
│                                                   │
│  ┌─────────────────┐                             │
│  │  Image Service  │                             │
│  └────────┬────────┘                             │
│           │                                       │
│      ┌────▼────┐                                 │
│      │  MinIO  │                                 │
│      └─────────┘                                 │
└──────────────────────────────────────────────────┘
```

### Data Layer

```
┌──────────────────────────────────────┐
│         Data Persistence              │
├──────────────────────────────────────┤
│                                       │
│  ┌──────────┐      ┌──────────┐     │
│  │ MongoDB  │      │  Kafka   │     │
│  │ (Docker) │      │ (Docker) │     │
│  └──────────┘      └──────────┘     │
│                                       │
│  • Replica Set     • KRaft mode      │
│  • Port: 27017     • Port: 9092      │
│                    • UI: 9093        │
└──────────────────────────────────────┘
```

### Ingress & Routing

```
                    Internet
                       │
                       ▼
              ┌────────────────┐
              │  Traefik       │
              │  (Ingress)     │
              └────────┬───────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
  ┌─────────┐   ┌─────────┐   ┌─────────┐
  │Product  │   │Category │   │ Image   │
  │Service  │   │Service  │   │ Service │
  └─────────┘   └─────────┘   └─────────┘
```

### Observability Stack

```
┌────────────────────────────────────────────┐
│          Observability Pipeline             │
├────────────────────────────────────────────┤
│                                             │
│  Application Services                       │
│         │                                   │
│         ▼                                   │
│  ┌──────────────────┐                      │
│  │ OpenTelemetry    │                      │
│  │   Collector      │                      │
│  └────┬────┬────┬───┘                      │
│       │    │    │                           │
│   ┌───┘    │    └───┐                      │
│   │        │        │                       │
│   ▼        ▼        ▼                       │
│ ┌────┐  ┌────┐  ┌─────┐                    │
│ │Loki│  │Tempo│  │Prom │                   │
│ └──┬─┘  └──┬─┘  └──┬──┘                    │
│    │       │       │                        │
│    └───────┴───────┘                        │
│            │                                 │
│            ▼                                 │
│      ┌──────────┐                           │
│      │ Grafana  │                           │
│      └──────────┘                           │
└────────────────────────────────────────────┘
```

## 🔄 Development Workflow

### Local Development

```bash
# 1. Запустити інфраструктуру
make infra-up

# 2. Створити кластер
make cluster-create

# 3. Розробка з hot reload
make dev

# 4. Debug режим (опціонально)
make dev-debug
```

### Build & Deploy Process

```
┌────────────┐
│   Code     │
│  Changes   │
└─────┬──────┘
      │
      ▼
┌─────────────┐
│  Skaffold   │ ◄─── skaffold.yaml
│   Watches   │
└─────┬───────┘
      │
      ├─────────────────────┬─────────────────┐
      │                     │                 │
      ▼                     ▼                 ▼
┌──────────┐         ┌──────────┐      ┌──────────┐
│  Build   │         │  Build   │      │  Build   │
│ Product  │         │ Category │      │  Image   │
│ Service  │         │ Service  │      │ Service  │
└────┬─────┘         └────┬─────┘      └────┬─────┘
     │                    │                   │
     └────────────────────┼───────────────────┘
                          │
                          ▼
                   ┌──────────────┐
                   │ Load to K3d  │
                   └──────┬───────┘
                          │
                          ▼
                   ┌──────────────┐
                   │ Helm Deploy  │
                   └──────┬───────┘
                          │
                          ▼
                   ┌──────────────┐
                   │  Running in  │
                   │  Kubernetes  │
                   └──────────────┘
```

## 🗂️ Структура проекту

```
ecommerce-infrastructure/
├── environments/           # Конфігурації середовищ
│   └── local/             # Local development
│       ├── k3d-cluster.yaml
│       ├── skaffold.yaml
│       └── README.md
│
├── docker/                # Docker artifacts
│   ├── Dockerfile.go
│   ├── Dockerfile.local   # З Delve для debug
│   └── compose/           # Локальні залежності
│       ├── mongo.yml
│       ├── kafka.yml
│       └── .env.example
│
├── helm/                  # Helm charts
│   ├── ecommerce-go-service/  # Umbrella chart
│   ├── shared-helpers/        # Shared templates
│   └── values/                # Організовані values
│       ├── infrastructure/
│       ├── observability/
│       ├── storage/
│       └── misc/
│
├── scripts/               # Utility scripts
│   ├── setup/            # Setup & checks
│   └── monitoring/       # Monitoring tools
│
└── docs/                 # Документація
    ├── setup/
    ├── architecture/
    └── runbooks/
```

## 🔒 Security

### Network Policies

- Pods комунікують тільки в межах namespace
- External доступ через Ingress

### Secrets Management

- Kubernetes Secrets для sensitive data
- `.env` файли для локальної розробки (не в git)

## 📈 Scalability

### Horizontal Pod Autoscaling

- Готові до HPA manifests
- Metrics через Prometheus

### Resource Limits

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

## 🚀 Future Enhancements

- [ ] Production environment (EKS/GKE)
- [ ] GitOps з ArgoCD/Flux
- [ ] Service Mesh (Istio/Linkerd)
- [ ] Automated backups
- [ ] Disaster recovery procedures
- [ ] Multi-region support

## 📚 Додаткові ресурси

- [Setup Guide](docs/setup/quickstart.md)
- [Troubleshooting](docs/runbooks/troubleshooting.md)
- [Main README](README.md)
