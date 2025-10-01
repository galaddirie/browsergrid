# Browsergrid

A distributed browser automation platform built with Elixir and Phoenix LiveView.

## Architecture

Browsergrid uses a distributed architecture:

- **Main Phoenix Application**: Web interface and session management
- **Session Registry**: Real-time tracking of active browser sessions
- **Telemetry System**: Comprehensive metrics and monitoring
- **Supervisord**: Process management within Docker containers
- **Database**: PostgreSQL for session/node persistence

Configuration files:
- `supervisord.conf`: Process definitions and logging
- `docker-entrypoint.sh`: Startup script that initializes supervisord and waits for services

## Development Setup

### Prerequisites

- [Taskfile](https://taskfile.dev/#/installation) (`task` CLI)
- [Kind](https://kind.sigs.k8s.io/) >= 0.20
- `kubectl`
- Docker
- Local PostgreSQL & Redis
- Git

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

## Features

- **Multi-browser support**: Chrome, Chromium
- **Real-time session management**: Phoenix LiveView interface with live telemetry
- **Session Registry**: Centralized tracking of active browser sessions
- **Telemetry & Monitoring**: Comprehensive metrics collection and Prometheus export
- **Docker containerization**: Easy deployment and scaling
- **Process supervision**: Supervisord for reliable process management
- **CDP Multiplexing**: Multiple clients can connect to a single browser session

## Telemetry & Monitoring

Browsergrid includes comprehensive telemetry and monitoring:

### Metrics Collected

- **Session Lifecycle**: Creation, startup time, failures, stops
- **Node Resources**: Memory usage, CPU, WebSocket connections
- **Performance**: Request duration, startup times

### Accessing Metrics

- **LiveView Dashboard**: Real-time telemetry events in the web interface
- **Prometheus**: Metrics available at `/metrics` endpoint
- **Logs**: Detailed telemetry events logged to console

### Telemetry Events

The system emits telemetry events for:
- Session creation, startup, failure, and stopping
- Node resource usage and WebSocket connections
- Performance metrics and timing


## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

[Add your license information here]

## Environment Variables

Copy `.env.example` to `.env` and configure:
- Database credentials
- Application secrets
- Kubernetes settings

### Testing

Run tests with:
```bash
mix test
```

### Formatting

Format code with:
```bash
mix format
```

## Project Features

- **UUID Primary Keys**: Better for distributed systems and security
- **Microsecond Timestamps**: Precise ordering and debugging
- **Credo**: Code quality and style checking
- **Styler**: Automatic code formatting
- **mix test.watch**: TDD support with automatic test running
- **Custom Schema**: Pre-configured with best practices
- **Telemetry Integration**: Built-in monitoring and observability
- **Session Registry**: Real-time session tracking and discovery

## Learn more

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Telemetry](https://hexdocs.pm/telemetry/)
- [Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
- [Elixir Forum](https://elixirforum.com/c/phoenix-forum)
