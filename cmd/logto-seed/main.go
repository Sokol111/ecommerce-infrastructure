package main

import "log/slog"

// =============================================================================
// Logto Seed
//
// Configures a Logto instance for the ecommerce platform via Management API.
// Self-contained: creates its own bootstrap access via direct DB insert,
// seeds all resources, then deletes the bootstrap app.
//
// What it creates:
//   1. API Resource (https://api.sokolshop.com) with RBAC scopes
//   2. Roles: super_admin, catalog_manager, viewer (User), service_account (M2M)
//   3. OIDC Application "admin-ui" (Traditional Web, Authorization Code + PKCE)
//   4. M2M Application "ecommerce-service" (M2M auth for Go backends)
//   5. M2M Application "platform-service" (M2M auth for platform-UI)
//   6. M2M Application "tenant-service-m2m" (Logto Management API access)
//   7. Custom JWT claims configuration (role + tenant)
//   8. K8s Secret "logto-credentials" with all client IDs/secrets
// =============================================================================

func main() {
	cfg := loadConfig()

	slog.Info("Starting Logto seed")

	waitReady(cfg)

	// Create temporary bootstrap M2M app via direct DB access.
	bootstrap := createBootstrapApp(cfg.DatabaseURL)

	seedCfg := loadSeedConfig("seed.json")

	s := &seeder{
		cfg:            cfg,
		seed:           seedCfg,
		secrets:        make(map[string]string),
		client:         newClient(cfg.LogtoURL, bootstrap.appID, bootstrap.appSecret),
		bootstrapAppID: bootstrap.appID,
		scopeIDs:       make(map[string]string),
	}

	s.createAPIResource()
	s.createRoles()
	s.createApplications()
	s.configureJWTCustomizer()
	s.configureSignInExperience()
	s.cleanupBootstrapApp()

	publishSecrets(s.secrets, s.cfg)
	slog.Info("Seed complete")
}
