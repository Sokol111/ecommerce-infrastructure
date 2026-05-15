package main

import (
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"log/slog"

	_ "github.com/jackc/pgx/v5/stdlib"
)

type bootstrapResult struct {
	appID     string
	appSecret string
}

// createBootstrapApp inserts a temporary M2M application with Management API
// access directly into Logto's PostgreSQL database. This avoids the need for
// pre-existing credentials — the seed process is fully self-contained.
//
// The bootstrap app is deleted via Management API after seeding completes.
func createBootstrapApp(dbURL string) bootstrapResult {
	db, err := sql.Open("pgx", dbURL)
	if err != nil {
		fatal("Failed to connect to Logto database", "error", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		fatal("Failed to ping Logto database", "error", err)
	}

	const tenantID = "default"

	// Clean up any leftover bootstrap apps from previous failed runs.
	res, err := db.Exec(`DELETE FROM applications WHERE tenant_id = $1 AND name = $2`, tenantID, "logto-seed-bootstrap")
	if err != nil {
		fatal("Failed to clean up old bootstrap apps", "error", err)
	}
	if n, _ := res.RowsAffected(); n > 0 {
		slog.Info("Cleaned up orphaned bootstrap apps", "count", n)
	}

	appID := generateID(21)
	appSecret := generateSecret(32) // 32 bytes → 64 hex chars

	// Insert bootstrap M2M application.
	_, err = db.Exec(`
		INSERT INTO applications (tenant_id, id, secret, name, description, type, oidc_client_metadata)
		VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
	`,
		tenantID, appID, appSecret,
		"logto-seed-bootstrap",
		"Temporary bootstrap app (auto-deleted after seed)",
		"MachineToMachine",
		`{"redirectUris":[],"postLogoutRedirectUris":[]}`,
	)
	if err != nil {
		fatal("Failed to insert bootstrap application", "error", err)
	}
	slog.Info("Created bootstrap M2M application", "id", appID)

	// Find the built-in Management API access role.
	var roleID string
	err = db.QueryRow(`
		SELECT id FROM roles WHERE tenant_id = $1 AND name = $2
	`, tenantID, "Logto Management API access").Scan(&roleID)
	if err != nil {
		fatal("Failed to find Management API access role (is the DB seeded?)", "error", err)
	}

	// Assign the role to the bootstrap app.
	assocID := generateID(21)
	_, err = db.Exec(`
		INSERT INTO applications_roles (tenant_id, id, application_id, role_id)
		VALUES ($1, $2, $3, $4)
	`, tenantID, assocID, appID, roleID)
	if err != nil {
		fatal("Failed to assign Management API role", "error", err)
	}
	slog.Info("Assigned Management API access role to bootstrap app")

	return bootstrapResult{appID: appID, appSecret: appSecret}
}

// generateID creates a random alphanumeric string of the given length.
func generateID(length int) string {
	const charset = "0123456789abcdefghijklmnopqrstuvwxyz"
	b := make([]byte, length)
	if _, err := rand.Read(b); err != nil {
		fatal("Failed to generate random bytes", "error", err)
	}
	for i := range b {
		b[i] = charset[b[i]%byte(len(charset))]
	}
	return string(b)
}

// generateSecret creates a cryptographically random hex string.
func generateSecret(nBytes int) string {
	b := make([]byte, nBytes)
	if _, err := rand.Read(b); err != nil {
		fatal("Failed to generate random bytes", "error", err)
	}
	return hex.EncodeToString(b)
}
