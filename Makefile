IMAGE_NAME=nginx:minik8s
NAMESPACE=minik8s
CHART_PATH=./minik8s/

.PHONY: all deploy build test load-image init lint helm tunnel clean

all: init deploy

deploy: build load-image lint helm

# Build local Docker image
build:
	docker build . --tag $(IMAGE_NAME)

# Test container with Docker
# Stops any existing container named "minik8s" and runs a new one
# Maps port 8080 on host to port 80 in the container
test: build
	docker stop minik8s || true
	docker run --rm --name minik8s -p 0.0.0.0:8080:80 $(IMAGE_NAME)

# Load built image into Minikube
load-image:
	minikube image load $(IMAGE_NAME)

# Initialize Minikube cluster, requires minikube and kubectl installed
init:
	minikube start
	minikube addons enable ingress
	kubectl --context=minikube cluster-info

# Lint and validate the Helm chart
lint:
	helm lint $(CHART_PATH)

# Deploy the project with Helm
helm:
	helm upgrade --install --namespace $(NAMESPACE) --create-namespace minik8s-release $(CHART_PATH)

# Run the minikube tunnel command
tunnel:
	minikube tunnel

# Delete Kubernetes resources
clean:
	kubectl delete namespace $(NAMESPACE)
