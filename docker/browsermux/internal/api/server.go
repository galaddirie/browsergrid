package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"

	"browsermux/internal/api/middleware"
	"browsermux/internal/browser"
	"browsermux/internal/config"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

type Server struct {
	router          *mux.Router
	server          *http.Server
	cdpProxy        *browser.CDPProxy
	eventDispatcher browser.EventDispatcher
	browserBaseURL  string
	frontendBaseURL string
	config          *config.Config
}

func NewServer(cdpProxy *browser.CDPProxy, eventDispatcher browser.EventDispatcher, port string, cfg *config.Config) *Server {
	router := mux.NewRouter()

	browserBaseURL := normalizeBrowserURL(cdpProxy.GetConfig().BrowserURL)
	frontendBaseURL := strings.TrimSuffix(cfg.FrontendURL, "/")

	server := &Server{
		router:          router,
		cdpProxy:        cdpProxy,
		eventDispatcher: eventDispatcher,
		browserBaseURL:  browserBaseURL,
		frontendBaseURL: frontendBaseURL,
		config:          cfg,
		server: &http.Server{
			Addr:    ":" + port,
			Handler: router,
		},
	}

	server.setupRoutes()
	return server
}

func (s *Server) Start() error {
	log.Printf("Starting API server on %s", s.server.Addr)
	log.Printf("Proxying browser at %s through frontend at %s", s.browserBaseURL, s.frontendBaseURL)
	return s.server.ListenAndServe()
}

func (s *Server) Shutdown(ctx context.Context) error {
	return s.server.Shutdown(ctx)
}

func (s *Server) setupRoutes() {
	s.router.Use(middleware.Logging)
	s.router.Use(middleware.Recovery)

	cdpProxy, err := NewCDPReverseProxy(s.browserBaseURL, s.frontendBaseURL)
	if err != nil {
		log.Fatalf("Failed to create CDP reverse proxy: %v", err)
	}

	s.router.PathPrefix("/json").Handler(cdpProxy)

	s.router.HandleFunc("/devtools/{path:.*}", s.handleWebSocket)

	s.router.HandleFunc("/api/browser", s.handleBrowserInfo).Methods("GET")
	s.router.HandleFunc("/api/clients", s.handleClients).Methods("GET")

	s.router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	}).Methods("GET")
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Error upgrading connection to WebSocket: %v", err)
		return
	}

	vars := mux.Vars(r)
	path := vars["path"]

	metadata := extractClientMetadata(r)
	metadata["path"] = path

	if strings.HasPrefix(path, "page/") {
		parts := strings.Split(path, "/")
		if len(parts) > 1 {
			metadata["target_id"] = parts[1]
		}
	}

	clientID, err := s.cdpProxy.AddClient(conn, metadata)
	if err != nil {
		if errors.Is(err, browser.ErrSessionLocked) {
			log.Printf("Rejecting client connection: session already locked by another client")
			closeMsg := websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "session already locked by another client")
			_ = conn.WriteControl(websocket.CloseMessage, closeMsg, time.Now().Add(time.Second))
		} else {
			log.Printf("Error adding client: %v", err)
		}
		conn.Close()
		return
	}

	log.Printf("Client %s connected with path %s", clientID, path)
}

func (s *Server) handleBrowserInfo(w http.ResponseWriter, r *http.Request) {
	info, err := s.cdpProxy.GetInfo()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get browser info: %v", err), http.StatusInternalServerError)
		return
	}

	data := map[string]interface{}{
		"browser": info,
		"clients": s.cdpProxy.GetClientCount(),
		"status":  s.cdpProxy.IsConnected(),
	}

	w.Header().Set("Content-Type", "application/json")
	if err := writeJSON(w, data); err != nil {
		log.Printf("Error writing JSON response: %v", err)
	}
}

func (s *Server) handleClients(w http.ResponseWriter, r *http.Request) {
	clients := s.cdpProxy.GetClients()

	data := map[string]interface{}{
		"clients": clients,
		"count":   len(clients),
	}

	w.Header().Set("Content-Type", "application/json")
	if err := writeJSON(w, data); err != nil {
		log.Printf("Error writing JSON response: %v", err)
	}
}

func normalizeBrowserURL(browserURL string) string {
	if strings.HasPrefix(browserURL, "ws:") {
		browserURL = "http:" + browserURL[3:]
	} else if strings.HasPrefix(browserURL, "wss:") {
		browserURL = "https:" + browserURL[4:]
	} else if !strings.HasPrefix(browserURL, "http:") && !strings.HasPrefix(browserURL, "https:") {
		browserURL = "http://" + browserURL
	}

	if lastIndex := strings.LastIndex(browserURL, "/devtools/"); lastIndex != -1 {
		browserURL = browserURL[:lastIndex]
	}

	return strings.TrimSuffix(browserURL, "/")
}

func extractClientMetadata(r *http.Request) map[string]interface{} {
	metadata := make(map[string]interface{})

	metadata["user_agent"] = r.UserAgent()
	metadata["remote_addr"] = r.RemoteAddr

	query := r.URL.Query()
	for key, values := range query {
		if len(values) > 0 {
			metadata[key] = values[0]
		}
	}

	return metadata
}

func writeJSON(w http.ResponseWriter, data interface{}) error {
	return json.NewEncoder(w).Encode(data)
}
