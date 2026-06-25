PYTHON ?= python3
IMAGE ?= kubernetes-monitor:local

.PHONY: install run test docker-build helm-template helm-install helm-uninstall

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
