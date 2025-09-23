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

- Docker and Docker Compose
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

3. Start the development environment:
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

4. Access the application:
   - Web interface: http://localhost:4000
   - Database admin: http://localhost:8080
   - Prometheus metrics: http://localhost:9568/metrics

### Port Mapping

- **Web interface**: 4000
- **Database**: 5432
- **Database admin**: 8080
- **CDP (Chrome DevTools)**: 9222 (fixed port)
- **Prometheus metrics**: 9568

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

## Production Deployment

For production deployment, use the main Dockerfile and docker-compose.yml:

```bash
docker-compose up -d
```

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
- Docker settings

## Local Development (without Docker)

If you prefer to run locally without Docker:

1. Install dependencies:
   ```bash
   mix deps.get
   ```

2. Create and migrate your database:
   ```bash
   mix ecto.setup
   ```

3. Start Phoenix endpoint:
   ```bash
   mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

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
