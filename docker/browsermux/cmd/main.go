package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"browsermux/internal/api"
	"browsermux/internal/browser"
	"browsermux/internal/config"
)

func main() {
	log.Println("Starting Browsergrid CDP Proxy...")

	cfg := loadConfig()

	cdpProxyConfig := browser.CDPProxyConfig{
		BrowserURL:        cfg.BrowserURL,
		MaxMessageSize:    cfg.MaxMessageSize,
		ConnectionTimeout: time.Duration(cfg.ConnectionTimeoutSeconds) * time.Second,
	}

	dispatcher := browser.NewEventDispatcher()

	cdpProxy, err := browser.NewCDPProxy(dispatcher, cdpProxyConfig)
	if err != nil {
		log.Fatalf("Failed to create CDP Proxy: %v", err)
	}

	server := api.NewServer(cdpProxy, dispatcher, cfg.Port, cfg)

	go func() {
		if err := server.Start(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server shutdown failed: %v", err)
	}

	if err := cdpProxy.Shutdown(); err != nil {
		log.Fatalf("CDP Proxy shutdown failed: %v", err)
	}

	log.Println("Server gracefully stopped")
}

func loadConfig() *config.Config {
	cfg, err := config.Load()
	if err != nil {
		log.Printf("Warning: Failed to load config, using defaults: %v", err)
		return config.DefaultConfig()
	}
	return cfg
}
