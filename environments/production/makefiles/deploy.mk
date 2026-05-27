# =============================================================================
##@ Deploy Infrastructure
# =============================================================================

.PHONY: deploy-redpanda
deploy-redpanda: ## Deploy Redpanda (Kafka-compatible broker)
	@printf "$(COLOR_BLUE)→ Deploying Redpanda...$(COLOR_RESET)\n"
	helm upgrade --install redpanda redpanda/redpanda \
		-n $(NS_PROD) \
		-f $(VALUES_DIR)/redpanda.yaml \
		--wait --timeout 5m
	@printf "$(COLOR_GREEN)✓ Redpanda deployed$(COLOR_RESET)\n"

.PHONY: deploy-imgproxy
deploy-imgproxy: ## Deploy imgproxy (image processing)
	@printf "$(COLOR_BLUE)→ Deploying imgproxy...$(COLOR_RESET)\n"
	kubectl apply -f $(K8S_DIR)/imgproxy.yaml
	@printf "$(COLOR_GREEN)✓ imgproxy deployed$(COLOR_RESET)\n"

.PHONY: deploy-logto
deploy-logto: ## Deploy Logto OIDC identity provider
	@printf "$(COLOR_BLUE)→ Deploying Logto...$(COLOR_RESET)\n"
	kubectl apply -f $(K8S_DIR)/logto.yaml
	@printf "$(COLOR_GREEN)✓ Logto deployed$(COLOR_RESET)\n"

.PHONY: deploy-alloy
deploy-alloy: ## Deploy Grafana Alloy (→ Grafana Cloud)
	@printf "$(COLOR_BLUE)→ Deploying Grafana Alloy...$(COLOR_RESET)\n"
	helm upgrade --install alloy grafana/alloy \
		-n $(NS_OBS) \
		-f $(VALUES_DIR)/alloy.yaml \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ Grafana Alloy deployed$(COLOR_RESET)\n"

# =============================================================================
##@ Deploy Application Services
# =============================================================================

# Service lists
SERVICES := tenant-service catalog-service image-service product-query-service category-query-service platform-ui admin-ui ui

.PHONY: deploy-svc
deploy-svc: ## Deploy a service (usage: make deploy-svc SVC=catalog-service [TAG=0.1.9])
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make deploy-svc SVC=<service-name> [TAG=<version>]\n"
	@printf "Available: $(SERVICES)\n"
	@exit 1
endif
	@printf "$(COLOR_BLUE)→ Deploying ecommerce-$(SVC)...$(COLOR_RESET)\n"
	cd $(HELM_DIR)/ecommerce-$(SVC) && helm dependency update
	$(eval HELM_SET := $(if $(TAG),--set image.tag=$(TAG)))
	$(eval HELM_SET += $(if $(filter latest,$(TAG)),--set image.pullPolicy=Always))
	helm upgrade --install ecommerce-$(SVC) $(HELM_DIR)/ecommerce-$(SVC) \
		-n $(NS_PROD) \
		-f $(VALUES_DIR)/ecommerce-$(SVC).yaml \
		$(HELM_SET) \
		--wait --timeout 3m
	@printf "$(COLOR_GREEN)✓ ecommerce-$(SVC) deployed$(COLOR_RESET)\n"
