.PHONY: all
all:
	make -C docker all
	make -C k3d all
	make -C helm/traefik all
	make -C helm/ecommerce-go-service all

.PHONY: update-ecommerce-go-service
update-ecommerce-go-service:
	make -C helm/ecommerce-go-service all

.PHONY: clean
clean:
	make -C k3d clean

.PHONY: helm-list
helm-list:
	helm list -n dev

.PHONY: get-pods
get-pods:
	kubectl get pods -n dev

.PHONY: describe-pod
describe-pod:
	kubectl describe pod $(POD) -n dev

.PHONY: pod-logs
pod-logs:
	kubectl logs $(POD) -n dev