Got it. Here’s a bare-bones, factual version.

---

# BrowserMux — Chrome DevTools Protocol Proxy

Minimal CDP proxy for a single browser instance with multi-client fanout. Used as a small component inside a larger system.

## Features

* Reverse proxy for all CDP HTTP routes
* WebSocket upgrade + URL rewrite (Docker/K8s compatible)
* Multi-client broadcast via single `fanOut`
* Auto-reconnect to browser
* Lightweight event dispatcher (wildcards, async)
* Config via env, JSON, or flags

## Endpoints

**Proxied CDP (via `httputil.ReverseProxy`):**

* `GET /json/version`
* `GET /json` or `/json/list`
* `POST /json/new`
* `POST /json/activate/{targetId}`
* `POST /json/close/{targetId}`
* `GET /json/protocol`

**WebSocket (CDP):**

* `GET /devtools/{path}`

**Management:**

* `GET /api/browser`
* `GET /api/clients`
* `GET /health`

## Configuration

**Env:**

```bash
# required
BROWSER_URL=ws://localhost:9222/devtools/browser

# optional
PORT=8080
MAX_MESSAGE_SIZE=1048576
CONNECTION_TIMEOUT_SECONDS=10
```

**JSON:**

```json
{
  "port": "8080",
  "browser_url": "ws://localhost:9222/devtools/browser",
  "max_message_size": 1048576,
  "connection_timeout_seconds": 10
}
```

**Flags override env + JSON.**

## Usage

```bash
# default
./browsermux

# custom browser URL
BROWSER_URL=ws://chrome:9222/devtools/browser ./browsermux

# config file
CONFIG_PATH=./config.json ./browsermux

# flags
./browsermux \
  --browser-url ws://chrome:9222/devtools/browser \
  --port 9090
```

### Docker

```bash
docker build -t browsermux .
docker run -p 8080:8080 \
  -e BROWSER_URL=ws://chrome:9222/devtools/browser \
  browsermux
```

## Build / Test

```bash
go build -o browsermux ./cmd/browsermux
go test ./...
```

## Code Layout

```
cmd/browsermux/          # entry point
internal/
  api/                   # HTTP server + reverse proxy
  api/middleware/        # middleware
  browser/               # CDP proxy + clients
  config/                # config loader
```

## Core Files

* `internal/browser/proxy.go` — browser connection, auto-reconnect, client lifecycle, `fanOut`, events
* `internal/api/server.go` — HTTP server, CDP reverse proxy, WS rewrite, management routes
* `internal/browser/types.go` — event types + dispatcher (wildcards, async)

## Events ( Monitoring )

```go
dispatcher.Register(browser.EventClientConnected, func(ev browser.Event) { /* ... */ })
dispatcher.Register(browser.EventCDPCommand,    func(ev browser.Event) { /* ... */ })
```

## Performance Notes

* Single broadcast path (`fanOut`)
* Reverse proxy avoids duplicated HTTP handlers
* RW locks kept minimal on hot paths
* Async event handlers
* Connection pooling where applicable

## Operational Notes

* No CDP-level auth added. Use network-layer auth or isolate per tenant or proxy with capabilities url
* Idle clients are cleaned up on WS close.
* Verify WS rewrite/Host/Origin under custom ingress.

