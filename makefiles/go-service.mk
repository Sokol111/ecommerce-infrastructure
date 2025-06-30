DOMAIN = $(PROJECT_NAME).test
DOCKERFILE_URL:=https://raw.githubusercontent.com/Sokol111/ecommerce-infrastructure/master/docker/Dockerfile.buildkit

.PHONY: generate-mocks build-docker-image start-docker-compose stop-docker-compose update-dependencies test init-git show-container-logs ensure-network

generate-mocks:
	mockery

add-host:
	@echo "Adding domain to /etc/hosts..."
	@if ! grep -q "$(DOMAIN)" /etc/hosts; then \
		echo "127.0.0.1 $(DOMAIN)" | sudo tee -a /etc/hosts > /dev/null; \
		echo "Added: $(DOMAIN)"; \
	else \
		echo "Already exists: $(DOMAIN)"; \
	fi

ensure-network:
	docker network inspect shared-network > /dev/null 2>&1 || docker network create shared-network

build-docker-image:
	@echo "Building Docker image..."
	curl -sSL $(DOCKERFILE_URL) -o Dockerfile.temp
	DOCKER_BUILDKIT=1 docker build \
		-f Dockerfile.temp \
		-t sokol111/$(PROJECT_NAME):latest .
	rm Dockerfile.temp

start-docker-compose: ensure-network stop-docker-compose
	docker compose up -d

stop-docker-compose:
	docker compose down

show-container-logs:
	docker compose logs -f

update-dependencies:
	go get -u ./...

test:
	go test ./... -v -cover
