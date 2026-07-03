package auth

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// TokenProvider fetches access tokens from Logto using client_credentials flow.
type TokenProvider struct {
	logtoURL     string
	clientID     string
	clientSecret string
	resource     string
	httpClient   *http.Client
}

// NewTokenProvider creates a TokenProvider for the given Logto instance.
func NewTokenProvider(logtoURL, clientID, clientSecret, resource string) *TokenProvider {
	return &TokenProvider{
		logtoURL:     strings.TrimRight(logtoURL, "/"),
		clientID:     clientID,
		clientSecret: clientSecret,
		resource:     resource,
		httpClient:   &http.Client{Timeout: 30 * time.Second},
	}
}

// FetchToken obtains an access token using the client_credentials grant.
func (p *TokenProvider) FetchToken() (string, error) {
	data := url.Values{
		"grant_type":    {"client_credentials"},
		"client_id":     {p.clientID},
		"client_secret": {p.clientSecret},
		"resource":      {p.resource},
		"scope":         {"products:read products:write categories:read categories:write attributes:read attributes:write images:write"},
	}

	resp, err := p.httpClient.PostForm(p.logtoURL+"/oidc/token", data)
	if err != nil {
		return "", fmt.Errorf("token request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("token request returned %d: %s", resp.StatusCode, string(body))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("failed to decode token response: %w", err)
	}

	if tokenResp.AccessToken == "" {
		return "", fmt.Errorf("received empty access token")
	}

	return tokenResp.AccessToken, nil
}
