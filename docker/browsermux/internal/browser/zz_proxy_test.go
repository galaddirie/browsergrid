package browser

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestDefaultConfig(t *testing.T) {
	config := DefaultConfig()

	if config.BrowserURL != "ws://localhost:9222/devtools/browser" {
		t.Errorf("Expected default BrowserURL 'ws://localhost:9222/devtools/browser', got %s", config.BrowserURL)
	}

	if config.MaxMessageSize != 1024*1024 {
		t.Errorf("Expected default MaxMessageSize %d, got %d", 1024*1024, config.MaxMessageSize)
	}

	if config.ConnectionTimeout != 10*time.Second {
		t.Errorf("Expected default ConnectionTimeout %v, got %v", 10*time.Second, config.ConnectionTimeout)
	}
}

func TestCDPProxyGetConfig(t *testing.T) {
	config := CDPProxyConfig{
		BrowserURL:        "ws://test:9222/devtools/browser",
		MaxMessageSize:    512 * 1024,
		ConnectionTimeout: 5 * time.Second,
	}

	proxy := &CDPProxy{
		config: config,
	}

	retrievedConfig := proxy.GetConfig()
	if retrievedConfig.BrowserURL != config.BrowserURL {
		t.Errorf("Expected BrowserURL %s, got %s", config.BrowserURL, retrievedConfig.BrowserURL)
	}

	if retrievedConfig.MaxMessageSize != config.MaxMessageSize {
		t.Errorf("Expected MaxMessageSize %d, got %d", config.MaxMessageSize, retrievedConfig.MaxMessageSize)
	}

	if retrievedConfig.ConnectionTimeout != config.ConnectionTimeout {
		t.Errorf("Expected ConnectionTimeout %v, got %v", config.ConnectionTimeout, retrievedConfig.ConnectionTimeout)
	}
}

func createMockBrowserServer() *httptest.Server {
	upgrader := websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool { return true },
	}

	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/json/version" {
			response := map[string]interface{}{
				"Browser":              "Mock Browser/1.0",
				"Protocol-Version":     "1.3",
				"User-Agent":           "Mock Browser Agent",
				"webSocketDebuggerUrl": "ws://localhost:9999/devtools/browser/12345",
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
			return
		}

		if strings.Contains(r.URL.Path, "/devtools/browser") {
			conn, err := upgrader.Upgrade(w, r, nil)
			if err != nil {
				return
			}
			defer conn.Close()

			for {
				_, message, err := conn.ReadMessage()
				if err != nil {
					break
				}

				if err := conn.WriteMessage(websocket.TextMessage, message); err != nil {
					break
				}
			}
		}
	}))
}

func TestNewCDPProxy(t *testing.T) {
	t.Run("Invalid Browser URL", func(t *testing.T) {
		dispatcher := &mockDispatcher{}
		config := CDPProxyConfig{
			BrowserURL:        "ws://nonexistent:9999/devtools/browser",
			MaxMessageSize:    1024 * 1024,
			ConnectionTimeout: 1 * time.Second,
		}

		proxy, err := NewCDPProxy(dispatcher, config)
		if err == nil {
			t.Fatal("Expected error for invalid browser URL")
		}
		if proxy != nil {
			t.Fatal("Expected nil proxy for error case")
		}
	})
}

