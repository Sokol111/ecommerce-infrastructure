# =============================================================================
# Tilt Development
# =============================================================================

.PHONY: dev
dev: cluster infra ## Запустити Tilt для розробки з автоматичною пересборкою, деплоєм та Web UI (http://localhost:10350)
	@printf "\033[36m→ Starting Tilt development mode\033[0m\n"
	@printf "\033[33m  Web UI: http://localhost:10350\033[0m\n"
	@printf "\033[33m  Debug ports: 2345-2349 (product, category, product-query, category-query, image)\033[0m\n"
	@cd "$(ENV_DIR)" && tilt up

.PHONY: dev-headless
dev-headless: cluster infra ## Запустити Tilt у headless режимі (без інтерактивного UI, для CI)
	@printf "\033[36m→ Starting Tilt in headless mode\033[0m\n"
	@cd "$(ENV_DIR)" && tilt up --stream

.PHONY: deploy
deploy: cluster infra ## Одноразовий деплой всіх сервісів через Tilt CI mode (build + deploy без watch)
	@printf "\033[36m→ Deploying to cluster via Tilt\033[0m\n"
	@cd "$(ENV_DIR)" && tilt ci
	@printf "\033[32m✓ Deployment complete\033[0m\n"

.PHONY: undeploy
undeploy: ## Видалити всі сервіси задеплоєні через Tilt
	@printf "\033[33m→ Removing Tilt deployments\033[0m\n"
	@cd "$(ENV_DIR)" && tilt down 2>/dev/null || true
	@printf "\033[32m✓ Deployments removed\033[0m\n"

.PHONY: redeploy
redeploy: undeploy deploy ## Видалити поточний деплоймент та заново задеплоїти всі сервіси (чистий деплой)

.PHONY: tilt-ui
tilt-ui: ## Відкрити Tilt Web UI в браузері (http://localhost:10350)
	@printf "\033[36m→ Opening Tilt UI: http://localhost:10350\033[0m\n"
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open "http://localhost:10350" 2>/dev/null || true; \
	elif command -v open >/dev/null 2>&1; then \
		open "http://localhost:10350" 2>/dev/null || true; \
	fi
