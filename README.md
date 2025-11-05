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
   task dev:init
   ```

4. Launch Browsergrid:
   ```bash
   task dev:up
   ```

5. Access the application at http://localhost:4000


When finished, tear everything down with `task destroy`.
