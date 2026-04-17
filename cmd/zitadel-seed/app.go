package main

import (
	"log/slog"

	applicationv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/application/v2"
	filterv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/filter/v2"
)

func (s *seeder) setupAdminUIApp() {
	slog.Info("Setting up admin-ui OIDC application")

	apps, err := s.apps.ListApplications(s.ctx, &applicationv2.ListApplicationsRequest{
		Filters: []*applicationv2.ApplicationSearchFilter{
			{
				Filter: &applicationv2.ApplicationSearchFilter_ProjectIdFilter{
					ProjectIdFilter: &applicationv2.ProjectIDFilter{
						ProjectId: s.projectID,
					},
				},
			},
			{
				Filter: &applicationv2.ApplicationSearchFilter_NameFilter{
					NameFilter: &applicationv2.ApplicationNameFilter{
						Name:   "admin-ui",
						Method: filterv2.TextFilterMethod_TEXT_FILTER_METHOD_EQUALS,
					},
				},
			},
		},
	})
	if err != nil {
		fatal("Failed to list apps", "error", err)
	}

	if len(apps.GetApplications()) > 0 {
		if oidcCfg := apps.GetApplications()[0].GetOidcConfiguration(); oidcCfg != nil {
			s.adminUIClientID = oidcCfg.GetClientId()
		}
		slog.Info("OIDC app already exists", "client_id", s.adminUIClientID)
		return
	}

	result, err := s.apps.CreateApplication(s.ctx, &applicationv2.CreateApplicationRequest{
		ProjectId: s.projectID,
		Name:      "admin-ui",
		ApplicationType: &applicationv2.CreateApplicationRequest_OidcConfiguration{
			OidcConfiguration: &applicationv2.CreateOIDCApplicationRequest{
				RedirectUris:           []string{s.cfg.RedirectURI},
				PostLogoutRedirectUris: []string{s.cfg.LogoutURI},
				ResponseTypes: []applicationv2.OIDCResponseType{
					applicationv2.OIDCResponseType_OIDC_RESPONSE_TYPE_CODE,
				},
				GrantTypes: []applicationv2.OIDCGrantType{
					applicationv2.OIDCGrantType_OIDC_GRANT_TYPE_AUTHORIZATION_CODE,
					applicationv2.OIDCGrantType_OIDC_GRANT_TYPE_REFRESH_TOKEN,
				},
				ApplicationType:          applicationv2.OIDCApplicationType_OIDC_APP_TYPE_WEB,
				AuthMethodType:           applicationv2.OIDCAuthMethodType_OIDC_AUTH_METHOD_TYPE_NONE,
				DevelopmentMode:          s.cfg.DevMode,
				AccessTokenType:          applicationv2.OIDCTokenType_OIDC_TOKEN_TYPE_JWT,
				AccessTokenRoleAssertion: true,
				IdTokenRoleAssertion:     true,
				IdTokenUserinfoAssertion: true,
			},
		},
	})
	if err != nil {
		fatal("Failed to create OIDC app", "error", err)
	}
	if oidcCfg := result.GetOidcConfiguration(); oidcCfg != nil {
		s.adminUIClientID = oidcCfg.GetClientId()
	}
	slog.Info("Created OIDC app", "client_id", s.adminUIClientID)
}
