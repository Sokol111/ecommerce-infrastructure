# E-Commerce Production Deployment

Production deployment configuration for the e-commerce platform using Docker Compose on a VPS.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet                                        │
│                                  │                                           │
│                                  ▼                                           │
│                         ┌───────────────┐                                   │
│                         │    Traefik    │ :80, :443                         │
│                         │  (SSL + LB)   │                                   │
│                         └───────┬───────┘                                   │
│                                 │                                           │
│         ┌───────────────────────┼───────────────────────┐                   │
│         │                       │                       │                   │
│         ▼                       ▼                       ▼                   │
│  ┌─────────────┐      ┌─────────────────┐      ┌─────────────┐             │
│  │ ecommerce-ui│      │   api.domain/*  │      │  admin-ui   │             │
│  │   (Next.js) │      │                 │      │  (Next.js)  │             │
│  └─────────────┘      └────────┬────────┘      └─────────────┘             │
│                                │                                            │
│         ┌──────────────────────┼──────────────────────┐                    │
│         │                      │                      │                    │
│         ▼                      ▼                      ▼                    │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────────┐            │
│  │auth-service │      │catalog-svc  │      │  image-service  │            │
│  └──────┬──────┘      └──────┬──────┘      └────────┬────────┘            │
│         │                    │                      │                      │
│         └────────────────────┼──────────────────────┘                      │
│                              │                                              │
│         ┌────────────────────┼────────────────────┐                        │
│         ▼                    ▼                    ▼                        │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                │
│  │   MongoDB   │      │    Kafka    │      │    MinIO    │                │
│  │ (replica)   │      │   (KRaft)   │      │    (S3)     │                │
│  └─────────────┘      └─────────────┘      └─────────────┘                │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐   │
│  │                     Observability Stack                             │   │
│  │  OTel Collector → Prometheus (metrics)                             │   │
│  │                 → Tempo (traces)                                    │   │
│  │  Alloy ────────→ Loki (logs)                                       │   │
│  │                              ↓                                      │   │
│  │                         Grafana                                     │   │
│  └────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **VPS**: Ubuntu 22.04+ with at least 4GB RAM, 2 vCPU, 40GB SSD
- **Docker**: 24.0+ with Docker Compose v2
- **Domain**: Configured DNS pointing to VPS IP
- **Ports**: 80, 443 open in firewall

### Install Docker (Ubuntu)

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Logout and login again, then verify
docker --version
docker compose version
```

## Quick Start

### 1. Clone Repository

```bash
# On your VPS
cd /opt
sudo git clone https://github.com/YOUR_USERNAME/ecommerce-infrastructure.git ecommerce
sudo chown -R $USER:$USER ecommerce
cd ecommerce/environments/production
```

### 2. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Generate secure passwords
make generate-secrets

# Edit .env with your values
nano .env
```

**Required variables to change:**

| Variable | Description | How to generate |
|----------|-------------|-----------------|
| `DOMAIN` | Your domain (e.g., `shop.example.com`) | — |
| `ACME_EMAIL` | Email for Let's Encrypt | — |
| `MONGO_ROOT_PASSWORD` | MongoDB password | `make generate-secrets` |
| `MINIO_ROOT_PASSWORD` | MinIO password | `make generate-secrets` |
| `AUTH_TOKEN_PRIVATE_KEY` | JWT signing key | See [Auth Keys](#generating-auth-keys) |
| `AUTH_TOKEN_PUBLIC_KEY` | JWT verification key | See [Auth Keys](#generating-auth-keys) |
| `ADMIN_EMAIL` | Initial admin email | — |
| `ADMIN_PASSWORD` | Initial admin password | Choose strong password |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `make generate-secrets` |
| `IMGPROXY_KEY` | imgproxy security key | `make generate-secrets` |
| `IMGPROXY_SALT` | imgproxy security salt | `make generate-secrets` |
| `TRAEFIK_DASHBOARD_AUTH` | Traefik dashboard auth | See [Traefik Auth](#traefik-dashboard-auth) |

### 3. Verify Configuration

```bash
make check-env
```

### 4. Deploy

```bash
# Deploy entire stack
make deploy

# Check status
make status

# View logs
make logs
```

### 5. Access Services

| Service | URL |
|---------|-----|
| Main Store | `https://YOUR_DOMAIN` |
| Admin Panel | `https://admin.YOUR_DOMAIN` |
| API | `https://api.YOUR_DOMAIN/api/v1/` |
| Grafana | `https://grafana.YOUR_DOMAIN` |
| Traefik Dashboard | `https://traefik.YOUR_DOMAIN` |

## Configuration Details

### Generating Auth Keys

Use the auth-service keygen tool:

```bash
# If you have Go installed locally
cd /path/to/ecommerce-auth-service
go run cmd/keygen/main.go

# Output:
# Private Key: <64-hex-chars>
# Public Key: <64-hex-chars>
```

Or generate manually:

```bash
# Generate key pair (Ed25519)
openssl genpkey -algorithm ED25519 -out private.pem
openssl pkey -in private.pem -pubout -out public.pem

# Convert to hex (check your auth-service docs for exact format)
```

### Traefik Dashboard Auth

Generate htpasswd hash:

```bash
# Install htpasswd if needed
sudo apt-get install apache2-utils

# Generate hash (escape $ with $$)
htpasswd -nb admin YOUR_PASSWORD | sed -e 's/\$/\$\$/g'

# Output example: admin:$$apr1$$xyz...
# Copy this to TRAEFIK_DASHBOARD_AUTH in .env
```

### DNS Configuration

Point these records to your VPS IP:

| Type | Name | Value |
|------|------|-------|
| A | `@` | `YOUR_VPS_IP` |
| A | `admin` | `YOUR_VPS_IP` |
| A | `api` | `YOUR_VPS_IP` |
| A | `grafana` | `YOUR_VPS_IP` |
| A | `traefik` | `YOUR_VPS_IP` |

Or use a wildcard:

| Type | Name | Value |
|------|------|-------|
| A | `@` | `YOUR_VPS_IP` |
| A | `*` | `YOUR_VPS_IP` |

## Makefile Commands

### Deployment

```bash
make deploy              # Deploy entire stack
make deploy-infra        # Deploy infrastructure only
make deploy-observability # Deploy monitoring only
make deploy-services     # Deploy application services only
make deploy-fresh        # Force recreate all containers
```

### Lifecycle

```bash
make down                # Stop and remove containers
make down-volumes        # Stop and remove containers + volumes (DATA LOSS!)
make restart             # Restart all services
make restart-services    # Restart only application services
make stop                # Stop without removing
make start               # Start stopped services
```

### Updates

```bash
make pull                # Pull latest images
make upgrade             # Pull + redeploy changed containers
make upgrade-services    # Pull + redeploy only app services
```

### Monitoring

```bash
make status              # Show container status
make health              # Check health of all services
make logs                # Follow all logs
make logs-services       # Follow app service logs
make logs-service SVC=auth-service  # Follow specific service logs
```

### Maintenance

```bash
make clean               # Remove stopped containers, unused images
make backup-volumes      # Backup data volumes to ./backups/
make generate-secrets    # Generate random passwords
make check-env           # Verify .env configuration
make urls                # Show service URLs
```

## Updating Services

### Update Application Services (new code)

When you push new code and CI builds new Docker images:

```bash
cd /opt/ecommerce/environments/production

# Pull new images and redeploy
make upgrade-services
```

### Update Infrastructure/Config

When compose files or configs change:

```bash
cd /opt/ecommerce/environments/production

# Pull latest from git
git pull origin main

# Redeploy with new config
make deploy

# Or force recreate everything
make deploy-fresh
```

## Backup & Restore

### Backup

```bash
# Backup all data volumes
make backup-volumes

# Backups are saved to ./backups/ with timestamps
ls -la backups/
# mongo_data_20260125_120000.tar.gz
# kafka_data_20260125_120000.tar.gz
# ...
```

### Restore

```bash
# Stop services
make down

# Restore a volume (example: mongo)
docker volume create ecommerce_mongo_data
docker run --rm \
  -v ecommerce_mongo_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/mongo_data_20260125_120000.tar.gz -C /data

# Start services
make deploy
```

## Monitoring & Observability

### Grafana

Access: `https://grafana.YOUR_DOMAIN`

Default credentials:
- Username: `admin`
- Password: (from `GRAFANA_ADMIN_PASSWORD` in .env)

Pre-configured datasources:
- **Prometheus**: Metrics
- **Tempo**: Traces
- **Loki**: Logs

### Viewing Logs

```bash
# All services
make logs

# Specific service
make logs-service SVC=catalog-service

# Or via Grafana → Explore → Loki
```

### Viewing Traces

1. Open Grafana → Explore
2. Select "Tempo" datasource
3. Search by service name or trace ID

## Troubleshooting

### Service won't start

```bash
# Check logs
make logs-service SVC=<service-name>

# Check health
docker inspect <container-name> --format='{{.State.Health}}'

# Check config
docker compose config
```

### SSL certificate issues

```bash
# Check Traefik logs
make logs-service SVC=traefik

# Verify DNS is pointing to server
dig +short YOUR_DOMAIN

# Check certificate status
docker exec traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates'
```

### MongoDB replica set issues

```bash
# Check replica set status
docker exec mongo mongosh -u admin -p <password> --eval "rs.status()"

# Re-initialize if needed
docker exec mongo mongosh -u admin -p <password> --eval "rs.initiate()"
```

### Kafka issues

```bash
# Check cluster status
docker exec kafka kafka-metadata.sh --snapshot /var/lib/kafka/data/__cluster_metadata-0/00000000000000000000.log --cluster-id <cluster-id>

# List topics
docker exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list
```

## Security Recommendations

1. **Firewall**: Only open ports 80, 443. Use SSH key authentication.

2. **Updates**: Regularly update base images:
   ```bash
   make pull
   make deploy-fresh
   ```

3. **Backups**: Set up automated backups:
   ```bash
   # Add to crontab
   0 2 * * * cd /opt/ecommerce/environments/production && make backup-volumes
   ```

4. **Monitoring**: Set up alerts in Grafana for:
   - Container restarts
   - High CPU/Memory usage
   - Disk space
   - Error rates

5. **Secrets rotation**: Periodically rotate passwords and keys.

## File Structure

```
environments/production/
├── docker-compose.yml      # Main compose file (includes others)
├── .env.example            # Example environment variables
├── .env                    # Actual environment (not in git!)
├── Makefile                # Deployment commands
├── README.md               # This file
├── compose/
│   ├── infra.yml          # MongoDB, Kafka, MinIO, imgproxy
│   ├── observability.yml  # OTel, Prometheus, Tempo, Loki, Grafana
│   ├── services.yml       # Go microservices + Next.js UIs
│   └── traefik.yml        # Reverse proxy + SSL
└── config/
    ├── otel-collector-config.yaml
    ├── prometheus-config.yaml
    ├── tempo-config.yaml
    ├── loki-config.yaml
    ├── alloy-config.alloy
    ├── grafana-datasources.yaml
    └── grafana-dashboards.yaml
```

## Support

For issues, check:
1. Service logs: `make logs-service SVC=<name>`
2. Container status: `make health`
3. Grafana dashboards for metrics/traces/logs
