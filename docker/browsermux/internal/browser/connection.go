package browser

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/gorilla/websocket"
)

type BrowserInfo struct {
	URL            string    `json:"url"`
	Version        string    `json:"version"`
	UserAgent      string    `json:"user_agent"`
	StartTime      time.Time `json:"start_time"`
	ConnectionTime time.Time `json:"connection_time"`
	Status         string    `json:"status"`
}

func GetBrowserInfo(browserURL string) (*BrowserInfo, error) {
	parsedBrowserURL, err := url.Parse(browserURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse browser URL: %w", err)
	}

	baseURL := browserURL
	if len(baseURL) > 3 && baseURL[:3] == "ws:" {
		baseURL = "http:" + baseURL[3:]
	} else if len(baseURL) > 4 && baseURL[:4] == "wss:" {
		baseURL = "https:" + baseURL[4:]
	}

	if lastIndex := lastIndexOf(baseURL, "/devtools/"); lastIndex != -1 {
		baseURL = baseURL[:lastIndex]
	}

	if baseURL[len(baseURL)-1] == '/' {
		baseURL = baseURL[:len(baseURL)-1]
	}

	infoURL := baseURL + "/json/version"

	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	resp, err := client.Get(infoURL)
	if err != nil {
		return nil, fmt.Errorf("failed to get browser info: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get browser info: HTTP %d", resp.StatusCode)
	}

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to parse browser info: %w", err)
	}

	info := &BrowserInfo{
		URL:            browserURL,
		ConnectionTime: time.Now(),
		Status:         "connected",
	}

	if v, ok := result["Browser"]; ok {
		info.Version = fmt.Sprintf("%v", v)
	}

	if v, ok := result["User-Agent"]; ok {
		info.UserAgent = fmt.Sprintf("%v", v)
	}

	if v, ok := result["webSocketDebuggerUrl"]; ok {
		wsURL := fmt.Sprintf("%v", v)
		if wsURL != "" {
			wsURL = replaceHostPort(wsURL, parsedBrowserURL.Host)
			info.URL = wsURL
		} else {
			return nil, fmt.Errorf("browser returned empty webSocketDebuggerUrl")
		}
	} else {
		return nil, fmt.Errorf("webSocketDebuggerUrl not found in browser info response")
	}

	return info, nil
}

func lastIndexOf(s, substr string) int {
	for i := len(s) - len(substr); i >= 0; i-- {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}

func replaceHostPort(originalURL string, newHost string) string {
	parsedURL, err := url.Parse(originalURL)
	if err != nil {
		return originalURL
	}

	if parsedURL.Host == "" {
		return originalURL
	}

	parsedURL.Host = newHost

	return parsedURL.String()
}

func TestBrowserConnection(browserURL string, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	dialer := websocket.Dialer{
		HandshakeTimeout: timeout,
	}

	conn, _, err := dialer.DialContext(ctx, browserURL, nil)
	if err != nil {
		return fmt.Errorf("failed to connect to browser: %w", err)
	}

	conn.Close()

	return nil
}
