package api

import (
	"bytes"
	"encoding/json"
	"io"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strconv"
	"strings"
	"time"
)

func NewCDPReverseProxy(browserBaseURL, frontendBaseURL string) (*httputil.ReverseProxy, error) {
	target, err := url.Parse(browserBaseURL)
	if err != nil {
		return nil, err
	}
	internalPort := portOf(target.Host)

	proxy := httputil.NewSingleHostReverseProxy(target)

	proxy.Director = func(r *http.Request) {
		originalHost := r.Host
		if xfHost := r.Header.Get("X-Forwarded-Host"); xfHost != "" {
			originalHost = xfHost
		}
		if r.Header.Get("X-External-Host") == "" {
			r.Header.Set("X-External-Host", originalHost)
		}
		if r.Header.Get("X-External-Scheme") == "" {
			if xfProto := r.Header.Get("X-Forwarded-Proto"); xfProto != "" {
				r.Header.Set("X-External-Scheme", xfProto)
			}
		}
		r.Header.Set("X-Forwarded-Host", originalHost)

		r.URL.Scheme = target.Scheme
		r.URL.Host = target.Host
		r.Host = target.Host
	}

	proxy.ModifyResponse = func(resp *http.Response) error {
		ct := resp.Header.Get("Content-Type")
		if !strings.HasPrefix(ct, "application/json") {
			return nil
		}

		extScheme := firstNonEmpty(
			resp.Request.Header.Get("X-External-Scheme"),
			resp.Request.Header.Get("X-Forwarded-Proto"),
		)
		if extScheme == "" {
			extScheme = "http"
		}
		extHost := firstNonEmpty(
			resp.Request.Header.Get("X-External-Host"),
			resp.Request.Header.Get("X-Forwarded-Host"),
		)
		if extHost == "" {
			extHost = resp.Request.Host
		}

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return err
		}
		_ = resp.Body.Close()

		rewritten, err := rewriteCDPJSON(body, extScheme, extHost, internalPort)
		if err != nil {
			rewritten = body
		}

		resp.Body = io.NopCloser(bytes.NewReader(rewritten))
		resp.ContentLength = int64(len(rewritten))
		resp.Header.Set("Content-Length", strconv.Itoa(len(rewritten)))
		return nil
	}

	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		http.Error(w, http.StatusText(http.StatusBadGateway), http.StatusBadGateway)
	}

	proxy.Transport = &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   1 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		TLSHandshakeTimeout:   2 * time.Second,
		ResponseHeaderTimeout: 2 * time.Second,
		ExpectContinueTimeout: 500 * time.Millisecond,
		MaxIdleConnsPerHost:   32,
	}

	return proxy, nil
}

func portOf(hostPort string) string {
	_, port, err := net.SplitHostPort(hostPort)
	if err != nil {
		return ""
	}
	return port
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}

func rewriteCDPJSON(body []byte, extScheme, extHost, internalPort string) ([]byte, error) {
	var any interface{}
	if err := json.Unmarshal(body, &any); err != nil {
		return nil, err
	}

	switch v := any.(type) {
	case map[string]interface{}:
		rewriteCDPObject(v, extScheme, extHost)
	case []interface{}:
		for _, item := range v {
			if m, ok := item.(map[string]interface{}); ok {
				rewriteCDPObject(m, extScheme, extHost)
			}
		}
	default:
		return body, nil
	}

	out, err := json.Marshal(any)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func rewriteCDPObject(m map[string]interface{}, extScheme, extHost string) {
	var wsPath string
	if raw, ok := m["webSocketDebuggerUrl"].(string); ok && raw != "" {
		if u, err := url.Parse(raw); err == nil {
			wsPath = u.EscapedPath()
			if u.RawQuery != "" {
				wsPath += "?" + u.RawQuery
			}
		}
	}

	if wsPath == "" {
		if id, ok := m["id"].(string); ok && id != "" {
			if m["type"] == "page" {
				wsPath = "/devtools/page/" + id
			}
		}
	}

	wsScheme := "ws"
	if strings.EqualFold(extScheme, "https") || strings.EqualFold(extScheme, "wss") {
		wsScheme = "wss"
	}

	if wsPath != "" {
		wsURL := wsScheme + "://" + extHost + wsPath
		m["webSocketDebuggerUrl"] = wsURL
		m["devtoolsFrontendUrl"] = wsURL
		if _, ok := m["devtoolsFrontendUrlCompat"]; ok {
			m["devtoolsFrontendUrlCompat"] = wsURL
		}
	}
}
