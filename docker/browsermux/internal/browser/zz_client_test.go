package browser

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

type mockDispatcher struct {
	events []Event
}

func (m *mockDispatcher) Register(eventType EventType, handler EventHandler) {
}

func (m *mockDispatcher) Dispatch(event Event) {
	m.events = append(m.events, event)
}

type mockCDPProxy struct {
	clients map[string]*Client
}

func (m *mockCDPProxy) HandleClientMessage(clientID string, message []byte) error {
	return nil
}

func (m *mockCDPProxy) RemoveClient(clientID string) error {
	delete(m.clients, clientID)
	return nil
}

func (m *mockCDPProxy) AddClient(conn *websocket.Conn, metadata map[string]interface{}) (string, error) {
	return "mock-client-id", nil
}

func (m *mockCDPProxy) GetClients() []*ClientDTO {
	return nil
}

func (m *mockCDPProxy) GetClientCount() int {
	return len(m.clients)
}

func (m *mockCDPProxy) Connect() error {
	return nil
}

func (m *mockCDPProxy) Disconnect() error {
	return nil
}

func (m *mockCDPProxy) IsConnected() bool {
	return true
}

func (m *mockCDPProxy) GetInfo() (*BrowserInfo, error) {
	return nil, nil
}

func (m *mockCDPProxy) HandleBrowserMessage(message []byte) error {
	return nil
}

func createWebSocketTestServer() *httptest.Server {
	upgrader := websocket.Upgrader{
		CheckOrigin: func(r *http.Request) bool {
			return true
		},
	}

	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer conn.Close()

		for {
			messageType, p, err := conn.ReadMessage()
			if err != nil {
				break
			}
			if err := conn.WriteMessage(messageType, p); err != nil {
				break
			}
		}
	}))
}

func TestNewClient(t *testing.T) {
	server := createWebSocketTestServer()
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Skip("Cannot establish WebSocket connection for test:", err)
	}
	defer conn.Close()

	dispatcher := &mockDispatcher{}
	mockProxy := &mockCDPProxy{
		clients: make(map[string]*Client),
	}
	metadata := map[string]interface{}{
		"user_agent": "test-agent",
		"source":     "test",
	}

	client := NewClient("test-client-1", conn, dispatcher, mockProxy, metadata)

	if client == nil {
		t.Fatal("NewClient() returned nil")
	}

	if client.ID != "test-client-1" {
		t.Errorf("Expected ID 'test-client-1', got %s", client.ID)
	}

	if client.Conn != conn {
		t.Error("Client connection does not match provided connection")
	}

	if client.Dispatcher == nil {
		t.Error("Client dispatcher should not be nil")
	}

	if client.Connected != true {
		t.Error("Expected new client to be connected")
	}

	if client.Metadata["user_agent"] != "test-agent" {
		t.Error("Client metadata not properly set")
	}

	if client.Send == nil {
		t.Error("Client send channel should be initialized")
	}

	if client.CreatedAt.IsZero() {
		t.Error("Client CreatedAt should be set")
	}
}

func TestClientToModel(t *testing.T) {
	client := &Client{
		ID:        "test-client",
		Connected: true,
		Metadata: map[string]interface{}{
			"user_agent": "test-agent",
		},
		CreatedAt: time.Now(),
	}

	dto := client.ToModel()

	if dto == nil {
		t.Fatal("ToModel() returned nil")
	}

	if dto.ID != client.ID {
		t.Errorf("Expected ID %s, got %s", client.ID, dto.ID)
	}

	if dto.Connected != client.Connected {
		t.Errorf("Expected Connected %v, got %v", client.Connected, dto.Connected)
	}

	if dto.Metadata["user_agent"] != "test-agent" {
		t.Error("Metadata not properly copied to DTO")
	}

	if dto.CreatedAt != client.CreatedAt {
		t.Error("CreatedAt not properly copied to DTO")
	}
}

func TestClientSendMessage(t *testing.T) {
	t.Run("Success", func(t *testing.T) {
		client := &Client{
			ID:        "test-client",
			Send:      make(chan []byte, 256),
			Connected: true,
		}

		message := []byte(`{"method":"Page.navigate","params":{"url":"https://example.com"}}`)

		err := client.SendMessage(message)
		if err != nil {
			t.Fatalf("SendMessage() error = %v", err)
		}

		select {
		case receivedMessage := <-client.Send:
			if string(receivedMessage) != string(message) {
				t.Errorf("Expected message %s, got %s", string(message), string(receivedMessage))
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Message not received in send channel")
		}
	})

	t.Run("Channel Full", func(t *testing.T) {
		server := createWebSocketTestServer()
		defer server.Close()

		wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Skip("Cannot establish WebSocket connection for test:", err)
		}
		defer conn.Close()

		client := &Client{
			ID:   "test-client",
			Conn: conn,
			Send: make(chan []byte, 1),
		}

		client.Send <- []byte("first message")

		err = client.SendMessage([]byte("second message"))
		if err == nil {
			t.Error("Expected error when send channel is full")
		}
	})
}

func TestClientClose(t *testing.T) {
	dispatcher := &mockDispatcher{}
	mockProxy := &mockCDPProxy{
		clients: make(map[string]*Client),
	}

	server := createWebSocketTestServer()
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Skip("Cannot establish WebSocket connection for test:", err)
	}

	client := &Client{
		ID:         "test-client",
		Conn:       conn,
		Dispatcher: dispatcher,
		CDPProxy:   mockProxy,
		Connected:  true,
	}

	err = client.Close()
	if err != nil {
		t.Errorf("Close() error = %v", err)
	}

	if client.Connected {
		t.Error("Expected client to be disconnected after Close()")
	}

	if len(dispatcher.events) != 1 {
		t.Errorf("Expected 1 event dispatched, got %d", len(dispatcher.events))
	}

	event := dispatcher.events[0]
	if event.Type != EventClientDisconnected {
		t.Errorf("Expected EventClientDisconnected, got %s", event.Type)
	}

	if event.SourceID != "test-client" {
		t.Errorf("Expected SourceID 'test-client', got %s", event.SourceID)
	}
}

func TestProcessMessage(t *testing.T) {
	dispatcher := &mockDispatcher{}
	mockProxy := &mockCDPProxy{
		clients: make(map[string]*Client),
	}

	client := &Client{
		ID:         "test-client",
		Dispatcher: dispatcher,
		CDPProxy:   mockProxy,
	}

	t.Run("Valid CDP Message", func(t *testing.T) {
		dispatcher.events = nil

		message := []byte(`{"id":1,"method":"Page.navigate","params":{"url":"https://example.com"}}`)
		client.ProcessMessage(message)

		if len(dispatcher.events) != 1 {
			t.Errorf("Expected 1 event dispatched, got %d", len(dispatcher.events))
		}

		event := dispatcher.events[0]
		if event.Type != EventCDPCommand {
			t.Errorf("Expected EventCDPCommand, got %s", event.Type)
		}

		if event.Method != "Page.navigate" {
			t.Errorf("Expected method 'Page.navigate', got %s", event.Method)
		}

		if event.SourceID != "test-client" {
			t.Errorf("Expected SourceID 'test-client', got %s", event.SourceID)
		}
	})

	t.Run("Invalid JSON Message", func(t *testing.T) {
		dispatcher.events = nil

		message := []byte(`invalid json`)
		client.ProcessMessage(message)

		for _, event := range dispatcher.events {
			if event.Type == EventCDPCommand {
				t.Error("Should not dispatch CDP command event for invalid JSON")
			}
		}
	})
}
