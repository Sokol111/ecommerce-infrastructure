package main

import (
	"log/slog"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	authorizationv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/authorization/v2"
	permissionv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/internal_permission/v2"
	objectv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/object/v2"
	userv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/user/v2"
)

// setupGoServiceAccount creates or finds the "ecommerce-service" machine user
// used by Go backend services for S2S auth with client_credentials.
func (s *seeder) setupGoServiceAccount() {
	slog.Info("Setting up Go S2S service account (client_credentials)")

	userID, created := s.findOrCreateMachineUser("ecommerce-service", "Ecommerce Service Account")
	if created {
		secret := s.createSecret(userID)
		s.secrets.set("s2s-client-secret", secret)
	}
	s.grantProjectRole(userID)

	slog.Info("Go S2S service account ready", "S2S_CLIENT_ID", "ecommerce-service")
}

// setupPlatformServiceAccount creates or finds the "platform-service" machine user
// used by platform-UI for S2S auth with client_credentials.
func (s *seeder) setupPlatformServiceAccount() {
	slog.Info("Setting up platform-UI S2S service account (client_credentials)")

	userID, created := s.findOrCreateMachineUser("platform-service", "Platform Service Account")
	if created {
		secret := s.createSecret(userID)
		s.secrets.set("platform-client-secret", secret)
	}
	s.grantProjectRole(userID)
	s.grantOrgUserManager(userID)

	slog.Info("Platform S2S service account ready", "PLATFORM_CLIENT_ID", "platform-service")
}

// findOrCreateMachineUser searches for an existing machine user by username,
// and creates one if not found.
// Returns the user ID and whether the user was created in this call.
func (s *seeder) findOrCreateMachineUser(username, displayName string) (string, bool) {
	users, err := s.client.UserServiceV2().ListUsers(s.ctx, &userv2.ListUsersRequest{
		Queries: []*userv2.SearchQuery{{
			Query: &userv2.SearchQuery_UserNameQuery{
				UserNameQuery: &userv2.UserNameQuery{
					UserName: username,
					Method:   objectv2.TextQueryMethod_TEXT_QUERY_METHOD_EQUALS,
				},
			},
		}},
	})
	if err != nil {
		fatal("Failed to list users", "username", username, "error", err)
	}

	if len(users.GetResult()) > 1 {
		fatal("Multiple users with same username found", "username", username, "count", len(users.GetResult()))
	}

	if len(users.GetResult()) == 1 {
		id := users.GetResult()[0].GetUserId()
		slog.Info("Machine user already exists", "username", username, "id", id)
		return id, false
	}

	req := &userv2.CreateUserRequest{
		OrganizationId: s.orgID,
		Username:       &username,
		UserType: &userv2.CreateUserRequest_Machine_{
			Machine: &userv2.CreateUserRequest_Machine{
				Name:            displayName,
				AccessTokenType: userv2.AccessTokenType_ACCESS_TOKEN_TYPE_JWT,
			},
		},
	}

	result, err := s.client.UserServiceV2().CreateUser(s.ctx, req)
	if err != nil {
		fatal("Failed to create machine user", "username", username, "error", err)
	}
	slog.Info("Created machine user", "username", username, "id", result.GetId())
	return result.GetId(), true
}

// createSecret generates a client_credentials secret for the machine user.
// The secret is only returned once — store it securely.
func (s *seeder) createSecret(userID string) string {
	resp, err := s.client.UserServiceV2().AddSecret(s.ctx, &userv2.AddSecretRequest{
		UserId: userID,
	})
	if err != nil {
		fatal("Failed to create client secret", "user_id", userID, "error", err)
	}
	return resp.GetClientSecret()
}

// grantProjectRole grants the service_account project role to the given user.
func (s *seeder) grantProjectRole(userID string) {
	_, err := s.client.AuthorizationServiceV2().CreateAuthorization(s.ctx, &authorizationv2.CreateAuthorizationRequest{
		UserId:    userID,
		ProjectId: s.projectID,
		RoleKeys:  []string{"service_account"},
	})
	if err != nil {
		if status.Code(err) == codes.AlreadyExists {
			return
		}
		fatal("Failed to grant project role", "user_id", userID, "error", err)
	}
}

// grantOrgUserManager grants ORG_USER_MANAGER org administrator role to the given user.
func (s *seeder) grantOrgUserManager(userID string) {
	_, err := s.client.InternalPermissionServiceV2().CreateAdministrator(s.ctx, &permissionv2.CreateAdministratorRequest{
		UserId: userID,
		Resource: &permissionv2.ResourceType{
			Resource: &permissionv2.ResourceType_OrganizationId{
				OrganizationId: s.orgID,
			},
		},
		Roles: []string{"ORG_USER_MANAGER"},
	})
	if err != nil {
		if status.Code(err) == codes.AlreadyExists {
			return
		}
		fatal("Failed to grant org user manager", "user_id", userID, "error", err)
	}
}
