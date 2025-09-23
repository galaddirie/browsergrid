package browser

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

var _ ClientManager = (*CDPProxy)(nil)
var _ ConnectionManager = (*CDPProxy)(nil)
var _ MessageHandler = (*CDPProxy)(nil)

type CDPProxy struct {
	browserConn     *websocket.Conn
	clients         map[string]*Client
	eventDispatcher EventDispatcher
	config          CDPProxyConfig
	browserMessages chan []byte
	mu              sync.RWMutex
	connected       bool
	shutdown        chan struct{}
}

type CDPProxyConfig struct {
	BrowserURL        string
	MaxMessageSize    int
	ConnectionTimeout time.Duration
}

func (p *CDPProxy) GetConfig() CDPProxyConfig {
	return p.config
}

func DefaultConfig() CDPProxyConfig {
	return CDPProxyConfig{
		BrowserURL:        "ws://localhost:9222/devtools/browser",
		MaxMessageSize:    4 * 1024 * 1024,
		ConnectionTimeout: 10 * time.Second,
	}
}

func NewCDPProxy(dispatcher EventDispatcher, config CDPProxyConfig) (*CDPProxy, error) {
	p := &CDPProxy{
		clients:         make(map[string]*Client),
		eventDispatcher: dispatcher,
		config:          config,
		browserMessages: make(chan []byte, 100),
		shutdown:        make(chan struct{}),
	}

	// Start connection retry logic in background instead of failing immediately
	go p.connectWithRetry()

	go p.processBrowserMessages()
	go p.processClientMessages()

	return p, nil
}

// connectWithRetry continuously tries to connect to the browser until successful
func (p *CDPProxy) connectWithRetry() {
	maxRetries := 30 // Try for up to 30 attempts
	retryDelay := 2 * time.Second

	for attempt := 1; attempt <= maxRetries; attempt++ {
		select {
		case <-p.shutdown:
			return
		default:
		}

		log.Printf("Attempting to connect to browser at %s (attempt %d/%d)", p.config.BrowserURL, attempt, maxRetries)

		if err := p.Connect(); err != nil {
			log.Printf("Failed to connect to browser (attempt %d/%d): %v", attempt, maxRetries, err)

			if attempt == maxRetries {
				log.Printf("Failed to connect to browser after %d attempts, will continue trying indefinitely", maxRetries)
				// Continue trying indefinitely with longer delays
				for {
					select {
					case <-p.shutdown:
						return
					default:
					}

					time.Sleep(5 * time.Second)
					log.Printf("Retrying connection to browser at %s", p.config.BrowserURL)

					if err := p.Connect(); err == nil {
						log.Printf("Successfully connected to browser at %s", p.config.BrowserURL)
						return
					}
				}
			}

			time.Sleep(retryDelay)
			continue
		}

		log.Printf("Successfully connected to browser at %s", p.config.BrowserURL)
		return
	}
}

func (p *CDPProxy) Connect() error {
	log.Printf("Attempting to connect to browser at %s", p.config.BrowserURL)
	browserInfo, err := GetBrowserInfo(p.config.BrowserURL)
	if err != nil {
		return fmt.Errorf("failed to get browser info: %w", err)
	}

	actualBrowserURL := browserInfo.URL
	log.Printf("Using browser WebSocket URL: %s (transformed from original endpoint)", actualBrowserURL)

	if err := p.connectToBrowser(actualBrowserURL); err != nil {
		return fmt.Errorf("browser connection error: %w", err)
	}
	return nil
}

func (p *CDPProxy) Disconnect() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.browserConn != nil {
		if err := p.browserConn.Close(); err != nil {
			return fmt.Errorf("error closing browser connection: %w", err)
		}
		p.browserConn = nil
	}

	p.connected = false
	return nil
}

func (p *CDPProxy) IsConnected() bool {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.connected
}

func (p *CDPProxy) GetInfo() (*BrowserInfo, error) {
	return GetBrowserInfo(p.config.BrowserURL)
}

