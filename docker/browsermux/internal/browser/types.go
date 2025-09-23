package browser

import (
	"encoding/json"
	"reflect"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type CDPMessage struct {
	ID     int                    `json:"id,omitempty"`
	Method string                 `json:"method,omitempty"`
	Params map[string]interface{} `json:"params,omitempty"`
	Result json.RawMessage        `json:"result,omitempty"`
	Error  *CDPError              `json:"error,omitempty"`
}

type CDPError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (m *CDPMessage) IsCommand() bool {
	return m.ID != 0 && m.Method != ""
}

func (m *CDPMessage) IsEvent() bool {
	return m.ID == 0 && m.Method != ""
}

func (m *CDPMessage) IsResponse() bool {
	return m.ID != 0 && m.Method == ""
}

func ParseCDPMessage(data []byte) (*CDPMessage, error) {
	msg := &CDPMessage{}
	if err := json.Unmarshal(data, msg); err != nil {
		return nil, err
	}
	return msg, nil
}

func MatchesCDPFilter(msg *CDPMessage, methodFilter string, paramsFilter map[string]interface{}) bool {
	if methodFilter != "*" && methodFilter != msg.Method {
		return false
	}

	if len(paramsFilter) == 0 {
		return true
	}

	for key, expectedValue := range paramsFilter {
		parts := strings.Split(key, ".")
		actualValue := interface{}(msg.Params)

		for _, part := range parts {
			if m, ok := actualValue.(map[string]interface{}); ok {
				if v, exists := m[part]; exists {
					actualValue = v
				} else {
					return false
				}
			} else {
				return false
			}
		}

		if !reflect.DeepEqual(actualValue, expectedValue) {
			return false
		}
	}

	return true
}

type EventType string

const (
	EventCDPCommand EventType = "cdp.command"
	EventCDPEvent   EventType = "cdp.event"

	EventClientConnected    EventType = "client.connected"
	EventClientDisconnected EventType = "client.disconnected"
)

type Event struct {
	Type       EventType              `json:"type"`
	Method     string                 `json:"method,omitempty"`
	Params     map[string]interface{} `json:"params,omitempty"`
	SourceType string                 `json:"source_type,omitempty"`
	SourceID   string                 `json:"source_id,omitempty"`
	Timestamp  time.Time              `json:"timestamp"`
}

type EventHandler func(Event)

type EventDispatcher interface {
	Register(eventType EventType, handler EventHandler)
	Dispatch(event Event)
}

type simpleEventDispatcher struct {
	handlers map[EventType][]EventHandler
	mu       sync.RWMutex
}

func NewEventDispatcher() EventDispatcher {
	return &simpleEventDispatcher{
		handlers: make(map[EventType][]EventHandler),
	}
}

func (d *simpleEventDispatcher) Register(eventType EventType, handler EventHandler) {
	d.mu.Lock()
	defer d.mu.Unlock()

	d.handlers[eventType] = append(d.handlers[eventType], handler)
}

func (d *simpleEventDispatcher) Dispatch(event Event) {
	d.mu.RLock()
	defer d.mu.RUnlock()

	if handlers, ok := d.handlers[event.Type]; ok {
		for _, handler := range handlers {
			go handler(event)
		}
	}

	if handlers, ok := d.handlers["*"]; ok {
		for _, handler := range handlers {
			go handler(event)
		}
	}
}

type Client struct {
	ID         string
	Conn       *websocket.Conn
	Send       chan []byte
	Dispatcher EventDispatcher
	CDPProxy   CDPProxyInterface
	Metadata   map[string]interface{}
	CreatedAt  time.Time
	Connected  bool
}

type ClientDTO struct {
	ID        string                 `json:"id"`
	Conn      *websocket.Conn        `json:"-"`
	Messages  chan []byte            `json:"-"`
	Connected bool                   `json:"connected"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
}

type ClientManager interface {
	AddClient(conn *websocket.Conn, metadata map[string]interface{}) (string, error)
	RemoveClient(clientID string) error
	GetClients() []*ClientDTO
	GetClientCount() int
}

type ConnectionManager interface {
	Connect() error
	Disconnect() error
	IsConnected() bool
	GetInfo() (*BrowserInfo, error)
}

type MessageHandler interface {
	HandleClientMessage(clientID string, message []byte) error
	HandleBrowserMessage(message []byte) error
}

type CDPProxyInterface interface {
	ClientManager
	MessageHandler
}
