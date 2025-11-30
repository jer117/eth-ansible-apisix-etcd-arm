.PHONY: help build run stop clean logs test health bash

VERSION ?= 3.14.0
IMAGE_NAME ?= apisix-arm
CONTAINER_NAME ?= apisix

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "Building Docker image..."
	docker build --build-arg VERSION=$(VERSION) -t $(IMAGE_NAME):$(VERSION) .
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest

build-no-cache: ## Build the Docker image without cache
	@echo "Building Docker image without cache..."
	docker build --no-cache --build-arg VERSION=$(VERSION) -t $(IMAGE_NAME):$(VERSION) .
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest

run: ## Run the container
	@echo "Starting APISIX container..."
	docker run -d \
		--name $(CONTAINER_NAME) \
		-p 9080:9080 \
		-p 9443:9443 \
		-p 9180:9180 \
		-p 2379:2379 \
		$(IMAGE_NAME):$(VERSION)
	@echo "Container started. Waiting for APISIX to be ready..."
	@sleep 10
	@make health

run-compose: ## Run using docker-compose
	@echo "Starting with docker-compose..."
	docker-compose up -d
	@echo "Services started. Waiting for APISIX to be ready..."
	@sleep 10
	@make health

stop: ## Stop the container
	@echo "Stopping APISIX container..."
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true

stop-compose: ## Stop docker-compose services
	@echo "Stopping docker-compose services..."
	docker-compose down

restart: stop run ## Restart the container

logs: ## Show container logs
	docker logs -f $(CONTAINER_NAME)

logs-compose: ## Show docker-compose logs
	docker-compose logs -f

health: ## Check APISIX health
	@echo "Checking APISIX health..."
	@curl -s http://localhost:9080/apisix/status || echo "APISIX is not responding"
	@echo ""
	@echo "Checking etcd health..."
	@docker exec $(CONTAINER_NAME) etcdctl endpoint health || echo "etcd is not responding"

test: health ## Run basic tests
	@echo "Testing APISIX Admin API..."
	@curl -s http://localhost:9180/apisix/admin/routes -H 'X-API-KEY: test' | head -n 5 || echo "Admin API test failed"

bash: ## Open bash shell in the container
	docker exec -it $(CONTAINER_NAME) bash

clean: stop ## Clean up containers and images
	@echo "Cleaning up..."
	docker rmi $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest || true
	docker volume prune -f

clean-all: clean ## Clean up everything including volumes
	@echo "Removing all volumes..."
	docker-compose down -v || true
	docker volume ls | grep apisix | awk '{print $$2}' | xargs -r docker volume rm || true

push: ## Push image to Docker Hub (requires DOCKER_USERNAME)
	@if [ -z "$(DOCKER_USERNAME)" ]; then \
		echo "Error: DOCKER_USERNAME is not set"; \
		exit 1; \
	fi
	@echo "Tagging and pushing image..."
	docker tag $(IMAGE_NAME):$(VERSION) $(DOCKER_USERNAME)/eth-ansible-apisix-etcd-arm:$(VERSION)
	docker tag $(IMAGE_NAME):$(VERSION) $(DOCKER_USERNAME)/eth-ansible-apisix-etcd-arm:latest
	docker push $(DOCKER_USERNAME)/eth-ansible-apisix-etcd-arm:$(VERSION)
	docker push $(DOCKER_USERNAME)/eth-ansible-apisix-etcd-arm:latest

info: ## Show build information
	@echo "Image Name: $(IMAGE_NAME):$(VERSION)"
	@echo "Container Name: $(CONTAINER_NAME)"
	@echo "APISIX Version: $(VERSION)"
	@echo ""
	@echo "Ports:"
	@echo "  9080 - APISIX HTTP"
	@echo "  9443 - APISIX HTTPS"
	@echo "  9180 - APISIX Admin API"
	@echo "  2379 - etcd client"

