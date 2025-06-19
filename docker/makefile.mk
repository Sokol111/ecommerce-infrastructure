.PHONY: ensure-network start-docker-mongo start-local-mongo stop-mongo stop-and-delete-mongo start-kafka stop-kafka start-traefik stop-traefik

ensure-network:
	docker network inspect shared-network > /dev/null 2>&1 || docker network create shared-network

start-docker-mongo: ensure-network stop-mongo
	MONGO_HOST=mongo docker compose -f ./infrastructure/docker/mongo.yml up -d

start-local-mongo: ensure-network stop-mongo
	MONGO_HOST=localhost docker compose -f ./infrastructure/docker/mongo.yml up -d

stop-mongo:
	docker compose -f ./infrastructure/docker/mongo.yml down

stop-and-delete-mongo:
	docker compose -f ./infrastructure/docker/mongo.yml down -v

start-kafka: ensure-network stop-kafka
	docker compose -f ./infrastructure/docker/kafka.yml up -d

stop-kafka:
	docker compose -f ./infrastructure/docker/kafka.yml down -v

start-traefik: ensure-network stop-traefik
	docker compose -f ./infrastructure/docker/traefik.yml up -d

stop-traefik:
	docker compose -f ./infrastructure/docker/traefik.yml down
