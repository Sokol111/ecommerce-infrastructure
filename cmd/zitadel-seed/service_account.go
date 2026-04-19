package main

import (
	"log/slog"
	"time"

	authorizationv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/authorization/v2"
	permissionv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/internal_permission/v2"
	objectv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/object/v2"
	userv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/user/v2"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// setupGoServiceAccount creates or finds the "ecommerce-service" machine user
// used by Go backend services for S2S auth with private_key_jwt.
// It registers the RSA public key so Go services can sign JWT client assertions
// with the matching private key.
func (s *seeder) setupGoServiceAccount() {
	slog.Info("Setting up Go S2S service account (private_key_jwt)")

	userID := s.findOrCreateMachineUser("ecommerce-service", "Ecommerce Service Account", s.cfg.S2SUserID)
	s.registerPublicKey(userID)
	s.grantProjectRole(userID)

	slog.Info("Go S2S service account ready",
		"S2S_CLIENT_ID", userID,
		"auth_method", "private_key_jwt",
	)
}

// setupPlatformServiceAccount creates or finds the "platform-service" machine user
// used by platform-UI for S2S auth with private_key_jwt.
func (s *seeder) setupPlatformServiceAccount() {
	slog.Info("Setting up platform-UI S2S service account (private_key_jwt)")

	userID := s.findOrCreateMachineUser("platform-service", "Platform Service Account", s.cfg.PlatformUserID)
	s.registerPublicKey(userID)
	s.grantProjectRole(userID)
	s.grantOrgUserManager(userID)

	slog.Info("Platform S2S service account ready",
		"PLATFORM_CLIENT_ID", userID,
		"auth_method", "private_key_jwt",
	)
}

// findOrCreateMachineUser searches for an existing machine user by username,
// and creates one if not found. If fixedID is set, it uses that as the UserId.
func (s *seeder) findOrCreateMachineUser(username, displayName, fixedID string) string {
	users, err := s.users.ListUsers(s.ctx, &userv2.ListUsersRequest{
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

	if len(users.GetResult()) > 0 {
		id := users.GetResult()[0].GetUserId()
		slog.Info("Machine user already exists", "username", username, "id", id)
		return id
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
	if fixedID != "" {
		req.UserId = &fixedID
	}

	result, err := s.users.CreateUser(s.ctx, req)
	if err != nil {
		fatal("Failed to create machine user", "username", username, "error", err)
	}
	slog.Info("Created machine user", "username", username, "id", result.GetId())
	return result.GetId()
}

// grantProjectRole grants the service_account project role to the given user.
func (s *seeder) grantProjectRole(userID string) {
	//nolint:errcheck // grant may already exist
	s.auths.CreateAuthorization(s.ctx, &authorizationv2.CreateAuthorizationRequest{
		UserId:    userID,
		ProjectId: s.projectID,
		RoleKeys:  []string{"service_account"},
	})
}

// grantOrgUserManager grants ORG_USER_MANAGER org administrator role to the given user.
func (s *seeder) grantOrgUserManager(userID string) {
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
}

// registerPublicKey registers the RSA public key for private_key_jwt auth.
func (s *seeder) registerPublicKey(userID string) {
	if s.cfg.S2SPublicKey == "" {
		return
	}
	resp, err := s.users.AddKey(s.ctx, &userv2.AddKeyRequest{
		UserId:         userID,
		PublicKey:      []byte(s.cfg.S2SPublicKey),
		ExpirationDate: timestamppb.New(time.Date(2099, 1, 1, 0, 0, 0, 0, time.UTC)),
	})
	if err != nil {
		fatal("Failed to register S2S public key", "user_id", userID, "error", err)
	}
	slog.Info("Registered S2S public key", "user_id", userID, "key_id", resp.GetKeyId())
}
