# =============================================================================
# Docker Compose Infrastructure
# =============================================================================

# Ignore orphan warnings since we use multiple compose files with same project name
# Not exported globally because it conflicts with Tilt's --remove-orphans flag
DC = COMPOSE_IGNORE_ORPHANS=true docker compose

.PHONY: docker
docker: tools-check ## Start Docker infra (Mongo, Kafka, Storage, Observability)
	@printf "\033[36m→ Starting Docker infrastructure\033[0m\n"
	@docker network inspect "$(DOCKER_NETWORK)" >/dev/null 2>&1 || \
		(printf "  Creating network '$(DOCKER_NETWORK)'\n" && docker network create "$(DOCKER_NETWORK)")
	@printf "  Starting MongoDB...\n"
	@$(DC) -f "$(MONGO_COMPOSE)" up -d
	@printf "  Starting Redpanda...\n"
	@$(DC) -f "$(KAFKA_COMPOSE)" up -d
	@printf "  Starting Storage (MinIO, imgproxy)...\n"
	@$(DC) -f "$(STORAGE_COMPOSE)" up -d
	@printf "  Starting Observability stack (Grafana, Prometheus, Tempo)...\n"
	@$(DC) -f "$(OBSERVABILITY_COMPOSE)" up -d
	@printf "  Starting Identity (Zitadel)...\n"
	@$(DC) -f "$(ZITADEL_COMPOSE)" up -d
	@printf "\033[32m✓ Docker infrastructure started\033[0m\n"
	@printf "\n\033[36mServices:\033[0m\n"
	@printf "  MongoDB:          mongodb://localhost:27017\n"
	@printf "  Redpanda:         localhost:9092\n"
	@printf "  Redpanda Console: http://localhost:9093\n"
	@printf "  Schema Registry:  http://localhost:8084\n"
	@printf "  MinIO API:        http://localhost:9000\n"
	@printf "  MinIO Console:    $(MINIO_CONSOLE_URL) (minioadmin/minioadmin123)\n"
	@printf "  imgproxy:         $(IMGPROXY_URL)\n"
	@printf "  Grafana:          $(GRAFANA_URL) (admin/admin)\n"
	@printf "  Prometheus:       $(PROMETHEUS_URL)\n"
	@printf "  Tempo:            $(TEMPO_URL)\n"
	@printf "  Zitadel Console:  $(ZITADEL_URL)/ui/console (zitadel-admin@zitadel.localhost / Password1!)\n"
	@printf "\n\033[33m⚠  Note: Services may take a few seconds to become ready\033[0m\n"

.PHONY: docker-down
docker-down: ## Stop Docker infra (keeps volumes)
	@printf "\033[33m→ Stopping Docker infrastructure\033[0m\n"
	@$(DC) -f "$(MONGO_COMPOSE)" down
	@$(DC) -f "$(KAFKA_COMPOSE)" down
	@$(DC) -f "$(STORAGE_COMPOSE)" down
	@$(DC) -f "$(OBSERVABILITY_COMPOSE)" down
	@$(DC) -f "$(ZITADEL_COMPOSE)" down
	@printf "\033[32m✓ Docker infrastructure stopped\033[0m\n"

.PHONY: docker-logs
docker-logs: ## Tail Docker infra logs (Ctrl+C to stop)
	@printf "\033[36m→ Docker infrastructure logs (Ctrl+C to stop)\033[0m\n"
	@$(DC) -f "$(MONGO_COMPOSE)" -f "$(KAFKA_COMPOSE)" -f "$(STORAGE_COMPOSE)" -f "$(OBSERVABILITY_COMPOSE)" -f "$(ZITADEL_COMPOSE)" logs -f

.PHONY: docker-restart
docker-restart: docker-down docker ## Restart Docker infra (keeps data)

.PHONY: docker-clean
docker-clean: ## Stop Docker infra and delete volumes
	@printf "\033[33m→ Cleaning Docker volumes\033[0m\n"
	@$(DC) -f "$(MONGO_COMPOSE)" down -v
	@$(DC) -f "$(KAFKA_COMPOSE)" down -v
	@$(DC) -f "$(STORAGE_COMPOSE)" down -v
	@$(DC) -f "$(OBSERVABILITY_COMPOSE)" down -v
	@$(DC) -f "$(ZITADEL_COMPOSE)" down -v
	@printf "\033[32m✓ Docker volumes removed\033[0m\n"

.PHONY: docker-status
docker-status: ## Show Docker services status
	@printf "\033[36m→ Docker infrastructure status:\033[0m\n"
	@printf "\n\033[33mMongoDB:\033[0m\n"
	@$(DC) -f "$(MONGO_COMPOSE)" ps
	@printf "\n\033[33mKafka:\033[0m\n"
	@$(DC) -f "$(KAFKA_COMPOSE)" ps
	@printf "\n\033[33mStorage:\033[0m\n"
	@$(DC) -f "$(STORAGE_COMPOSE)" ps
	@printf "\n\033[33mObservability:\033[0m\n"
	@$(DC) -f "$(OBSERVABILITY_COMPOSE)" ps
	@printf "\n\033[33mIdentity (Zitadel):\033[0m\n"
	@$(DC) -f "$(ZITADEL_COMPOSE)" ps
