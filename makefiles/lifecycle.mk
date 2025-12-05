# =============================================================================
# Lifecycle Commands
# =============================================================================

.PHONY: init
init: tools-check cluster docker infra ## Повна ініціалізація середовища: створення кластера, запуск інфраструктури та Kubernetes компонентів (без деплою сервісів)
	@echo ""
	@printf "\033[32m✓ Development environment ready!\033[0m\n"
	@echo ""
	@printf "\033[36mNext steps:\033[0m\n"
	@printf "  - Run \033[32mmake dev\033[0m to start Tilt development mode\n"
	@printf "  - Run \033[32mmake deploy\033[0m to deploy services\n"
	@printf "  - Run \033[32mmake status\033[0m to check cluster status\n"
	@printf "  - Run \033[32mmake grafana\033[0m to access observability\n"
	@printf "  - Run \033[32mmake debug-info\033[0m for debugging instructions\n"

.PHONY: clean
clean: undeploy infra-uninstall docker-clean cluster-delete ## Повне очищення: видалення кластера, інфраструктури та всіх volumes з даними
	@printf "\033[32m✓ Complete cleanup finished\033[0m\n"

.PHONY: reset
reset: clean init ## Повний reset середовища: очищення та повторна ініціалізація з нуля (clean + init)
	@printf "\033[32m✓ Environment reset complete\033[0m\n"

.PHONY: up
up: cluster-start docker infra ## Швидкий старт: запустити кластер, Docker інфраструктуру та Kubernetes компоненти (все окрім деплою сервісів)
	@echo ""
	@printf "\033[32m✓ Everything is up and running!\033[0m\n"
	@echo ""
	@printf "\033[36mNext step:\033[0m\n"
	@printf "  - Run \033[32mmake dev\033[0m or \033[32mmake deploy\033[0m to deploy services\n"

.PHONY: down
down: docker-down cluster-stop ## Швидка зупинка: зупинити Docker інфраструктуру та кластер (дані зберігаються)
