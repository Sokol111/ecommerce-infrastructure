#!/usr/bin/env bash
# Quick log viewer with service selection

set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}Available services in namespace '$NAMESPACE':${NC}\n"

# Get all deployments
deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

if [ -z "$deployments" ]; then
  echo -e "${YELLOW}No deployments found in namespace '$NAMESPACE'${NC}"
  exit 1
fi

# Create array
IFS=' ' read -r -a dep_array <<< "$deployments"

# Display menu
i=1
for dep in "${dep_array[@]}"; do
  pods=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name="$dep" --no-headers 2>/dev/null | wc -l)
  echo -e "  ${GREEN}$i)${NC} $dep ${YELLOW}($pods pods)${NC}"
  ((i++))
done

echo -e "\n  ${GREEN}a)${NC} All services"
echo -e "  ${GREEN}q)${NC} Quit"

echo -e -n "\n${CYAN}Select service:${NC} "
read -r choice

if [ "$choice" = "q" ]; then
  exit 0
elif [ "$choice" = "a" ]; then
  echo -e "\n${CYAN}Streaming all logs (Ctrl+C to stop)...${NC}\n"
  stern ".*" -n "$NAMESPACE"
elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#dep_array[@]}" ]; then
  selected="${dep_array[$((choice-1))]}"
  echo -e "\n${CYAN}Streaming logs for $selected (Ctrl+C to stop)...${NC}\n"
  stern "$selected" -n "$NAMESPACE"
else
  echo -e "${YELLOW}Invalid choice${NC}"
  exit 1
fi
