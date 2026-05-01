package main

import (
	"context"
	"log/slog"

	"github.com/zitadel/zitadel-go/v3/pkg/client"
)

// =============================================================================
// Zitadel Seed
//
// Configures a Zitadel instance for the ecommerce platform.
// Uses the Zitadel Go SDK (gRPC) for type-safe API interactions.
// All settings are controlled via environment variables.
//
// What it creates:
//   1. Project "ecommerce" with roles (super_admin, catalog_manager, viewer, service_account)
//   2. OIDC Application "admin-ui" (Authorization Code + PKCE)
//   3. Machine User "ecommerce-service" for Go backend S2S auth (private_key_jwt)
//   4. Machine User "platform-service" for platform-UI S2S auth (private_key_jwt)
//   5. Actions v2 Target + Execution for permissions mapping webhook
// =============================================================================

type seeder struct {
	cfg     config
	ctx     context.Context
	secrets *secretStore
	client  *client.Client

	orgID           string
	projectID       string
	adminUIClientID string
}

func main() {
	s := &seeder{
		cfg:     loadConfig(),
		ctx:     context.Background(),
		secrets: newSecretStore(),
	}

	slog.Info("Starting Zitadel seed")

	s.waitReady()
	s.readPAT()
	s.connect()
	s.resolveOrgID()
	s.setupProject()
	s.setupAdminUIApp()
	s.setupGoServiceAccount()
	s.setupPlatformServiceAccount()
	s.setupPermissionsAction()
	// s.setupDemoUser()

	s.secrets.publish(s.cfg)

	slog.Info("Seed complete",
		"zitadel_console", s.cfg.ZitadelURL+"/ui/console",
		"admin_ui_client_id", s.adminUIClientID,
	)
}
