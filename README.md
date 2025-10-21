# MiniK8s

Small, sample K8s deployment of an nginx image on Minikube with Helm.

This is just a POC, but hypothetically you could deploy something useful with it by modifying the ConfigMap object
that's used to deploy the files, in `minik8s/templates/configmap.yaml`. It's currently used to mount files
from the `minik8s/html/` directory into the nginx container to serve them.

## How It Works: Dual index.html Pattern

This project uses two `index.html` files with different purposes:

1. **`/index.html`** (root directory) - Baked into the Docker image as a fallback
   - Shows an error message if ConfigMap mounting fails
   - Built into the container during `docker build`
   - Located at `/usr/share/nginx/html/index.html` in the container

2. **`/minik8s/html/index.html`** - Deployed via Kubernetes ConfigMap
   - The actual content served when deployment is successful
   - Mounted over the fallback file via ConfigMap volume mount
   - Easy to update without rebuilding the Docker image

To customize the served content, edit files in `minik8s/html/` and redeploy with Helm. The ConfigMap
will automatically update, and pods will restart due to the checksum annotation in the deployment.

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│ Development Machine                                                │
│                                                                    │
│  ┌──────────────┐                                                  │
│  │ Dockerfile   │──► docker build ──► nginx:minik8s image          │
│  │ index.html   │                           │                      │
│  │ entrypoint.sh│                           │                      │
│  └──────────────┘                           ▼                      │
│                                    minikube image load             │
│                                             │                      │
│  ┌──────────────┐                           │                      │
│  │ Helm Chart   │                           │                      │
│  │ - templates/ │──► helm upgrade ──────────┼─────────────────┐    │
│  │ - values.yaml│                           │                 │    │
│  │ - html/      │                           │                 │    │
│  └──────────────┘                           │                 │    │
│                                    ┌────────▼─────────────────▼──┐ │
│                                    │ Minikube (Kubernetes)       │ │
│                                    │                             │ │
│                                    │  ┌────────────────────┐     │ │
│  Browser ────────────────────────────►│ Ingress (nginx)    │     │ │
│  http://minik8s.local/             │  └────────┬───────────┘     │ │
│                                    │           │                 │ │
│                                    │  ┌────────▼───────────┐     │ │
│                                    │  │ Service (ClusterIP)│     │ │
│                                    │  │ Port: 8080 → 80    │     │ │
│                                    │  └────────┬───────────┘     │ │
│                                    │           │                 │ │
│                                    │  ┌────────▼───────────┐     │ │
│                                    │  │ Deployment         │     │ │
│                                    │  │ (2 replicas)       │     │ │
│                                    │  │                    │     │ │
│                                    │  │  ┌──────────────┐  │     │ │
│                                    │  │  │ Pod 1        │  │     │ │
│                                    │  │  │ nginx:minik8s│  │     │ │
│                                    │  │  │ + ConfigMap  │  │     │ │
│                                    │  │  └──────────────┘  │     │ │
│                                    │  │  ┌──────────────┐  │     │ │
│                                    │  │  │ Pod 2        │  │     │ │
│                                    │  │  │ nginx:minik8s│  │     │ │
│                                    │  │  │ + ConfigMap  │  │     │ │
│                                    │  │  └──────────────┘  │     │ │
│                                    │  └────────▲───────────┘     │ │
│                                    │           │                 │ │
│                                    │  ┌────────┴───────────┐     │ │
│                                    │  │ ConfigMap          │     │ │
│                                    │  │ (html/index.html)  │     │ │
│                                    │  └────────────────────┘     │ │
│                                    └─────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

**Flow:**
1. Build Docker image with nginx + fallback HTML
2. Load image into Minikube's internal registry
3. Deploy Helm chart which creates:
   - ConfigMap with custom HTML files
   - Deployment with 2 nginx pods (ConfigMap mounted over default HTML)
   - Service to expose pods internally
   - Ingress to route external traffic
4. Access via browser through Ingress (requires minikube tunnel on Docker Desktop)

## Requirements

- Minikube
- Docker
- Helm
- `kubectl` (optional)
- Make (optional)

Also, a `minik8s.local` host entry is needed in your system's `hosts` file. E.g. for Linux, it will be `/etc/hosts` and on Windows
it's `C:\Windows\System32\drivers\etc\hosts`.

If you use Docker Desktop, use `127.0.0.1` as the address. Otherwise, use the IP you get from `minikube ip`.

## Deployment with Makefile

You can just run the following to run the full deployment:
```sh
make
```

If you encounter an error failing to call an Ingress validation webhook, that means that the deploy was too fast and
the Minikube's Ingress Controller did not load yet. Rerun the `deploy` Make target after a few seconds, or check the
status of the addon by running:
```sh
kubectl -n ingress-nginx get pods
```
The `ingress-nginx-controller-*` pod should be ready and running.

If you use Docker Desktop, you must also run the Minikube tunnel:
```sh
make tunnel
```

You will then be able to access the site through your web browser at http://minik8s.local/, or use a curl command:
```sh
curl -vvvv http://minik8s.local/
```

### Delete all k8s objects

All objects are in the `minik8s` namespace. Delete it to delete all the objects from this repository.

Just run:
```sh
make clean
```

## Step-by-step manual deploy

### Build local Docker image

```sh
docker build . --tag nginx:minik8s
```

#### Test container with Docker

```sh
docker run --rm --name minik8s -p 0.0.0.0:8080:80 nginx:minik8s
```

And try to access http://localhost:8080/.

### Minikube setup

Install Minikube from [their site](https://minikube.sigs.k8s.io/docs/start/).

```sh
minikube start
```

Test the local cluster with kubectl. Minikube installation will modify your default kubectl configuration file. In Linux, this will be `~/.kube/config`.
```sh
kubectl cluster-info
```

Load the built image from Docker into Minikube:
```sh
minikube image load nginx:minik8s
```

Enable the ingress addon for Minikube:
```sh
minikube addons enable ingress
```

### Kubernetes deploy with Helm

Deploy the Helm chart for MiniK8s:
```sh
helm upgrade --install --namespace minik8s --create-namespace minik8s-release ./minik8s/
```

You will then be able to access the site through your web browser at http://minik8s.local/, or use a curl command:
```sh
curl -vvvv http://minik8s.local/
```

### Expose the Minikube deployment (Docker Desktop only)

In a separate terminal, you must start a Minikube Tunnel.

```sh
minikube tunnel
```

### Delete all k8s objects

Delete the `minik8s` namespace to delete all other objects:
```sh
kubectl delete namespace minik8s
```
