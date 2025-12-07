# =============================================================================
# Docker Compose Infrastructure
# =============================================================================

.PHONY: docker
docker: tools-check ## Start Docker infra (Mongo, Kafka, Storage, Observability)
	@printf "\033[36m→ Starting Docker infrastructure\033[0m\n"
	@docker network inspect "$(DOCKER_NETWORK)" >/dev/null 2>&1 || \
		(printf "  Creating network '$(DOCKER_NETWORK)'\n" && docker network create "$(DOCKER_NETWORK)")
	@printf "  Starting MongoDB...\n"
	@docker compose -f "$(MONGO_COMPOSE)" up -d --remove-orphans
	@printf "  Starting Kafka...\n"
	@docker compose -f "$(KAFKA_COMPOSE)" up -d --remove-orphans
	@printf "  Starting Storage (MinIO, imgproxy)...\n"
	@docker compose -f "$(STORAGE_COMPOSE)" up -d --remove-orphans
	@printf "  Starting Observability stack (Grafana, Prometheus, Tempo)...\n"
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" up -d --remove-orphans
	@printf "\033[32m✓ Docker infrastructure started\033[0m\n"
	@printf "\n\033[36mServices:\033[0m\n"
	@printf "  MongoDB:          mongodb://localhost:27017\n"
	@printf "  Kafka:            localhost:9092\n"
	@printf "  Kafka UI:         http://localhost:9093\n"
	@printf "  Schema Registry:  http://localhost:8084\n"
	@printf "  MinIO API:        http://localhost:9000\n"
	@printf "  MinIO Console:    $(MINIO_CONSOLE_URL) (minioadmin/minioadmin123)\n"
	@printf "  imgproxy:         $(IMGPROXY_URL)\n"
	@printf "  Grafana:          $(GRAFANA_URL) (admin/admin)\n"
	@printf "  Prometheus:       $(PROMETHEUS_URL)\n"
	@printf "  Tempo:            $(TEMPO_URL)\n"
	@printf "\n\033[33m⚠  Note: Services may take a few seconds to become ready\033[0m\n"

.PHONY: docker-down
docker-down: ## Stop Docker infra (keeps volumes)
	@printf "\033[33m→ Stopping Docker infrastructure\033[0m\n"
	@docker compose -f "$(MONGO_COMPOSE)" down
	@docker compose -f "$(KAFKA_COMPOSE)" down
	@docker compose -f "$(STORAGE_COMPOSE)" down
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" down
	@printf "\033[32m✓ Docker infrastructure stopped\033[0m\n"

.PHONY: docker-logs
docker-logs: ## Tail Docker infra logs (Ctrl+C to stop)
	@printf "\033[36m→ Docker infrastructure logs (Ctrl+C to stop)\033[0m\n"
	@docker compose -f "$(MONGO_COMPOSE)" -f "$(KAFKA_COMPOSE)" -f "$(STORAGE_COMPOSE)" -f "$(OBSERVABILITY_COMPOSE)" logs -f

.PHONY: docker-restart
docker-restart: docker-down docker ## Restart Docker infra (keeps data)

.PHONY: docker-clean
docker-clean: docker-down ## Stop Docker infra and delete volumes
	@printf "\033[33m→ Cleaning Docker volumes\033[0m\n"
	@docker compose -f "$(MONGO_COMPOSE)" down -v
	@docker compose -f "$(KAFKA_COMPOSE)" down -v
	@docker compose -f "$(STORAGE_COMPOSE)" down -v
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" down -v
	@printf "\033[32m✓ Docker volumes removed\033[0m\n"

.PHONY: docker-status
docker-status: ## Show Docker services status
	@printf "\033[36m→ Docker infrastructure status:\033[0m\n"
	@printf "\n\033[33mMongoDB:\033[0m\n"
	@docker compose -f "$(MONGO_COMPOSE)" ps
	@printf "\n\033[33mKafka:\033[0m\n"
	@docker compose -f "$(KAFKA_COMPOSE)" ps
	@printf "\n\033[33mStorage:\033[0m\n"
	@docker compose -f "$(STORAGE_COMPOSE)" ps
	@printf "\n\033[33mObservability:\033[0m\n"
	@docker compose -f "$(OBSERVABILITY_COMPOSE)" ps
