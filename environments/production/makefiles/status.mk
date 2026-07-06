# =============================================================================
##@ Status & Inspection
# =============================================================================

.PHONY: status
status: ## Show status of all pods
	@printf "$(COLOR_BOLD)Namespace: $(NS_PROD)$(COLOR_RESET)\n"
	@kubectl get pods -n $(NS_PROD) -o wide
	@printf "\n$(COLOR_BOLD)Namespace: $(NS_OBS)$(COLOR_RESET)\n"
	@kubectl get pods -n $(NS_OBS) -o wide

.PHONY: health
health: ## Check health of all services
	@printf "$(COLOR_BOLD)Pod Health:$(COLOR_RESET)\n"
	@kubectl get pods -n $(NS_PROD) -o custom-columns=\
	"NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"
	@printf "\n"
	@kubectl get pods -n $(NS_OBS) -o custom-columns=\
	"NAME:.metadata.name,STATUS:.status.phase,READY:.status.conditions[?(@.type=='Ready')].status,RESTARTS:.status.containerStatuses[0].restartCount"

.PHONY: events
events: ## Show recent events in prod namespace
	kubectl get events -n $(NS_PROD) --sort-by='.lastTimestamp' | tail -30

.PHONY: ingresses
ingresses: ## Show all ingress routes
	@printf "$(COLOR_BOLD)Ingress Routes:$(COLOR_RESET)\n"
	@kubectl get ingress -n $(NS_PROD)

# =============================================================================
##@ Logs & Debugging
# =============================================================================

.PHONY: logs
logs: ## Follow logs for a service (usage: make logs SVC=catalog-service)
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make logs SVC=<service-name>\n"
	@exit 1
endif
	kubectl logs -f -n $(NS_PROD) -l app.kubernetes.io/name=$(SVC)

.PHONY: logs-prev
logs-prev: ## Show logs from crashed container (usage: make logs-prev SVC=catalog-service)
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make logs-prev SVC=<service-name>\n"
	@exit 1
endif
	kubectl logs -n $(NS_PROD) -l app.kubernetes.io/name=$(SVC) -p --tail=50

.PHONY: describe
describe: ## Describe pod for a service (usage: make describe SVC=catalog-service)
ifndef SVC
	@printf "$(COLOR_RED)Error: SVC is not set$(COLOR_RESET)\n"
	@printf "Usage: make describe SVC=<service-name>\n"
	@exit 1
endif
	kubectl describe pod -n $(NS_PROD) -l app.kubernetes.io/name=$(SVC)

.PHONY: console
console: ## Port-forward Redpanda Console (http://localhost:8080)
	@printf "$(COLOR_BLUE)→ Opening port-forward to Redpanda Console...$(COLOR_RESET)\n"
	@printf "$(COLOR_YELLOW)Press Ctrl+C to stop$(COLOR_RESET)\n"
	kubectl port-forward -n $(NS_PROD) svc/redpanda-console 8080:8080

.PHONY: logto-console
logto-console: ## Port-forward Logto Admin Console (localhost:3002)
	@printf "$(COLOR_BLUE)→ Forwarding Logto Admin Console to localhost:3002...$(COLOR_RESET)\n"
	kubectl port-forward svc/logto 3002:3002 -n $(NS_PROD)
