package browser

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestGetBrowserInfo(t *testing.T) {
	t.Run("Success", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/json/version" {
				t.Errorf("Expected path /json/version, got %s", r.URL.Path)
			}

			response := map[string]interface{}{
				"Browser":              "Chrome/120.0.0.0",
				"Protocol-Version":     "1.3",
				"User-Agent":           "Mozilla/5.0 Chrome/120.0.0.0",
				"webSocketDebuggerUrl": "ws://localhost:9222/devtools/browser/12345",
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
		}))
		defer server.Close()

		wsURL := strings.Replace(server.URL, "http://", "ws://", 1) + "/devtools/browser"

		info, err := GetBrowserInfo(wsURL)
		if err != nil {
			t.Fatalf("GetBrowserInfo() error = %v", err)
		}

		if info == nil {
			t.Fatal("GetBrowserInfo() returned nil info")
		}

		if info.Version != "Chrome/120.0.0.0" {
			t.Errorf("Expected version 'Chrome/120.0.0.0', got %s", info.Version)
		}

		if info.UserAgent != "Mozilla/5.0 Chrome/120.0.0.0" {
			t.Errorf("Expected user agent 'Mozilla/5.0 Chrome/120.0.0.0', got %s", info.UserAgent)
		}

		if info.Status != "connected" {
			t.Errorf("Expected status 'connected', got %s", info.Status)
		}

		if !strings.Contains(info.URL, "ws://") {
			t.Errorf("Expected WebSocket URL, got %s", info.URL)
		}
	})

	t.Run("HTTP Error", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusInternalServerError)
		}))
		defer server.Close()

		wsURL := strings.Replace(server.URL, "http://", "ws://", 1) + "/devtools/browser"

		info, err := GetBrowserInfo(wsURL)
		if err == nil {
			t.Fatal("Expected error for HTTP 500 response")
		}
		if info != nil {
			t.Fatal("Expected nil info for error case")
		}
	})

	t.Run("Invalid JSON", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte("invalid json"))
		}))
		defer server.Close()

		wsURL := strings.Replace(server.URL, "http://", "ws://", 1) + "/devtools/browser"

		info, err := GetBrowserInfo(wsURL)
		if err == nil {
			t.Fatal("Expected error for invalid JSON")
		}
		if info != nil {
			t.Fatal("Expected nil info for invalid JSON")
		}
	})

	t.Run("Missing webSocketDebuggerUrl", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			response := map[string]interface{}{
				"Browser":          "Chrome/120.0.0.0",
				"Protocol-Version": "1.3",
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
		}))
		defer server.Close()

		wsURL := strings.Replace(server.URL, "http://", "ws://", 1) + "/devtools/browser"

		info, err := GetBrowserInfo(wsURL)
		if err == nil {
			t.Fatal("Expected error for missing webSocketDebuggerUrl")
		}
		if info != nil {
			t.Fatal("Expected nil info for missing webSocketDebuggerUrl")
		}
	})

	t.Run("Empty webSocketDebuggerUrl", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			response := map[string]interface{}{
				"Browser":              "Chrome/120.0.0.0",
				"webSocketDebuggerUrl": "",
			}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
		}))
		defer server.Close()

		wsURL := strings.Replace(server.URL, "http://", "ws://", 1) + "/devtools/browser"

		info, err := GetBrowserInfo(wsURL)
		if err == nil {
			t.Fatal("Expected error for empty webSocketDebuggerUrl")
		}
		if info != nil {
			t.Fatal("Expected nil info for empty webSocketDebuggerUrl")
		}
	})

	t.Run("Invalid Browser URL", func(t *testing.T) {
		info, err := GetBrowserInfo("invalid-url")
		if err == nil {
			t.Fatal("Expected error for invalid URL")
		}
		if info != nil {
			t.Fatal("Expected nil info for invalid URL")
		}
	})
}

func TestLastIndexOf(t *testing.T) {
	tests := []struct {
		name     string
		str      string
		substr   string
		expected int
	}{
		{"Found at end", "hello world", "world", 6},
		{"Found at beginning", "hello world", "hello", 0},
		{"Found in middle", "hello world hello", "hello", 12},
		{"Not found", "hello world", "xyz", -1},
		{"Empty substring", "hello", "", 5},
		{"Empty string", "", "hello", -1},
		{"Exact match", "hello", "hello", 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := lastIndexOf(tt.str, tt.substr)
			if result != tt.expected {
				t.Errorf("lastIndexOf(%q, %q) = %d, expected %d", tt.str, tt.substr, result, tt.expected)
			}
		})
	}
}

func TestReplaceHostPort(t *testing.T) {
	tests := []struct {
		name        string
		originalURL string
		newHost     string
		expected    string
	}{
		{
			"Replace host and port",
			"ws://localhost:9222/devtools/browser",
			"192.168.1.100:8080",
			"ws://192.168.1.100:8080/devtools/browser",
		},
		{
			"Replace only host",
			"ws://localhost:9222/devtools/browser",
			"example.com:9222",
			"ws://example.com:9222/devtools/browser",
		},
		{
			"HTTPS URL",
			"https://localhost:9222/json/version",
			"example.com:8080",
			"https://example.com:8080/json/version",
		},
		{
			"Invalid URL returns original",
			"not-a-valid-url",
			"example.com:8080",
			"not-a-valid-url",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := replaceHostPort(tt.originalURL, tt.newHost)
			if result != tt.expected {
				t.Errorf("replaceHostPort(%q, %q) = %q, expected %q", tt.originalURL, tt.newHost, result, tt.expected)
			}
		})
	}
}

func TestTestBrowserConnection(t *testing.T) {
	t.Run("Invalid URL", func(t *testing.T) {
		err := TestBrowserConnection("invalid-url", 1*time.Second)
		if err == nil {
			t.Fatal("Expected error for invalid URL")
		}
	})

	t.Run("Connection Timeout", func(t *testing.T) {
		err := TestBrowserConnection("ws://192.0.2.1:9999/devtools/browser", 100*time.Millisecond)
		if err == nil {
			t.Fatal("Expected error for connection timeout")
		}
	})
}