func (p *CDPProxy) HandleClientMessage(clientID string, message []byte) error {
	p.mu.RLock()
	if !p.connected || p.browserConn == nil {
		p.mu.RUnlock()
		return fmt.Errorf("browser not connected")
	}
	p.mu.RUnlock()

	if err := p.browserConn.WriteMessage(websocket.TextMessage, message); err != nil {
		log.Printf("Error sending message to browser: %v", err)
		return fmt.Errorf("failed to send message to browser: %w", err)
	}
	return nil
}

func (p *CDPProxy) HandleBrowserMessage(message []byte) error {
	p.fanOut(message)
	return nil
}

func (p *CDPProxy) fanOut(message []byte) {
	if cdpMsg, err := ParseCDPMessage(message); err == nil && cdpMsg.IsEvent() {
		p.eventDispatcher.Dispatch(Event{
			Type:       EventCDPEvent,
			Method:     cdpMsg.Method,
			Params:     cdpMsg.Params,
			SourceType: "browser",
			Timestamp:  time.Now(),
		})
	}

	p.mu.RLock()
	for _, client := range p.clients {
		if client.Connected {
			select {
			case client.Send <- message:
			default:
				log.Printf("Client %s message buffer full, dropping message", client.ID)
			}
		}
	}
	p.mu.RUnlock()
}

func (p *CDPProxy) connectToBrowser(browserURL string) error {
	dialer := websocket.Dialer{
		HandshakeTimeout: p.config.ConnectionTimeout,
	}

	conn, _, err := dialer.Dial(browserURL, nil)
	if err != nil {
		return fmt.Errorf("websocket connection error: %w", err)
	}

	p.browserConn = conn
	p.connected = true
	p.browserConn.SetReadLimit(int64(p.config.MaxMessageSize))

	log.Printf("Connected to browser at %s", browserURL)
	return nil
}

func (p *CDPProxy) AddClient(conn *websocket.Conn, metadata map[string]interface{}) (string, error) {
	clientID := uuid.New().String()
	client := NewClient(clientID, conn, p.eventDispatcher, p, metadata)

	p.mu.Lock()
	p.clients[clientID] = client
	p.mu.Unlock()

	p.eventDispatcher.Dispatch(Event{
		Type:       EventClientConnected,
		SourceID:   clientID,
		SourceType: "client",
		Timestamp:  time.Now(),
		Params: map[string]interface{}{
			"client_id": clientID,
			"metadata":  metadata,
		},
	})

	go p.handleClientMessages(client)
	go p.sendMessagesToClient(client)

	return clientID, nil
}

func (p *CDPProxy) RemoveClient(clientID string) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	client, exists := p.clients[clientID]
	if !exists {
		return fmt.Errorf("client %s not found", clientID)
	}

	close(client.Send)
	delete(p.clients, clientID)

	p.eventDispatcher.Dispatch(Event{
		Type:       EventClientDisconnected,
		SourceID:   clientID,
		SourceType: "client",
		Timestamp:  time.Now(),
		Params: map[string]interface{}{
			"client_id": clientID,
		},
	})

	log.Printf("Removed client %s, remaining clients: %d", clientID, len(p.clients))
	return nil
}

func (p *CDPProxy) GetClientCount() int {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return len(p.clients)
}

func (p *CDPProxy) GetClients() []*ClientDTO {
	p.mu.RLock()
	defer p.mu.RUnlock()

	clients := make([]*ClientDTO, 0, len(p.clients))
	for _, client := range p.clients {
		clients = append(clients, client.ToModel())
	}
	return clients
}

func (p *CDPProxy) Shutdown() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	close(p.shutdown)

	if p.browserConn != nil {
		p.browserConn.Close()
	}
	p.connected = false

	for clientID, client := range p.clients {
		if client.Connected {
			if client.Conn != nil {
				client.Conn.Close()
			}
			client.Connected = false
		}
		delete(p.clients, clientID)
	}

	log.Println("CDP Proxy shutdown complete")
	return nil
}

