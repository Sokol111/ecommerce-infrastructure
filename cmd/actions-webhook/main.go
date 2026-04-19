package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"strings"
)

// Zitadel Actions v2 webhook handler.
// Receives preaccesstoken / preuserinfo calls and maps roles to permissions.

var rolePermissions = map[string][]string{
	"super_admin": {
		"users:read", "users:write", "users:delete",
		"products:read", "products:write", "products:delete",
		"categories:read", "categories:write", "categories:delete",
		"attributes:read", "attributes:write", "attributes:delete",
	},
	"catalog_manager": {
		"products:read", "products:write", "products:delete",
		"categories:read", "categories:write", "categories:delete",
		"attributes:read", "attributes:write", "attributes:delete",
	},
	"viewer": {
		"users:read", "products:read", "categories:read", "attributes:read",
	},
	"service_account": {
		"tenants:read", "tenants:write",
	},
}

type request struct {
	UserGrants []grant  `json:"user_grants"`
	User       *reqUser `json:"user"`
}

type reqUser struct {
	Machine *machine `json:"machine"`
}

type machine struct {
	Name string `json:"name"`
}

type grant struct {
	Roles []string `json:"roles"`
}

type appendClaim struct {
	Key   string `json:"key"`
	Value any    `json:"value"`
}

type response struct {
	AppendClaims []appendClaim `json:"append_claims"`
}

func main() {
	signingKey := os.Getenv("SIGNING_KEY")
	addr := envOr("ADDR", ":8090")

	http.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	http.HandleFunc("POST /", func(w http.ResponseWriter, r *http.Request) {
		body, err := readAndVerify(r, signingKey)
		if err != nil {
			slog.Warn("Request rejected", "error", err)
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		var req request
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}

		slog.Info("Webhook called", "body", string(body), "grants", len(req.UserGrants))

		resp := mapPermissions(req)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})

	slog.Info("Actions webhook listening", "addr", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		slog.Error("Server failed", "error", err)
		os.Exit(1)
	}
}

func mapPermissions(req request) response {
	// Machine users without user_grants: assign service_account role.
	// Zitadel doesn't include user_grants in the webhook payload for
	// machine-to-machine flows (client_credentials / jwt-bearer).
	if len(req.UserGrants) == 0 && req.User != nil && req.User.Machine != nil {
		return response{AppendClaims: []appendClaim{
			{Key: "role", Value: "service_account"},
			{Key: "permissions", Value: rolePermissions["service_account"]},
		}}
	}

	seen := make(map[string]bool)
	var permissions []string
	var firstRole string

	for _, g := range req.UserGrants {
		for _, role := range g.Roles {
			if firstRole == "" {
				firstRole = role
			}
			for _, perm := range rolePermissions[role] {
				if !seen[perm] {
					seen[perm] = true
					permissions = append(permissions, perm)
				}
			}
		}
	}

	var claims []appendClaim
	if len(permissions) > 0 {
		claims = append(claims, appendClaim{Key: "permissions", Value: permissions})
	}
	if firstRole != "" {
		claims = append(claims, appendClaim{Key: "role", Value: firstRole})
	}

	return response{AppendClaims: claims}
}

func readAndVerify(r *http.Request, signingKey string) ([]byte, error) {
	body, err := readBody(r)
	if err != nil {
		return nil, err
	}

	// Skip signature verification if no signing key configured (local dev).
	if signingKey == "" {
		return body, nil
	}

	sig := r.Header.Get("X-ZITADEL-Signature")
	if sig == "" {
		sig = r.Header.Get("zitadel-signature")
	}
	if sig == "" {
		return nil, errMissingSig
	}

	if !verifyHMAC(sig, body, signingKey) {
		return nil, errInvalidSig
	}

	return body, nil
}

func verifyHMAC(header string, body []byte, key string) bool {
	// Header format: t=<timestamp>,v1=<hex-signature>
	var timestamp, signature string
	for _, part := range strings.Split(header, ",") {
		k, v, ok := strings.Cut(part, "=")
		if !ok {
			continue
		}
		switch k {
		case "t":
			timestamp = v
		case "v1":
			signature = v
		}
	}
	if timestamp == "" || signature == "" {
		return false
	}

	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(timestamp + "." + string(body)))
	expected := hex.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(expected), []byte(signature))
}

func readBody(r *http.Request) ([]byte, error) {
	defer r.Body.Close()
	const maxBody = 1 << 20 // 1MB
	lr := http.MaxBytesReader(nil, r.Body, maxBody)
	buf := make([]byte, 0, 4096)
	for {
		n := len(buf)
		if n == cap(buf) {
			buf = append(buf, 0)[:n]
		}
		nn, err := lr.Read(buf[n:cap(buf)])
		buf = buf[:n+nn]
		if err != nil {
			if err.Error() == "http: request body too large" {
				return nil, errBodyTooLarge
			}
			break
		}
	}
	return buf, nil
}

type sentinelError string

func (e sentinelError) Error() string { return string(e) }

const (
	errMissingSig   = sentinelError("missing signature")
	errInvalidSig   = sentinelError("invalid signature")
	errBodyTooLarge = sentinelError("body too large")
)

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
