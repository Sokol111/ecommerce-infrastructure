package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

func fatal(msg string, args ...any) {
	slog.Error(msg, args...)
	os.Exit(1)
}

// client wraps HTTP interactions with the Logto Management API.
type client struct {
	baseURL    string
	token      string
	httpClient *http.Client
}

// newClient creates a Logto Management API client by authenticating with the
// given M2M application credentials.
func newClient(logtoURL, appID, appSecret string) *client {
	c := &client{
		baseURL:    strings.TrimRight(logtoURL, "/"),
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}
	c.authenticate(appID, appSecret)
	return c
}

// authenticate obtains a Management API access token using client_credentials.
func (c *client) authenticate(appID, appSecret string) {
	data := url.Values{
		"grant_type":    {"client_credentials"},
		"client_id":     {appID},
		"client_secret": {appSecret},
		"resource":      {"https://default.logto.app/api"},
		"scope":         {"all"},
	}

	resp, err := c.httpClient.PostForm(c.baseURL+"/oidc/token", data)
	if err != nil {
		fatal("Failed to authenticate with Logto", "error", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		fatal("Authentication failed", "status", resp.StatusCode, "body", string(body))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		fatal("Failed to decode token response", "error", err)
	}

	c.token = tokenResp.AccessToken
	slog.Info("Authenticated with Logto Management API")
}

// apiRequest makes an authenticated request to the Logto Management API.
func (c *client) apiRequest(method, path string, body any) ([]byte, int) {
	var reqBody io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			fatal("Failed to marshal request body", "error", err)
		}
		reqBody = bytes.NewReader(b)
	}

	req, err := http.NewRequest(method, c.baseURL+"/api"+path, reqBody)
	if err != nil {
		fatal("Failed to create request", "error", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		fatal("API request failed", "method", method, "path", path, "error", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		fatal("Failed to read response", "error", err)
	}

	return respBody, resp.StatusCode
}

// apiDo performs an API request, checks status, and optionally unmarshals the response.
// POST requests that return 409 Conflict are silently skipped (resource already exists).
func (c *client) apiDo(method, path string, body, result any) {
	respBody, status := c.apiRequest(method, path, body)
	if method == "POST" && status == http.StatusConflict {
		slog.Info("Resource already exists, skipping", "path", path)
		return
	}
	if status < 200 || status >= 300 {
		fatal("API request failed", "method", method, "path", path, "status", status, "body", string(respBody))
	}
	if result != nil {
		if err := json.Unmarshal(respBody, result); err != nil {
			fatal("Failed to decode response", "path", path, "error", err)
		}
	}
}

// apiDelete deletes a resource. Returns true if deleted, false if not found.
func (c *client) apiDelete(path string) bool {
	_, status := c.apiRequest("DELETE", path, nil)
	if status == http.StatusNotFound {
		return false
	}
	if status != http.StatusNoContent && status != http.StatusOK {
		fatal("API DELETE failed", "path", path, "status", status)
	}
	return true
}

// --- Domain methods ---

func (c *client) createResource(name, indicator string, ttl int) string {
	if id, found := c.findResourceByIndicator(indicator); found {
		slog.Info("API Resource already exists", "id", id)
		return id
	}
	var res struct {
		ID string `json:"id"`
	}
	c.apiDo("POST", "/resources", map[string]any{
		"name":           name,
		"indicator":      indicator,
		"isDefault":      true,
		"accessTokenTtl": ttl,
	}, &res)
	slog.Info("Created API Resource", "id", res.ID)
	return res.ID
}

func (c *client) ensureScopes(resourceID string, names []string) map[string]string {
	// Load existing scopes.
	var scopes []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	}
	c.apiDo("GET", fmt.Sprintf("/resources/%s/scopes", resourceID), nil, &scopes)
	m := make(map[string]string, len(scopes))
	for _, s := range scopes {
		m[s.Name] = s.ID
	}

	// Create missing scopes.
	for _, name := range names {
		if _, ok := m[name]; !ok {
			var res struct {
				ID string `json:"id"`
			}
			c.apiDo("POST", fmt.Sprintf("/resources/%s/scopes", resourceID), map[string]any{
				"name":        name,
				"description": name,
			}, &res)
			m[name] = res.ID
			slog.Info("Created scope", "name", name)
		}
	}
	return m
}

func (c *client) createRole(name, description, roleType string) string {
	if id, found := c.findRoleByName(name); found {
		slog.Info("Role already exists", "name", name, "id", id)
		return id
	}
	var res struct {
		ID string `json:"id"`
	}
	c.apiDo("POST", "/roles", map[string]any{
		"name":        name,
		"description": description,
		"type":        roleType,
	}, &res)
	slog.Info("Created role", "name", name, "id", res.ID)
	return res.ID
}

