# Browsergrid

A distributed browser automation platform built with Elixir and Phoenix LiveView.


## Development Setup

### Prerequisites

- [Taskfile](https://taskfile.dev/#/installation) (`task` CLI)
- [Kind](https://kind.sigs.k8s.io/) >= 0.20
- `kubectl`
- Docker

### Quick Start

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd browsergrid
   ```

2. Copy environment variables:
   ```bash
   cp env.example .env
   ```

3. Bootstrap the Kubernetes cluster:
   ```bash
   task k8s:bootstrap
   ```

4. Deploy Browsergrid:
   ```bash
   task app:deploy
   ```

5. Access the application:
   ```bash
   task app:port-forward
   # Browsergrid is now available at http://localhost:4000
   ```

### Detailed Kubernetes Development Setup

Browsergrid uses a Taskfile-powered workflow that provisions a local Kind cluster and deploys the control plane alongside on-demand browser pods.

#### One-time bootstrap

```bash
# Create the cluster and bootstrap namespace/RBAC
task k8s:bootstrap

# (Optional) build and load local browser images
task browsers:load
```

#### Deploy Browsergrid into the cluster

```bash
# Build the Phoenix release image and push it into Kind, then apply manifests
task app:deploy

# Follow logs from the running pod
task app:logs
```

#### Access the web UI

Expose the in-cluster service on your workstation:

```bash
task app:port-forward
# Browsergrid is now available at http://localhost:4000
```

When finished, tear everything down with `task destroy`.
