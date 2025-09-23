package browser

import (
	"errors"
	"log"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 512 * 1024
)

func (c *Client) ToModel() *ClientDTO {
	return &ClientDTO{
		ID:        c.ID,
		Connected: c.Connected,
		Metadata:  c.Metadata,
		CreatedAt: c.CreatedAt,
	}
}

func NewClient(id string, conn *websocket.Conn, dispatcher EventDispatcher, cdpProxy CDPProxyInterface, metadata map[string]interface{}) *Client {
	return &Client{
		ID:         id,
		Conn:       conn,
		Send:       make(chan []byte, 256),
		Dispatcher: dispatcher,
		CDPProxy:   cdpProxy,
		Metadata:   metadata,
		CreatedAt:  time.Now(),
		Connected:  true,
	}
}

func (c *Client) Close() error {
	c.Connected = false

	c.Dispatcher.Dispatch(Event{
		Type:       EventClientDisconnected,
		SourceType: "client",
		SourceID:   c.ID,
		Timestamp:  time.Now(),
	})

	return c.Conn.Close()
}

func (c *Client) SendMessage(message []byte) error {
	select {
	case c.Send <- message:
		return nil
	default:
		return errors.New("send channel is full")
	}
}

func (c *Client) ProcessMessage(message []byte) {
	cdpMsg, err := ParseCDPMessage(message)
	if err == nil {
		log.Printf("Received message from client %s: %s (id: %d)", c.ID, cdpMsg.Method, cdpMsg.ID)

		c.Dispatcher.Dispatch(Event{
			Type:       EventCDPCommand,
			Method:     cdpMsg.Method,
			Params:     cdpMsg.Params,
			SourceType: "client",
			SourceID:   c.ID,
			Timestamp:  time.Now(),
		})
	} else {
		log.Printf("Received message from client %s: %s", c.ID, string(message))
	}

	c.CDPProxy.HandleClientMessage(c.ID, message)
}