func (p *CDPProxy) handleClientMessages(client *Client) {
	defer func() {
		p.RemoveClient(client.ID)
	}()

	client.Conn.SetReadLimit(int64(p.config.MaxMessageSize))

	for {
		_, message, err := client.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("Client %s error: %v", client.ID, err)
			}
			break
		}

		if cdpMsg, err := ParseCDPMessage(message); err == nil && cdpMsg.IsCommand() {
			p.eventDispatcher.Dispatch(Event{
				Type:       EventCDPCommand,
				Method:     cdpMsg.Method,
				Params:     cdpMsg.Params,
				SourceID:   client.ID,
				SourceType: "client",
				Timestamp:  time.Now(),
			})
		}

		select {
		case p.browserMessages <- message:
		case <-p.shutdown:
			return
		}
	}
}

func (p *CDPProxy) sendMessagesToClient(client *Client) {
	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()

	for {
		select {
		case message, ok := <-client.Send:
			if !ok {
				return
			}

			if err := client.Conn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("Error sending message to client %s: %v", client.ID, err)
				return
			}
		case <-ticker.C:
			if err := client.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				log.Printf("Error sending ping to client %s: %v", client.ID, err)
				return
			}
		case <-p.shutdown:
			return
		}
	}
}

func (p *CDPProxy) processBrowserMessages() {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Recovered in processBrowserMessages: %v", r)
		}
	}()

	for {
		select {
		case <-p.shutdown:
			return
		default:
		}

		// Wait for browser connection to be established
		p.mu.RLock()
		connected := p.connected
		browserConn := p.browserConn
		p.mu.RUnlock()

		if !connected || browserConn == nil {
			// Wait a bit before checking again
			time.Sleep(100 * time.Millisecond)
			continue
		}

		_, message, err := browserConn.ReadMessage()
		if err != nil {
			log.Printf("Error reading from browser: %v", err)

			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				if err := p.reconnectToBrowser(); err != nil {
					log.Printf("Failed to reconnect to browser: %v", err)
					time.Sleep(5 * time.Second)
				}
			}
			continue
		}

		p.fanOut(message)
	}
}

func (p *CDPProxy) processClientMessages() {
	for {
		select {
		case message := <-p.browserMessages:
			// Wait for browser connection to be established
			p.mu.RLock()
			connected := p.connected
			browserConn := p.browserConn
			p.mu.RUnlock()

			if !connected || browserConn == nil {
				// Browser not connected, drop the message
				log.Printf("Dropping client message - browser not connected")
				continue
			}

			if err := browserConn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("Error sending message to browser: %v", err)

				if err := p.reconnectToBrowser(); err != nil {
					log.Printf("Failed to reconnect to browser: %v", err)
				}
			}
		case <-p.shutdown:
			return
		}
	}
}

func (p *CDPProxy) reconnectToBrowser() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.browserConn != nil {
		p.browserConn.Close()
	}

	log.Printf("Attempting to reconnect to browser at %s", p.config.BrowserURL)
	browserInfo, err := GetBrowserInfo(p.config.BrowserURL)
	if err != nil {
		p.connected = false
		return fmt.Errorf("failed to get browser info for reconnection: %w", err)
	}

	actualBrowserURL := browserInfo.URL
	log.Printf("Reconnecting using WebSocket URL: %s (transformed from original endpoint)", actualBrowserURL)

	dialer := websocket.Dialer{
		HandshakeTimeout: p.config.ConnectionTimeout,
	}

	p.browserConn, _, err = dialer.Dial(actualBrowserURL, nil)
	if err != nil {
		p.connected = false
		return fmt.Errorf("failed to reconnect to browser: %w", err)
	}

	p.connected = true
	p.browserConn.SetReadLimit(int64(p.config.MaxMessageSize))

	log.Printf("Reconnected to browser at %s", actualBrowserURL)
	return nil
}
