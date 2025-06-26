THIS_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: all
all: start-mongo start-kafka

.PHONY: ensure-network
ensure-network:
	docker network inspect shared-network > /dev/null 2>&1 || docker network create shared-network

.PHONY: start-mongo
start-mongo: ensure-network
	docker compose -f $(THIS_DIR)docker-compose/mongo.yml up -d

.PHONY: stop-mongo
stop-mongo:
	docker compose -f $(THIS_DIR)docker-compose/mongo.yml down

.PHONY: start-kafka
start-kafka: ensure-network
	docker compose -f $(THIS_DIR)docker-compose/kafka.yml up -d

.PHONY: stop-kafka
stop-kafka:
	docker compose -f $(THIS_DIR)docker-compose/kafka.yml down

.PHONY: stop
stop: stop-mongo stop-kafka

.PHONY: restart
restart: stop all