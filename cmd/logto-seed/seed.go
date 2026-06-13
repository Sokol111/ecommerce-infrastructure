package main

import (
	"encoding/json"
	"log/slog"
	"os"
)

// seedConfig holds roles, applications and users loaded from seed.json.
type seedConfig struct {
	Roles        []roleDefinition `json:"roles"`
	Applications []appDefinition  `json:"applications"`
	Users        []userDefinition `json:"users"`
}

// roleDefinition describes a role and its assigned scopes.
type roleDefinition struct {
	Name        string   `json:"name"`
	Description string   `json:"description"`
	Type        string   `json:"type"` // "User" or "MachineToMachine"
	Scopes      []string `json:"scopes"`
}

// appDefinition describes an OIDC application to create.
type appDefinition struct {
	Name          string `json:"name"`
	Description   string `json:"description"`
	Type          string `json:"type"`                    // "Traditional" or "MachineToMachine"
	Role          string `json:"role,omitempty"`          // role to assign (M2M with custom API)
	ManagementAPI bool   `json:"managementAPI,omitempty"` // assign Logto Management API role
	SecretPrefix  string `json:"secretPrefix"`            // prefix for K8s secret keys
	RedirectURI   string `json:"redirectURI,omitempty"`   // OIDC redirect URI (supports $ENV_VAR)
	LogoutURI     string `json:"logoutURI,omitempty"`     // OIDC post-logout redirect URI (supports $ENV_VAR)
}

// userDefinition describes a platform admin user to create.
type userDefinition struct {
	Email    string   `json:"email"`
	Password string   `json:"password"` // supports $ENV_VAR for production
	Name     string   `json:"name"`
	Roles    []string `json:"roles"` // Logto role names to assign
}

// allScopes returns a deduplicated list of all scopes across all roles.
func (sc *seedConfig) allScopes() []string {
	seen := make(map[string]bool)
	var scopes []string
	for _, r := range sc.Roles {
		for _, s := range r.Scopes {
			if !seen[s] {
				seen[s] = true
				scopes = append(scopes, s)
			}
		}
	}
	return scopes
}

func loadSeedConfig(path string) seedConfig {
	data, err := os.ReadFile(path)
	if err != nil {
		fatal("Failed to read seed config", "path", path, "error", err)
	}
	// Expand $ENV_VAR references.
	data = []byte(os.ExpandEnv(string(data)))
	var cfg seedConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		fatal("Failed to parse seed config", "path", path, "error", err)
	}
	return cfg
}

type seeder struct {
	cfg     config
	seed    seedConfig
	secrets map[string]string
	client  *client

	bootstrapAppID string
	apiResourceID  string
	scopeIDs       map[string]string // scope name -> scope ID
}

// createAPIResource creates the ecommerce API resource and its scopes.
func (s *seeder) createAPIResource() {
	s.apiResourceID = s.client.createResource("Ecommerce API", s.cfg.APIResourceIndicator, 3600)
	s.scopeIDs = s.client.ensureScopes(s.apiResourceID, s.seed.allScopes())
}

// createRoles creates all application roles and assigns scopes.
func (s *seeder) createRoles() {
	for _, rd := range s.seed.Roles {
		roleID := s.client.createRole(rd.Name, rd.Description, rd.Type)

		scopeIDList := make([]string, 0, len(rd.Scopes))
		for _, scopeName := range rd.Scopes {
			if id, ok := s.scopeIDs[scopeName]; ok {
				scopeIDList = append(scopeIDList, id)
			}
		}
		if len(scopeIDList) > 0 {
			s.client.assignScopesToRole(roleID, scopeIDList)
		}
	}
}

// createApplications creates all OIDC applications defined in seed.json.
func (s *seeder) createApplications() {
	for _, app := range s.seed.Applications {
		p := createAppParams{
			Name:        app.Name,
			Description: app.Description,
			Type:        app.Type,
			RedirectURI: app.RedirectURI,
			LogoutURI:   app.LogoutURI,
		}

		id, secret := s.client.createApp(p)

		s.secrets[app.SecretPrefix+"-client-id"] = id
		if secret != "" {
			s.secrets[app.SecretPrefix+"-client-secret"] = secret
		}

		// Assign role.
		switch {
		case app.ManagementAPI:
			roleID, found := s.client.findRoleByName("Logto Management API access")
			if !found {
				fatal("Logto Management API access role not found")
			}
			s.client.assignRoleToApp(id, []string{roleID})
			slog.Info("Assigned Management API access role", "app", app.Name)

		case app.Role != "":
			roleID, found := s.client.findRoleByName(app.Role)
			if !found {
				fatal("Role not found for app", "role", app.Role, "app", app.Name)
			}
			s.client.assignRoleToApp(id, []string{roleID})
			slog.Info("Assigned role to app", "app", app.Name, "role", app.Role)
		}
	}
}

// createUsers creates all platform admin users defined in seed.json.
func (s *seeder) createUsers() {
	for _, u := range s.seed.Users {
		userID := s.client.createUser(u.Email, u.Password, u.Name)

		var roleIDs []string
		for _, roleName := range u.Roles {
			roleID, found := s.client.findRoleByName(roleName)
			if !found {
				fatal("Role not found for user", "role", roleName, "user", u.Email)
			}
			roleIDs = append(roleIDs, roleID)
		}
		if len(roleIDs) > 0 {
			s.client.assignRoleToUser(userID, roleIDs)
			slog.Info("Assigned roles to user", "user", u.Email, "roles", u.Roles)
		}
	}
}

// configureJWTCustomizer sets up custom JWT claims for access tokens.
func (s *seeder) configureJWTCustomizer() {
	slog.Info("Configuring JWT customizer")

	s.client.setJWTCustomizer("access-token", `const getCustomJwtClaims = async ({ token, context, environmentVariables }) => {
  const roles = context.user?.roles ?? [];
  return {
    role: roles[0]?.name ?? '',
    tenant: context.user?.customData?.tenant ?? '',
  };
};`)
	slog.Info("Configured user access token JWT customizer")

	s.client.setJWTCustomizer("client-credentials", `const getCustomJwtClaims = async ({ token, context, environmentVariables }) => {
  const roles = context.application?.roles ?? [];
  return {
    role: roles[0]?.name ?? '',
  };
};`)
	slog.Info("Configured M2M client credentials JWT customizer")
}

// configureSignInExperience enables email+password sign-in.
func (s *seeder) configureSignInExperience() {
	slog.Info("Configuring sign-in experience")
	s.client.apiDo("PATCH", "/sign-in-exp", map[string]any{
		"signIn": map[string]any{
			"methods": []map[string]any{
				{
					"identifier":        "email",
					"password":          true,
					"verificationCode":  false,
					"isPasswordPrimary": true,
				},
			},
		},
		"signUp": map[string]any{
			"identifiers": []string{},
			"password":    false,
			"verify":      false,
		},
	}, nil)
	slog.Info("Configured sign-in experience with email+password")
}

// cleanupBootstrapApp deletes the bootstrap M2M app after all setup is done.
func (s *seeder) cleanupBootstrapApp() {
	slog.Info("Cleaning up bootstrap M2M application")
	if s.client.deleteApp(s.bootstrapAppID) {
		slog.Info("Deleted bootstrap app", "id", s.bootstrapAppID)
	} else {
		slog.Info("Bootstrap app already deleted")
	}
}
