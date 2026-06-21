PYTHON ?= python3
IMAGE ?= kubernetes-monitor:local
EXAMPLES_DIR ?= ../../docs/examples/monitoring-kubernetes

.PHONY: install run test docker-build deploy undeploy helm-template helm-install helm-uninstall

install:
	$(PYTHON) -m pip install -r requirements-dev.txt

run:
	PYTHONPATH=src uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload

test:
	PYTHONPATH=src $(PYTHON) -m pytest tests

docker-build:
	docker build -t $(IMAGE) .

helm-template:
	helm template kubernetes-monitor ./chart --namespace monitoring

helm-install:
	helm upgrade --install kubernetes-monitor ./chart --namespace monitoring --create-namespace

helm-uninstall:
	helm uninstall kubernetes-monitor --namespace monitoring

deploy:
	kubectl apply -f $(EXAMPLES_DIR)/namespace.yaml
	kubectl apply -f $(EXAMPLES_DIR)/service-account.yaml
	kubectl apply -f $(EXAMPLES_DIR)/rbac.yaml
	kubectl apply -f $(EXAMPLES_DIR)/deployment.yaml
	kubectl apply -f $(EXAMPLES_DIR)/service.yaml
	kubectl apply -f $(EXAMPLES_DIR)/certificate.yaml
	kubectl apply -f $(EXAMPLES_DIR)/httproute.yaml

undeploy:
	kubectl delete -f $(EXAMPLES_DIR)/httproute.yaml --ignore-not-found
	kubectl delete -f $(EXAMPLES_DIR)/certificate.yaml --ignore-not-found
	kubectl delete -f $(EXAMPLES_DIR)/service.yaml --ignore-not-found
	kubectl delete -f $(EXAMPLES_DIR)/deployment.yaml --ignore-not-found
	kubectl delete -f $(EXAMPLES_DIR)/rbac.yaml --ignore-not-found
	kubectl delete -f $(EXAMPLES_DIR)/service-account.yaml --ignore-not-found
