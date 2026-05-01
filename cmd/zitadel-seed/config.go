package main

import (
	"net/url"
	"os"
)

type config struct {
	ZitadelURL  string // Full URL for HTTP health checks
	Host        string // gRPC dial target hostname (extracted from URL)
	Port        string // gRPC port (extracted from URL)
	Domain      string // Zitadel external domain for gRPC :authority override
	PAT         string // Direct PAT value (from PAT env var)
	PATFile     string // Path to PAT file (from PAT_FILE env var)
	RedirectURI string // OIDC callback URI for admin-ui
	LogoutURI   string // Post-logout redirect URI
	DevMode     bool   // Allow non-HTTPS redirect URIs
	WebhookURL  string // Actions v2 webhook endpoint for permissions mapping

	// KubeNamespace and KubeSecretName control K8s secret creation.
	// When both are set, seed creates/updates a K8s Secret directly.
	// When empty, secrets are printed to stdout.
	KubeNamespace  string // From KUBE_NAMESPACE env var
	KubeSecretName string // From KUBE_SECRET_NAME env var

	// KubeAPIServer overrides the API server URL from kubeconfig.
	// Useful when running in Docker where kubeconfig points to 0.0.0.0.
	KubeAPIServer string // From KUBE_API_SERVER env var
}

func loadConfig() config {
	rawURL := requireEnv("ZITADEL_URL")
	u, err := url.Parse(rawURL)
	if err != nil {
		fatal("Invalid ZITADEL_URL", "error", err)
	}

	host := u.Hostname()
	port := u.Port()
	if port == "" {
		port = "8080"
	}

	return config{
		ZitadelURL:  rawURL,
		Host:        host,
		Port:        port,
		Domain:      requireEnv("ZITADEL_DOMAIN"),
		PAT:         os.Getenv("PAT"),
		PATFile:     os.Getenv("PAT_FILE"),
		RedirectURI: requireEnv("REDIRECT_URI"),
		LogoutURI:   requireEnv("LOGOUT_URI"),
		DevMode:     os.Getenv("DEV_MODE") == "true",
		WebhookURL:  requireEnv("WEBHOOK_URL"),

		KubeNamespace:  os.Getenv("KUBE_NAMESPACE"),
		KubeSecretName: os.Getenv("KUBE_SECRET_NAME"),
		KubeAPIServer:  os.Getenv("KUBE_API_SERVER"),
	}
}

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		fatal("Required environment variable not set", "var", key)
	}
	return v
}
