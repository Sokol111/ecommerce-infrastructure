# =============================================================================
##@ Operations
# =============================================================================

.PHONY: restart
restart: ## Restart a service (usage: make restart SVC=catalog-service)
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make restart SVC=<service-name>\n"
	@exit 1
endif
	@printf "$(COLOR_BLUE)→ Restarting $(SVC)...$(COLOR_RESET)\n"
	kubectl rollout restart deployment -n $(NS_PROD) -l app.kubernetes.io/name=$(SVC)
	kubectl rollout status deployment -n $(NS_PROD) -l app.kubernetes.io/name=$(SVC) --timeout=90s
	@printf "$(COLOR_GREEN)✓ $(SVC) restarted$(COLOR_RESET)\n"

.PHONY: restart-alloy
restart-alloy: ## Restart Grafana Alloy
	@printf "$(COLOR_BLUE)→ Restarting Alloy...$(COLOR_RESET)\n"
	kubectl rollout restart daemonset/alloy -n $(NS_OBS)
	kubectl rollout status daemonset/alloy -n $(NS_OBS) --timeout=90s
	@printf "$(COLOR_GREEN)✓ Alloy restarted$(COLOR_RESET)\n"

.PHONY: restart-redpanda
restart-redpanda: ## Restart Redpanda
	@printf "$(COLOR_BLUE)→ Restarting Redpanda...$(COLOR_RESET)\n"
	kubectl rollout restart statefulset/redpanda -n $(NS_PROD)
	kubectl rollout status statefulset/redpanda -n $(NS_PROD) --timeout=5m
	@printf "$(COLOR_GREEN)✓ Redpanda restarted$(COLOR_RESET)\n"

# =============================================================================
##@ Seeder
# =============================================================================

SEED_CRONJOB := ecommerce-tenant-service-seeder
TENANT_SLUG  ?=

.PHONY: seed
seed: ## Trigger seeder Job in cluster (TENANT_SLUG=acme for specific tenant)
	@if [ -z "$(TENANT_SLUG)" ]; then \
		printf "$(COLOR_RED)Error: TENANT_SLUG is required$(COLOR_RESET)\n"; \
		printf "Usage: make seed TENANT_SLUG=<slug>\n"; \
		exit 1; \
	fi
	@printf "$(COLOR_BLUE)→ Creating seeder job for tenant '$(TENANT_SLUG)'...$(COLOR_RESET)\n"
	kubectl create job -n $(NS_PROD) \
		--from=cronjob/$(SEED_CRONJOB) \
		"seeder-$(TENANT_SLUG)-$$(date +%s)" \
		-- --tenant-slug="$(TENANT_SLUG)"
	@printf "$(COLOR_GREEN)✓ Seeder job created$(COLOR_RESET)\n"

.PHONY: seed-status
seed-status: ## Show status of seeder jobs
	@kubectl get jobs -n $(NS_PROD) -l app.kubernetes.io/component=seeder --sort-by=.metadata.creationTimestamp

.PHONY: seed-logs
seed-logs: ## Show logs of seeder job (TENANT_SLUG=acme)
	@if [ -z "$(TENANT_SLUG)" ]; then \
		printf "$(COLOR_RED)Error: TENANT_SLUG is required$(COLOR_RESET)\n"; \
		printf "Usage: make seed-logs TENANT_SLUG=<slug>\n"; \
		exit 1; \
	fi
	@kubectl logs -n $(NS_PROD) -l app.kubernetes.io/component=seeder,tenant-slug=$(TENANT_SLUG) --tail=100

# =============================================================================
##@ Logto Setup
# =============================================================================

.PHONY: logto-seed
logto-seed: ## Run logto-seed Job (one-time Logto configuration)
	@printf "$(COLOR_BLUE)→ Running logto-seed...$(COLOR_RESET)\n"
	kubectl apply -f $(K8S_DIR)/logto-seed-rbac.yaml
	export IMAGE=ghcr.io/sokol111/ecommerce-logto-seed:latest && \
		envsubst < $(K8S_DIR)/logto-seed-job.yaml | kubectl create -f -
	@printf "$(COLOR_GREEN)✓ logto-seed job created$(COLOR_RESET)\n"
	@printf "$(COLOR_BLUE)→ Waiting for completion...$(COLOR_RESET)\n"
	@JOB=$$(kubectl get jobs -n $(NS_PROD) --sort-by=.metadata.creationTimestamp -o name | grep logto-seed | tail -1) && \
		kubectl wait --for=condition=complete -n $(NS_PROD) "$$JOB" --timeout=120s && \
		printf "$(COLOR_GREEN)✓ logto-seed completed$(COLOR_RESET)\n" && \
		kubectl logs -n $(NS_PROD) "$$JOB"
