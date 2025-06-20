include helm/mongo/makefile.mk
include helm/traefik/makefile.mk
include k3d/makefile.mk

setup-cluster: create-k3d install-traefik install-mongo