func TestCDPProxyClientManagement(t *testing.T) {
	dispatcher := &mockDispatcher{}

	proxy := &CDPProxy{
		clients:         make(map[string]*Client),
		eventDispatcher: dispatcher,
		config:          DefaultConfig(),
		browserMessages: make(chan []byte, 100),
		shutdown:        make(chan struct{}),
		connected:       false,
	}

	t.Run("GetClientCount - Empty", func(t *testing.T) {
		count := proxy.GetClientCount()
		if count != 0 {
			t.Errorf("Expected 0 clients, got %d", count)
		}
	})

	t.Run("GetClients - Empty", func(t *testing.T) {
		clients := proxy.GetClients()
		if len(clients) != 0 {
			t.Errorf("Expected 0 clients, got %d", len(clients))
		}
	})

	t.Run("RemoveClient - Not Found", func(t *testing.T) {
		err := proxy.RemoveClient("nonexistent")
		if err == nil {
			t.Fatal("Expected error for nonexistent client")
		}
	})

	server := createWebSocketTestServer()
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Skip("Cannot establish WebSocket connection for test:", err)
	}
	defer conn.Close()

	t.Run("AddClient", func(t *testing.T) {
		metadata := map[string]interface{}{
			"user_agent": "test-agent",
		}

		clientID, err := proxy.AddClient(conn, metadata)
		if err != nil {
			t.Fatalf("AddClient() error = %v", err)
		}

		if clientID == "" {
			t.Fatal("AddClient() returned empty client ID")
		}

		if proxy.GetClientCount() != 1 {
			t.Errorf("Expected 1 client, got %d", proxy.GetClientCount())
		}

		clients := proxy.GetClients()
		if len(clients) != 1 {
			t.Errorf("Expected 1 client in list, got %d", len(clients))
		}

		client := clients[0]
		if client.ID != clientID {
			t.Errorf("Expected client ID %s, got %s", clientID, client.ID)
		}

		if client.Metadata["user_agent"] != "test-agent" {
			t.Error("Client metadata not properly set")
		}

		connectEvents := 0
		for _, event := range dispatcher.events {
			if event.Type == EventClientConnected {
				connectEvents++
			}
		}
		if connectEvents == 0 {
			t.Error("Expected ClientConnected event to be dispatched")
		}

		t.Run("Reject additional client while locked", func(t *testing.T) {
			conn2, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
			if err != nil {
				t.Skip("Cannot establish second WebSocket connection for test:", err)
			}
			defer conn2.Close()

			_, err = proxy.AddClient(conn2, map[string]interface{}{
				"user_agent": "test-agent-2",
			})

			if !errors.Is(err, ErrSessionLocked) {
				t.Fatalf("Expected ErrSessionLocked, got %v", err)
			}
		})

		t.Run("RemoveClient", func(t *testing.T) {
			err := proxy.RemoveClient(clientID)
			if err != nil {
				t.Fatalf("RemoveClient() error = %v", err)
			}

			if proxy.GetClientCount() != 0 {
				t.Errorf("Expected 0 clients after removal, got %d", proxy.GetClientCount())
			}

			disconnectEvents := 0
			for _, event := range dispatcher.events {
				if event.Type == EventClientDisconnected {
					disconnectEvents++
				}
			}
			if disconnectEvents == 0 {
				t.Error("Expected ClientDisconnected event to be dispatched")
			}

			t.Run("Allow new client after lock released", func(t *testing.T) {
				conn3, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
				if err != nil {
					t.Skip("Cannot establish replacement WebSocket connection for test:", err)
				}
				defer conn3.Close()

				replacementID, err := proxy.AddClient(conn3, map[string]interface{}{
					"user_agent": "test-agent-3",
				})
				if err != nil {
					t.Fatalf("Expected new client to attach after lock release, got %v", err)
				}

				if err := proxy.RemoveClient(replacementID); err != nil {
					t.Fatalf("Failed to cleanup replacement client: %v", err)
				}
			})
		})
	})
}

func TestCDPProxyConnectionState(t *testing.T) {
	dispatcher := &mockDispatcher{}

	proxy := &CDPProxy{
		clients:         make(map[string]*Client),
		eventDispatcher: dispatcher,
		config:          DefaultConfig(),
		browserMessages: make(chan []byte, 100),
		shutdown:        make(chan struct{}),
		connected:       false,
	}

	t.Run("IsConnected - False", func(t *testing.T) {
		if proxy.IsConnected() {
			t.Error("Expected proxy to not be connected initially")
		}
	})

	proxy.connected = true

	t.Run("IsConnected - True", func(t *testing.T) {
		if !proxy.IsConnected() {
			t.Error("Expected proxy to be connected after setting connected = true")
		}
	})
}

func TestCDPProxyHandleClientMessage(t *testing.T) {
	dispatcher := &mockDispatcher{}

	proxy := &CDPProxy{
		clients:         make(map[string]*Client),
		eventDispatcher: dispatcher,
		config:          DefaultConfig(),
		browserMessages: make(chan []byte, 100),
		shutdown:        make(chan struct{}),
		connected:       false,
		browserConn:     nil,
	}

	t.Run("Not Connected", func(t *testing.T) {
		message := []byte(`{"method":"Page.navigate","params":{"url":"https://example.com"}}`)

		err := proxy.HandleClientMessage("client-1", message)
		if err == nil {
			t.Fatal("Expected error when browser not connected")
		}
	})
}

