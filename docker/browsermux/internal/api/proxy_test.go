package api

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestPortOf(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"localhost:32771", "32771"},
		{"localhost:61000", "61000"},
		{"127.0.0.1:8080", "8080"},
		{"localhost", ""},
		{"", ""},
		{"invalid:port:format", ""},
	}

	for _, test := range tests {
		result := portOf(test.input)
		if result != test.expected {
			t.Errorf("portOf(%q) = %q, want %q", test.input, result, test.expected)
		}
	}
}

func TestCDPReverseProxyURLRewriting(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		response := `[
			{
				"id": "E3A16CEA6D514252398E77E24DF1ACB7",
				"title": "Google Hangouts",
				"type": "background_page",
				"webSocketDebuggerUrl": "ws://localhost:61000/devtools/page/E3A16CEA6D514252398E77E24DF1ACB7"
			}
		]`
		w.Write([]byte(response))
	}))
	defer backend.Close()

	browserURL := "http://localhost:61000"

	proxy, err := NewCDPReverseProxy(browserURL, "http://localhost:80")
	if err != nil {
		t.Fatalf("Failed to create reverse proxy: %v", err)
	}

	proxy.Director = func(r *http.Request) {
		originalHost := r.Host
		r.Header.Set("X-Forwarded-Host", originalHost)

		backendURL, _ := url.Parse(backend.URL)
		r.URL.Scheme = backendURL.Scheme
		r.URL.Host = backendURL.Host
		r.Host = backendURL.Host
	}

	req := httptest.NewRequest("GET", "http://localhost:32771/json", nil)
	req.Host = "localhost:32771"

	recorder := httptest.NewRecorder()
	proxy.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", recorder.Code)
	}

	body := recorder.Body.String()

	if strings.Contains(body, ":61000") {
		t.Errorf("Response still contains internal port 61000: %s", body)
	}

	if !strings.Contains(body, ":32771") {
		t.Errorf("Response should contain external port 32771: %s", body)
	}

	expectedURL := "ws://localhost:32771/devtools/page/E3A16CEA6D514252398E77E24DF1ACB7"
	if !strings.Contains(body, expectedURL) {
		t.Errorf("Response should contain rewritten URL %s, got: %s", expectedURL, body)
	}
}

func TestCDPReverseProxyNonJSONResponse(t *testing.T) {
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte("<html>Contains :61000 port</html>"))
	}))
	defer backend.Close()

	proxy, err := NewCDPReverseProxy(backend.URL, "http://localhost:80")
	if err != nil {
		t.Fatalf("Failed to create reverse proxy: %v", err)
	}

	req := httptest.NewRequest("GET", "http://localhost:32771/some-page", nil)
	req.Host = "localhost:32771"

	recorder := httptest.NewRecorder()
	proxy.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", recorder.Code)
	}

	body := recorder.Body.String()

	if !strings.Contains(body, ":61000") {
		t.Errorf("Non-JSON response should not be rewritten, expected to contain :61000: %s", body)
	}
}
