package main

import (
	"net/url"
	"os"
	"strings"
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

	// Fixed resource IDs (optional — auto-generated if empty).
	// Setting these makes credentials survive volume resets.
	ProjectID      string // Fixed Zitadel project ID
	AdminUIAppID   string // Fixed OIDC application ID for admin-ui
	S2SUserID      string // Fixed machine user ID for Go service S2S (private_key_jwt)
	PlatformUserID string // Fixed machine user ID for platform-UI S2S (private_key_jwt)

	// S2S public key for machine users (private_key_jwt).
	S2SPublicKey string // PEM-encoded RSA public key (from S2S_PUBLIC_KEY env var)

	// TrustedDomains are additional domains Zitadel should accept requests from.
	// In local dev, Go services in k3d reach Zitadel via "zitadel-api" hostname,
	// but ZITADEL_EXTERNALDOMAIN is "localhost". Adding "zitadel-api" as a trusted
	// domain makes Zitadel accept Host: zitadel-api.
	TrustedDomains []string // Comma-separated (from TRUSTED_DOMAINS env var)

	// SystemPrivateKey is a PEM-encoded RSA private key for System API JWT auth.
	// Required only when TrustedDomains is set (AddCustomDomain needs system.domain.write).
	SystemPrivateKey string // From SYSTEM_PRIVATE_KEY env var

	// SystemUser is the key name matching ZITADEL_SYSTEMAPIUSERS config.
	// Used as iss/sub in the System API JWT.
	SystemUser string // From SYSTEM_USER env var (default: "ecommerce-seed")
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

		ProjectID:      os.Getenv("PROJECT_ID"),
		AdminUIAppID:   os.Getenv("ADMIN_UI_APP_ID"),
		S2SUserID:      os.Getenv("S2S_USER_ID"),
		PlatformUserID: os.Getenv("PLATFORM_USER_ID"),

		S2SPublicKey: os.Getenv("S2S_PUBLIC_KEY"),

		TrustedDomains: parseTrustedDomains(os.Getenv("TRUSTED_DOMAINS")),

		SystemPrivateKey: os.Getenv("SYSTEM_PRIVATE_KEY"),
		SystemUser:       defaultStr(os.Getenv("SYSTEM_USER"), "ecommerce-seed"),
	}
}

func defaultStr(val, fallback string) string {
	if val == "" {
		return fallback
	}
	return val
}

func parseTrustedDomains(raw string) []string {
	if raw == "" {
		return nil
	}
	var domains []string
	for _, d := range strings.Split(raw, ",") {
		if d = strings.TrimSpace(d); d != "" {
			domains = append(domains, d)
		}
	}
	return domains
}

func requireEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		fatal("Required environment variable not set", "var", key)
	}
	return v
}
