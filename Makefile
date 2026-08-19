# skyportal-k8s-deploy — generic Helm wrappers.
# Site overlays (e.g. skyportal-nrp) set NS / VALUES / SECRETS and call these.
NS      ?= skyportal
RELEASE ?= skyportal
CHART   ?= chart
VALUES  ?=
SECRETS ?= secrets.yaml
ROLE    ?= app
VALUES_FLAG := $(if $(VALUES),-f $(VALUES),)

.PHONY: help secrets lint template install upgrade uninstall status logs

help:
	@echo "skyportal-k8s-deploy (NS=$(NS), RELEASE=$(RELEASE), VALUES=$(VALUES)):"
	@echo "  secrets     kubectl apply $(SECRETS) (run before install)"
	@echo "  lint        helm lint the chart"
	@echo "  template    render manifests locally"
	@echo "  install     secrets + helm install"
	@echo "  upgrade     helm upgrade"
	@echo "  uninstall   helm uninstall"
	@echo "  status      pods,svc,ingress,pvc,statefulset"
	@echo "  logs ROLE=app|bus|workers|postgres"

secrets:
	kubectl apply -n $(NS) -f $(SECRETS)

lint:
	helm lint $(CHART) $(VALUES_FLAG)

template:
	helm template $(RELEASE) $(CHART) $(VALUES_FLAG)

install: secrets
	helm install $(RELEASE) $(CHART) -n $(NS) $(VALUES_FLAG)

upgrade:
	helm upgrade $(RELEASE) $(CHART) -n $(NS) $(VALUES_FLAG)

uninstall:
	helm uninstall $(RELEASE) -n $(NS)

status:
	kubectl get pods,svc,ingress,pvc,statefulset -n $(NS)

logs:
	kubectl logs -n $(NS) -l skyportal.role=$(ROLE) --tail=200 -f
