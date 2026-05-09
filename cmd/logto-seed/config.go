package main

import (
	"os"
)

type config struct {
	// LogtoURL is the base URL of the Logto instance (e.g., http://logto:3001).
	LogtoURL string

	// DatabaseURL is the PostgreSQL connection string for Logto's database.
	// Used to create a temporary bootstrap M2M app for Management API access.
	DatabaseURL string

	// API resource indicator for the ecommerce platform.
	APIResourceIndicator string

	// K8s secret output.
	KubeNamespace  string
	KubeSecretName string
	KubeAPIServer  string
}

func loadConfig() config {
	return config{
		LogtoURL:             requireEnv("LOGTO_URL"),
		DatabaseURL:          requireEnv("DB_URL"),
		APIResourceIndicator: requireEnv("API_RESOURCE_INDICATOR"),
		KubeNamespace:        os.Getenv("KUBE_NAMESPACE"),
		KubeSecretName:       os.Getenv("KUBE_SECRET_NAME"),
		KubeAPIServer:        os.Getenv("KUBE_API_SERVER"),
	}
}

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		fatal("Missing required environment variable", "key", key)
	}
	return v
}
