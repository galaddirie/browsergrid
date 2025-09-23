package config

import (
	"encoding/json"
	"os"
	"strconv"
)

type Config struct {
	Port string `json:"port"`

	BrowserURL               string `json:"browser_url"`
	FrontendURL              string `json:"frontend_url"`
	MaxMessageSize           int    `json:"max_message_size"`
	ConnectionTimeoutSeconds int    `json:"connection_timeout_seconds"`
}

func Load() (*Config, error) {
	config := &Config{}

	if configPath := os.Getenv("CONFIG_PATH"); configPath != "" {
		file, err := os.Open(configPath)
		if err == nil {
			defer file.Close()

			decoder := json.NewDecoder(file)
			if err := decoder.Decode(config); err == nil {
				return config, nil
			}
		}
	}

	if port := os.Getenv("PORT"); port != "" {
		config.Port = port
	} else {
		config.Port = "8080"
	}

	if browserURL := os.Getenv("BROWSER_URL"); browserURL != "" {
		config.BrowserURL = browserURL
	} else {
		config.BrowserURL = "http://localhost:6100"
	}

	if frontendURL := os.Getenv("FRONTEND_URL"); frontendURL != "" {
		config.FrontendURL = frontendURL
	} else {
		config.FrontendURL = "http://localhost:80"
	}

	if maxSize := os.Getenv("MAX_MESSAGE_SIZE"); maxSize != "" {
		if size, err := strconv.Atoi(maxSize); err == nil {
			config.MaxMessageSize = size
		} else {
			config.MaxMessageSize = 1024 * 1024
		}
	} else {
		config.MaxMessageSize = 1024 * 1024
	}

	if timeout := os.Getenv("CONNECTION_TIMEOUT_SECONDS"); timeout != "" {
		if t, err := strconv.Atoi(timeout); err == nil {
			config.ConnectionTimeoutSeconds = t
		} else {
			config.ConnectionTimeoutSeconds = 10
		}
	} else {
		config.ConnectionTimeoutSeconds = 10
	}

	return config, nil
}

func DefaultConfig() *Config {
	return &Config{
		Port:                     "8080",
		BrowserURL:               "http://localhost:9222",
		FrontendURL:              "http://localhost:80",
		MaxMessageSize:           1024 * 1024,
		ConnectionTimeoutSeconds: 10,
	}
}
