package main

import (
	"context"
	"log/slog"

	actionv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/action/v2"
	applicationv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/application/v2"
	authorizationv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/authorization/v2"
	permissionv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/internal_permission/v2"
	orgv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/org/v2"
	projectv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/project/v2"
	userv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/user/v2"
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
//   3. Machine User "ecommerce-service" with Client Credentials (S2S auth)
//   4. Actions v2 Target + Execution for permissions mapping webhook
//   5. Demo admin user with super_admin role
// =============================================================================

type seeder struct {
	cfg config
	pat string
	ctx context.Context

	projects projectv2.ProjectServiceClient
	apps     applicationv2.ApplicationServiceClient
	users    userv2.UserServiceClient
	auths    authorizationv2.AuthorizationServiceClient
	actions  actionv2.ActionServiceClient
	orgs     orgv2.OrganizationServiceClient
	perms    permissionv2.InternalPermissionServiceClient

	orgID           string
	projectID       string
	adminUIClientID string
}

func main() {
	s := &seeder{
		cfg: loadConfig(),
		ctx: context.Background(),
	}

	slog.Info("Starting Zitadel seed")

	s.waitReady()
	s.readPAT()
	s.connect()
	s.resolveOrgID()
	s.setupProject()
	s.setupAdminUIApp()
	s.setupServiceAccount()
	s.setupPermissionsAction()
	s.setupDemoUser()

	slog.Info("Seed complete",
		"zitadel_console", s.cfg.ZitadelURL+"/ui/console",
		"admin_ui_client_id", s.adminUIClientID,
	)
}