func (c *client) assignScopesToRole(roleID string, scopeIDs []string) {
	// Fetch already-assigned scopes to avoid 422.
	var existing []struct {
		ID string `json:"id"`
	}
	c.apiDo("GET", fmt.Sprintf("/roles/%s/scopes", roleID), nil, &existing)

	assigned := make(map[string]bool, len(existing))
	for _, s := range existing {
		assigned[s.ID] = true
	}

	var missing []string
	for _, id := range scopeIDs {
		if !assigned[id] {
			missing = append(missing, id)
		}
	}

	if len(missing) == 0 {
		slog.Info("All scopes already assigned to role, skipping", "roleID", roleID)
		return
	}

	c.apiDo("POST", fmt.Sprintf("/roles/%s/scopes", roleID), map[string]any{
		"scopeIds": missing,
	}, nil)
}

type createAppParams struct {
	Name        string
	Description string
	Type        string
	RedirectURI string
	LogoutURI   string
}

func (c *client) createApp(p createAppParams) (id, secret string) {
	if existing, found := c.findAppByName(p.Name); found {
		slog.Info("Application already exists", "name", p.Name, "id", existing)
		return existing, ""
	}

	body := map[string]any{
		"name":        p.Name,
		"description": p.Description,
		"type":        p.Type,
	}
	if p.RedirectURI != "" {
		body["oidcClientMetadata"] = map[string]any{
			"redirectUris":           []string{p.RedirectURI},
			"postLogoutRedirectUris": []string{p.LogoutURI},
		}
	}

	var res struct {
		ID     string `json:"id"`
		Secret string `json:"secret"`
	}
	c.apiDo("POST", "/applications", body, &res)
	slog.Info("Created application", "name", p.Name, "id", res.ID)
	return res.ID, res.Secret
}

func (c *client) assignRoleToApp(appID string, roleIDs []string) {
	// Fetch already-assigned roles to avoid 422.
	var existing []struct {
		ID string `json:"id"`
	}
	c.apiDo("GET", fmt.Sprintf("/applications/%s/roles", appID), nil, &existing)

	assigned := make(map[string]bool, len(existing))
	for _, r := range existing {
		assigned[r.ID] = true
	}

	var missing []string
	for _, id := range roleIDs {
		if !assigned[id] {
			missing = append(missing, id)
		}
	}

	if len(missing) == 0 {
		slog.Info("All roles already assigned to app, skipping", "appID", appID)
		return
	}

	c.apiDo("POST", fmt.Sprintf("/applications/%s/roles", appID), map[string]any{
		"roleIds": missing,
	}, nil)
}

func (c *client) findAppByName(name string) (string, bool) {
	var apps []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	}
	c.apiDo("GET", fmt.Sprintf("/applications?search=%s", name), nil, &apps)
	for _, a := range apps {
		if a.Name == name {
			return a.ID, true
		}
	}
	return "", false
}

func (c *client) deleteApp(id string) bool {
	return c.apiDelete(fmt.Sprintf("/applications/%s", id))
}

func (c *client) setJWTCustomizer(tokenType, script string) {
	c.apiDo("PUT", fmt.Sprintf("/configs/jwt-customizer/%s", tokenType), map[string]any{
		"script": script,
	}, nil)
}

func (c *client) findResourceByIndicator(indicator string) (string, bool) {
	var resources []struct {
		ID        string `json:"id"`
		Indicator string `json:"indicator"`
	}
	c.apiDo("GET", fmt.Sprintf("/resources?search=%s", url.QueryEscape(indicator)), nil, &resources)
	for _, r := range resources {
		if r.Indicator == indicator {
			return r.ID, true
		}
	}
	return "", false
}

func (c *client) findRoleByName(name string) (string, bool) {
	var roles []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	}
	c.apiDo("GET", fmt.Sprintf("/roles?search=%s", url.QueryEscape(name)), nil, &roles)
	for _, r := range roles {
		if r.Name == name {
			return r.ID, true
		}
	}
	return "", false
}

// waitReady polls the Logto OIDC discovery endpoint until it responds.
func waitReady(cfg config) {
	endpoint := cfg.LogtoURL + "/oidc/.well-known/openid-configuration"
	c := &http.Client{Timeout: 5 * time.Second}

	for range 60 {
		if resp, err := c.Get(endpoint); err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				slog.Info("Logto is ready")
				return
			}
		}
		time.Sleep(2 * time.Second)
	}
	fatal("Logto did not become ready in time", "endpoint", endpoint)
}
