# =============================================================================
# Tilt Development
# =============================================================================

# Ensure shared Docker network exists (required by docker_compose in Tiltfile)
.PHONY: docker-network
docker-network:
	@docker network inspect "$(DOCKER_NETWORK)" >/dev/null 2>&1 || \
		(printf "  Creating network '$(DOCKER_NETWORK)'\n" && docker network create "$(DOCKER_NETWORK)")

.PHONY: dev
dev: cluster infra docker-network ## Start Tilt dev mode with hot-reload
	@printf "\033[36m→ Starting Tilt development mode\033[0m\n"
	@printf "\033[33m  Web UI: http://localhost:10350\033[0m\n"
	@printf "\033[33m  Debug ports: 2345-2349 (product, category, product-query, category-query, image)\033[0m\n"
	@cd "$(ENV_DIR)" && tilt up

.PHONY: dev-headless
dev-headless: cluster infra docker-network ## Start Tilt headless (for CI)
	@printf "\033[36m→ Starting Tilt in headless mode\033[0m\n"
	@cd "$(ENV_DIR)" && tilt up --stream

.PHONY: deploy
deploy: cluster infra docker-network ## Deploy all services once (Tilt CI mode)
	@printf "\033[36m→ Deploying to cluster via Tilt\033[0m\n"
	@cd "$(ENV_DIR)" && tilt ci
	@printf "\033[32m✓ Deployment complete\033[0m\n"

.PHONY: undeploy
undeploy: ## Remove all Tilt deployments
	@printf "\033[33m→ Removing Tilt deployments\033[0m\n"
	@cd "$(ENV_DIR)" && tilt down 2>/dev/null || true
	@printf "\033[32m✓ Deployments removed\033[0m\n"

.PHONY: redeploy
redeploy: undeploy deploy ## Clean redeploy all services
