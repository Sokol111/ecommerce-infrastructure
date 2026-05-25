# =============================================================================
# Tilt Development
# =============================================================================

.PHONY: dev
dev: ## Start Tilt dev mode with hot-reload
	@printf "\033[36m→ Starting Tilt development mode\033[0m\n"
	@printf "\033[33m  Web UI: http://localhost:10350\033[0m\n"
	@printf "\033[33m  Debug ports: 2345-2349 (product, category, product-query, category-query, image)\033[0m\n"
	@cd "$(THIS_DIR)" && tilt up

.PHONY: undeploy
undeploy: ## Remove all Tilt deployments
	@printf "\033[33m→ Removing Tilt deployments\033[0m\n"
	@cd "$(THIS_DIR)" && tilt down 2>/dev/null || true
	@printf "\033[32m✓ Deployments removed\033[0m\n"