func TestCDPProxyHandleBrowserMessage(t *testing.T) {
	dispatcher := &mockDispatcher{}

	proxy := &CDPProxy{
		clients:         make(map[string]*Client),
		eventDispatcher: dispatcher,
		config:          DefaultConfig(),
		browserMessages: make(chan []byte, 100),
		shutdown:        make(chan struct{}),
		connected:       true,
	}

	client := &Client{
		ID:        "test-client",
		Send:      make(chan []byte, 256),
		Connected: true,
	}
	proxy.clients["test-client"] = client

	t.Run("CDP Event Message", func(t *testing.T) {
		dispatcher.events = nil

		message := []byte(`{"method":"Page.loadEventFired","params":{"timestamp":123456}}`)

		err := proxy.HandleBrowserMessage(message)
		if err != nil {
			t.Fatalf("HandleBrowserMessage() error = %v", err)
		}

		eventFound := false
		for _, event := range dispatcher.events {
			if event.Type == EventCDPEvent && event.Method == "Page.loadEventFired" {
				eventFound = true
				break
			}
		}
		if !eventFound {
			t.Error("Expected CDP event to be dispatched")
		}

		select {
		case receivedMessage := <-client.Send:
			if string(receivedMessage) != string(message) {
				t.Errorf("Expected message %s, got %s", string(message), string(receivedMessage))
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Message not received by client")
		}
	})

	t.Run("Non-Event Message", func(t *testing.T) {
		dispatcher.events = nil

		message := []byte(`{"id":"1","result":{"frameId":"frame123"}}`)

		err := proxy.HandleBrowserMessage(message)
		if err != nil {
			t.Fatalf("HandleBrowserMessage() error = %v", err)
		}

		for _, event := range dispatcher.events {
			if event.Type == EventCDPEvent {
				t.Error("Should not dispatch CDP event for non-event messages")
			}
		}

		select {
		case receivedMessage := <-client.Send:
			if string(receivedMessage) != string(message) {
				t.Errorf("Expected message %s, got %s", string(message), string(receivedMessage))
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Message not received by client")
		}
	})
}

func TestCDPProxyShutdown(t *testing.T) {
	dispatcher := &mockDispatcher{}

	proxy := &CDPProxy{
		clients:         make(map[string]*Client),
		eventDispatcher: dispatcher,
		config:          DefaultConfig(),
		browserMessages: make(chan []byte, 100),
		shutdown:        make(chan struct{}),
		connected:       true,
	}

	client := &Client{
		ID:        "test-client",
		Send:      make(chan []byte, 256),
		Connected: true,
	}
	proxy.clients["test-client"] = client

	err := proxy.Shutdown()
	if err != nil {
		t.Fatalf("Shutdown() error = %v", err)
	}

	if proxy.connected {
		t.Error("Expected proxy to be disconnected after shutdown")
	}

	if len(proxy.clients) != 0 {
		t.Errorf("Expected all clients to be removed after shutdown, got %d", len(proxy.clients))
	}

	if client.Connected {
		t.Error("Client connection should be marked as disconnected")
	}
}

func TestCDPProxyDisconnect(t *testing.T) {
	dispatcher := &mockDispatcher{}

	server := createWebSocketTestServer()
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Skip("Cannot establish WebSocket connection for test:", err)
	}

	proxy := &CDPProxy{
		clients:         make(map[string]*Client),
		eventDispatcher: dispatcher,
		config:          DefaultConfig(),
		browserMessages: make(chan []byte, 100),
		shutdown:        make(chan struct{}),
		connected:       true,
		browserConn:     conn,
	}

	err = proxy.Disconnect()
	if err != nil {
		t.Fatalf("Disconnect() error = %v", err)
	}

	if proxy.connected {
		t.Error("Expected proxy to be disconnected")
	}

	if proxy.browserConn != nil {
		t.Error("Expected browser connection to be nil after disconnect")
	}
}
