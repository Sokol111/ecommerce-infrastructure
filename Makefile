NAMESPACE ?= dev

.PHONY: all
all:
	make -C docker all
	make -C k3d all
	make -C helm/traefik all
	make -C helm/ecommerce-go-service all

.PHONY: update-services
update-services:
	make -C helm/ecommerce-go-service all

.PHONY: docker-all
docker-all:
	make -C docker all

.PHONY: clean
clean:
	make -C k3d clean

.PHONY: helm-list
helm-list:
	helm list -n $(NAMESPACE)

.PHONY: get-pods
get-pods:
	kubectl get pods -n $(NAMESPACE)

.PHONY: describe-pod
describe-pod:
ifndef POD
	$(error You must specify POD=<pod-name>)
endif
	kubectl describe pod $(POD) -n $(NAMESPACE)

.PHONY: logs
logs:
ifndef SERVICE
	$(error You must specify SERVICE=<partial-pod-name>)
endif
	stern $(SERVICE) -n $(NAMESPACE)
