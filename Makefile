all:
	make -C docker all
	make -C k3d all
	make -C helm/traefik all
	make -C helm/ecommerce-go-service all