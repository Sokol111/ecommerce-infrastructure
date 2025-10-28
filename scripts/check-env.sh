#!/usr/bin/env bash
# Quick environment check script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Environment Check ===${NC}\n"

# Check required tools
echo -e "${CYAN}Checking required tools:${NC}"
MISSING=0

check_tool() {
  if command -v "$1" &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} $1 ($(command -v "$1"))"
  else
    echo -e "  ${RED}✗${NC} $1 - NOT FOUND"
    MISSING=1
  fi
}

check_tool docker
check_tool docker-compose
check_tool k3d
check_tool kubectl
check_tool skaffold
check_tool helm
check_tool stern
check_tool nc

if [ $MISSING -eq 1 ]; then
  echo -e "\n${RED}Some tools are missing!${NC}"
  exit 1
fi

echo -e "\n${CYAN}Checking Docker:${NC}"
if docker ps &> /dev/null; then
  echo -e "  ${GREEN}✓${NC} Docker daemon is running"
  echo -e "  ${CYAN}Containers:${NC} $(docker ps -q | wc -l) running"
else
  echo -e "  ${RED}✗${NC} Docker daemon is not accessible"
  exit 1
fi

echo -e "\n${CYAN}Checking k3d cluster:${NC}"
if k3d cluster list 2>/dev/null | grep -q "dev-cluster"; then
  STATUS=$(k3d cluster list | grep "dev-cluster" | awk '{print $6}')
  if [ "$STATUS" = "running" ]; then
    echo -e "  ${GREEN}✓${NC} Cluster 'dev-cluster' is running"
  else
    echo -e "  ${YELLOW}⚠${NC} Cluster 'dev-cluster' exists but is $STATUS"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} Cluster 'dev-cluster' not found"
  echo -e "  ${CYAN}Run:${NC} make cluster-create"
fi

echo -e "\n${CYAN}Checking kubectl context:${NC}"
if kubectl config current-context &> /dev/null; then
  CTX=$(kubectl config current-context)
  echo -e "  ${GREEN}✓${NC} Current context: $CTX"
  
  if kubectl get nodes &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Cluster is accessible"
    kubectl get nodes --no-headers | while read -r line; do
      NODE=$(echo "$line" | awk '{print $1}')
      STATUS=$(echo "$line" | awk '{print $2}')
      if [ "$STATUS" = "Ready" ]; then
        echo -e "    ${GREEN}✓${NC} $NODE"
      else
        echo -e "    ${YELLOW}⚠${NC} $NODE ($STATUS)"
      fi
    done
  else
    echo -e "  ${RED}✗${NC} Cannot access cluster"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} No kubectl context set"
fi

echo -e "\n${CYAN}Checking local infrastructure:${NC}"
if docker ps --format "{{.Names}}" | grep -q mongo; then
  echo -e "  ${GREEN}✓${NC} MongoDB is running"
else
  echo -e "  ${YELLOW}⚠${NC} MongoDB is not running"
  echo -e "  ${CYAN}Run:${NC} make infra-up"
fi

if docker ps --format "{{.Names}}" | grep -q kafka; then
  echo -e "  ${GREEN}✓${NC} Kafka is running"
else
  echo -e "  ${YELLOW}⚠${NC} Kafka is not running"
  echo -e "  ${CYAN}Run:${NC} make infra-up"
fi

echo -e "\n${CYAN}Checking debug ports:${NC}"
for port in 2345 2346 2347 2348 2349; do
  if nc -z localhost "$port" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Port $port is open"
  else
    echo -e "  ${YELLOW}⚠${NC} Port $port is not accessible"
  fi
done

echo -e "\n${CYAN}Disk usage:${NC}"
df -h / | tail -1 | awk '{print "  Root: " $3 " used / " $2 " total (" $5 " full)"}'
df -h /var/lib/docker 2>/dev/null | tail -1 | awk '{print "  Docker: " $3 " used / " $2 " total (" $5 " full)"}'

echo -e "\n${GREEN}=== Check Complete ===${NC}"
echo -e "\n${CYAN}Quick commands:${NC}"
echo -e "  ${GREEN}make help${NC}     - Show all available commands"
echo -e "  ${GREEN}make status${NC}   - Show cluster status"
echo -e "  ${GREEN}make init${NC}     - Initialize everything"
echo -e "  ${GREEN}make dev${NC}      - Start development mode"
