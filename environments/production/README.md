# Production Environment

## Architecture

```
VPS (Hetzner CX22, 2 GB or CPX21, 4 GB)
└── k3s
    ├── namespace: prod
    │   ├── 5 Go services        (Helm charts)
    │   ├── 2 Nuxt UI            (Helm charts)
    │   ├── Redpanda             (Helm chart)
    │   ├── imgproxy             (Helm chart)
    │   └── Traefik + cert-manager
    ├── namespace: observability
    │   └── Grafana Alloy        (Helm chart, DaemonSet)
    │       → Grafana Cloud
    └── external services:
        ├── MongoDB Atlas (free)
        └── Cloudflare R2 (free)
```