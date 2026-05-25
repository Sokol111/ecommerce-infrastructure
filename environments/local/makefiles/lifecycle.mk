# =============================================================================
# Lifecycle Commands
# =============================================================================

.PHONY: init
init: tools-check cluster-create cluster-inject-ca traefik-install alloy-install ## Bootstrap dev environment (cluster + infra)
	@echo ""
	@printf "\033[32m✓ Development environment ready!\033[0m\n"
	@echo ""
	@printf "\033[36mNext steps:\033[0m\n"
	@printf "  - Run \033[32mmake dev\033[0m to start Tilt (services + infrastructure)\n"
	@printf "  - Run \033[32mmake urls\033[0m to see all available service URLs\n"

.PHONY: clean
clean: undeploy traefik-uninstall alloy-uninstall docker-clean cluster-delete ## Destroy everything (cluster, infra, volumes)
	@printf "\033[32m✓ Complete cleanup finished\033[0m\n"

.PHONY: up
up: cluster-start cluster-inject-ca traefik-install alloy-install ## Start cluster and K8s infrastructure
	@echo ""
	@printf "\033[32m✓ Cluster and infrastructure are up!\033[0m\n"
	@echo ""
	@printf "\033[36mNext step:\033[0m\n"
	@printf "  - Run \033[32mmake dev\033[0m to start Tilt (services + Docker infra)\n"

.PHONY: down
down: cluster-stop ## Stop cluster (Docker infra stopped by tilt down)
	@printf "\033[33m→ Stopped. Run 'make docker-down' if Docker infra is still running.\033[0m\n"
