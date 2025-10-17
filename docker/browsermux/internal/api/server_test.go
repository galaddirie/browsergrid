package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"browsermux/internal/browser"
	"browsermux/internal/config"
)

func TestServerHealthCheck(t *testing.T) {
	dispatcher := browser.NewEventDispatcher()
	proxyConfig := browser.DefaultConfig()

	proxyConfig.BrowserURL = "ws://localhost:9999/devtools/browser"

	proxy := &browser.CDPProxy{}

	cfg := &config.Config{
		Port:       "8080",
		BrowserURL: "ws://localhost:9999/devtools/browser",
	}

	server := NewServer(proxy, dispatcher, "8080", cfg)

	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	server.router.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("Health check returned wrong status code: got %v want %v", status, http.StatusOK)
	}

	expected := "OK"
	if rr.Body.String() != expected {
		t.Errorf("Health check returned unexpected body: got %v want %v", rr.Body.String(), expected)
	}
}

func TestExtractClientMetadata(t *testing.T) {
	req, err := http.NewRequest("GET", "/test?param1=value1&param2=value2", nil)
	if err != nil {
		t.Fatal(err)
	}

	req.Header.Set("User-Agent", "test-agent")
	req.RemoteAddr = "127.0.0.1:1234"

	metadata := extractClientMetadata(req)

	if metadata["user_agent"] != "test-agent" {
		t.Errorf("Expected user_agent to be 'test-agent', got %v", metadata["user_agent"])
	}

	if metadata["remote_addr"] != "127.0.0.1:1234" {
		t.Errorf("Expected remote_addr to be '127.0.0.1:1234', got %v", metadata["remote_addr"])
	}

	if metadata["param1"] != "value1" {
		t.Errorf("Expected param1 to be 'value1', got %v", metadata["param1"])
	}

	if metadata["param2"] != "value2" {
		t.Errorf("Expected param2 to be 'value2', got %v", metadata["param2"])
	}
}

func TestNormalizeBrowserURL(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"ws://localhost:9222/devtools/browser", "http://localhost:9222"},
		{"wss://localhost:9222/devtools/browser", "https://localhost:9222"},
		{"http://localhost:9222/devtools/browser", "http://localhost:9222"},
		{"localhost:9222", "http://localhost:9222"},
		{"http://localhost:9222/", "http://localhost:9222"},
	}

	for _, test := range tests {
		result := normalizeBrowserURL(test.input)
		if result != test.expected {
			t.Errorf("normalizeBrowserURL(%q) = %q, want %q", test.input, result, test.expected)
		}
	}
}
