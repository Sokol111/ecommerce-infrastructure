package main

import (
	"log/slog"

	authorizationv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/authorization/v2"
	permissionv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/internal_permission/v2"
	objectv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/object/v2"
	userv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/user/v2"
)

func (s *seeder) setupServiceAccount() {
	slog.Info("Setting up S2S service account")

	// Find or create machine user.
	users, err := s.users.ListUsers(s.ctx, &userv2.ListUsersRequest{
		Queries: []*userv2.SearchQuery{{
			Query: &userv2.SearchQuery_UserNameQuery{
				UserNameQuery: &userv2.UserNameQuery{
					UserName: "ecommerce-service",
					Method:   objectv2.TextQueryMethod_TEXT_QUERY_METHOD_EQUALS,
				},
			},
		}},
	})
	if err != nil {
		fatal("Failed to list users", "error", err)
	}

	var userID string
	if len(users.GetResult()) > 0 {
		userID = users.GetResult()[0].GetUserId()
		slog.Info("Machine user already exists", "id", userID)
	} else {
		username := "ecommerce-service"
		result, err := s.users.CreateUser(s.ctx, &userv2.CreateUserRequest{
			Username: &username,
			UserType: &userv2.CreateUserRequest_Machine_{
				Machine: &userv2.CreateUserRequest_Machine{
					Name:            "Ecommerce Service Account",
					AccessTokenType: userv2.AccessTokenType_ACCESS_TOKEN_TYPE_JWT,
				},
			},
		})
		if err != nil {
			fatal("Failed to create machine user", "error", err)
		}
		userID = result.GetId()
		slog.Info("Created machine user", "id", userID)

		// Generate client secret only for new users.
		// Secret is visible only once — copy it from the logs.
		secret, err := s.users.AddSecret(s.ctx, &userv2.AddSecretRequest{
			UserId: userID,
		})
		if err != nil {
			fatal("Failed to generate machine secret", "error", err)
		}
		slog.Info("S2S credentials generated — save these!",
			"S2S_CLIENT_ID", userID,
			"S2S_CLIENT_SECRET", secret.GetClientSecret(),
		)
	}

	// Grant service_account role (idempotent — CreateAuthorization is a no-op if exists).
	//nolint:errcheck // grant may already exist
	s.auths.CreateAuthorization(s.ctx, &authorizationv2.CreateAuthorizationRequest{
		UserId:    userID,
		ProjectId: s.projectID,
		RoleKeys:  []string{"service_account"},
	})
	slog.Info("Machine user granted service_account role")

	// Grant org-level administrator role so the service account can call
	// Zitadel API (create users, grant roles).
	//nolint:errcheck // administrator may already exist
	s.perms.CreateAdministrator(s.ctx, &permissionv2.CreateAdministratorRequest{
		UserId: userID,
		Resource: &permissionv2.ResourceType{
			Resource: &permissionv2.ResourceType_OrganizationId{
				OrganizationId: s.orgID,
			},
		},
		Roles: []string{"ORG_USER_MANAGER"},
	})
	slog.Info("Machine user granted org administrator role")
}
