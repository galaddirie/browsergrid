# BrowserMux - Elegant Chrome DevTools Protocol Proxy

BrowserMux is a minimalist, high-performance Chrome DevTools Protocol (CDP) proxy that enables multiple clients to connect to a single browser instance with clean, efficient code.

## Architecture

BrowserMux follows a clean, layered architecture:

### Core Components

1. **CDP Proxy** (`internal/browser/proxy.go`) - The heart of the system
   - Manages browser connections with automatic reconnection
   - Handles client lifecycle with graceful cleanup
   - Broadcasts messages efficiently using a single `fanOut` method
   - Dispatches events for monitoring and debugging

2. **HTTP API** (`internal/api/server.go`) - Lightweight HTTP interface
   - Uses `httputil.ReverseProxy` for all CDP endpoints (eliminates ~300 lines of duplicate code)
   - Automatically rewrites WebSocket URLs for proper routing (fixes port mapping issues in Docker)
   - Provides browser status and client management endpoints

3. **Event System** (`internal/browser/types.go`) - Simple event dispatcher
   - Streamlined interface without unnecessary handler IDs
   - Supports wildcard event listeners
   - Async event processing for performance

## Key Features

- **Minimal Code**: Elegant implementation with no unnecessary abstractions
- **High Performance**: Efficient message broadcasting and connection management
- **Auto-Reconnection**: Robust browser connection handling with automatic recovery
- **Standard Compliance**: Full Chrome DevTools Protocol compatibility
- **Easy Configuration**: Environment variables or JSON config file

## API Endpoints

### Chrome DevTools Protocol (Proxied)
All standard CDP endpoints are automatically proxied through `httputil.ReverseProxy`:

- `/json/version` - Browser version information
- `/json` or `/json/list` - List available targets/pages
- `/json/new` - Create new target/page
- `/json/activate/{targetId}` - Activate target
- `/json/close/{targetId}` - Close target
- `/json/protocol` - Get protocol definition

### WebSocket Connections
- `/devtools/{path}` - WebSocket endpoint for CDP communication

### Management API
- `/api/browser` - Browser information and status
- `/api/clients` - Connected clients information
- `/health` - Health check endpoint

## Configuration

Configure via environment variables:

```bash
# Required
BROWSER_URL=ws://localhost:9222/devtools/browser

# Optional
PORT=8080
FRONTEND_URL=http://localhost:80
MAX_MESSAGE_SIZE=1048576
CONNECTION_TIMEOUT_SECONDS=10
```

Or use a JSON config file:

```json
{
  "port": "8080",
  "browser_url": "ws://localhost:9222/devtools/browser",
  "frontend_url": "http://localhost:80",
  "max_message_size": 1048576,
  "connection_timeout_seconds": 10
}
```

## Usage

### Basic Usage

```bash
# Start with default configuration
./browsermux

# Start with custom browser URL
BROWSER_URL=ws://chrome:9222/devtools/browser ./browsermux

# Start with config file
CONFIG_PATH=config.json ./browsermux

# Override settings with CLI flags (takes precedence over env/config file)
./browsermux \
  --browser-url ws://chrome:9222/devtools/browser \
  --port 9090 \
  --frontend-url http://localhost:8080
```

### Docker Usage

```bash
# Build and run
docker build -t browsermux .
docker run -p 8080:8080 -e BROWSER_URL=ws://chrome:9222/devtools/browser browsermux
```

## Development

### Building

```bash
go build ./cmd/browsermux
```

### Testing

```bash
go test ./...
```

### Code Structure

The codebase is organized for clarity and maintainability:

```
cmd/browsermux/          # Application entry point
internal/
  ├── api/               # HTTP server and reverse proxy
  ├── browser/           # CDP proxy and client management
  ├── config/            # Configuration management
  └── api/middleware/    # HTTP middleware
```

## Performance

BrowserMux is designed for efficiency:

- **Single Message Broadcast**: Uses one `fanOut` method for all message distribution
- **Reverse Proxy**: Eliminates duplicate HTTP handling code
- **Efficient Locking**: Minimal lock contention with read-write mutexes
- **Async Events**: Non-blocking event processing
- **Connection Pooling**: Efficient WebSocket connection management

## Monitoring

BrowserMux provides built-in monitoring through its event system:

```go
// Register event handlers
dispatcher.Register(browser.EventClientConnected, func(event browser.Event) {
    log.Printf("Client connected: %s", event.SourceID)
})

dispatcher.Register(browser.EventCDPCommand, func(event browser.Event) {
    log.Printf("CDP command: %s", event.Method)
})
```

## License

[Your License Here]
