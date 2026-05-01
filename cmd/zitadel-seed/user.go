package main

import (
	"log/slog"

	authorizationv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/authorization/v2"
	objectv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/object/v2"
	userv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/user/v2"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (s *seeder) setupDemoUser() {
	slog.Info("Setting up demo admin user")

	email := "admin@demo.localhost"

	users, err := s.client.UserServiceV2().ListUsers(s.ctx, &userv2.ListUsersRequest{
		Queries: []*userv2.SearchQuery{{
			Query: &userv2.SearchQuery_EmailQuery{
				EmailQuery: &userv2.EmailQuery{
					EmailAddress: email,
					Method:       objectv2.TextQueryMethod_TEXT_QUERY_METHOD_EQUALS,
				},
			},
		}},
	})
	if err != nil {
		fatal("Failed to list users", "error", err)
	}

	var userID string
	if len(users.GetResult()) > 1 {
		fatal("Expected at most one demo user, got multiple", "count", len(users.GetResult()))
	} else if len(users.GetResult()) == 1 {
		userID = users.GetResult()[0].GetUserId()
		slog.Info("Demo user already exists", "id", userID)
	} else {
		username := email
		result, err := s.client.UserServiceV2().CreateUser(s.ctx, &userv2.CreateUserRequest{
			OrganizationId: s.orgID,
			Username:       &username,
			UserType: &userv2.CreateUserRequest_Human_{
				Human: &userv2.CreateUserRequest_Human{
					Profile: &userv2.SetHumanProfile{
						GivenName:  "Demo",
						FamilyName: "Admin",
					},
					Email: &userv2.SetHumanEmail{
						Email: email,
						Verification: &userv2.SetHumanEmail_IsVerified{
							IsVerified: true,
						},
					},
					PasswordType: &userv2.CreateUserRequest_Human_Password{
						Password: &userv2.Password{
							Password:       "Password1!",
							ChangeRequired: false,
						},
					},
				},
			},
		})
		if err != nil {
			fatal("Failed to create demo user", "error", err)
		}
		userID = result.GetId()
		slog.Info("Created demo user", "email", email, "id", userID)
	}

	// Grant super_admin role.
	_, err = s.client.AuthorizationServiceV2().CreateAuthorization(s.ctx, &authorizationv2.CreateAuthorizationRequest{
		UserId:         userID,
		OrganizationId: s.orgID,
		ProjectId:      s.projectID,
		RoleKeys:       []string{"super_admin"},
	})
	if err != nil && status.Code(err) != codes.AlreadyExists {
		fatal("Failed to grant super_admin role", "error", err)
	}
	slog.Info("Demo user granted super_admin role")
}
