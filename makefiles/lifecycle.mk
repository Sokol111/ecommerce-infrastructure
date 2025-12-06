# =============================================================================
# Lifecycle Commands
# =============================================================================

.PHONY: init
init: tools-check cluster docker infra ## Bootstrap full dev environment from scratch
	@echo ""
	@printf "\033[32m✓ Development environment ready!\033[0m\n"
	@echo ""
	@printf "\033[36mNext steps:\033[0m\n"
	@printf "  - Run \033[32mmake dev\033[0m to start Tilt development mode\n"
	@printf "  - Run \033[32mmake deploy\033[0m to deploy services\n"
	@printf "  - Run \033[32mmake urls\033[0m to see all available service URLs\n"

.PHONY: clean
clean: undeploy infra-uninstall docker-clean cluster-delete ## Destroy everything (cluster, infra, volumes)
	@printf "\033[32m✓ Complete cleanup finished\033[0m\n"

.PHONY: reset
reset: clean init ## Nuke and rebuild environment (clean + init)
	@printf "\033[32m✓ Environment reset complete\033[0m\n"

.PHONY: up
up: cluster-start docker infra ## Start cluster and infrastructure (no deploy)
	@echo ""
	@printf "\033[32m✓ Everything is up and running!\033[0m\n"
	@echo ""
	@printf "\033[36mNext step:\033[0m\n"
	@printf "  - Run \033[32mmake dev\033[0m or \033[32mmake deploy\033[0m to deploy services\n"

.PHONY: down
down: docker-down cluster-stop ## Stop cluster and infrastructure (keeps data)
