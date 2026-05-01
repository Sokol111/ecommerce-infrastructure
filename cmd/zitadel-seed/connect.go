package main

import (
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"google.golang.org/grpc"

	"github.com/zitadel/zitadel-go/v3/pkg/client"
	orgv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/org/v2"
	"github.com/zitadel/zitadel-go/v3/pkg/zitadel"
)

func (s *seeder) waitReady() {
	slog.Info("Waiting for Zitadel...")
	httpClient := &http.Client{Timeout: 5 * time.Second}
	for range 60 {
		req, _ := http.NewRequest("GET", s.cfg.ZitadelURL+"/.well-known/openid-configuration", nil)
		req.Host = s.cfg.Domain
		if resp, err := httpClient.Do(req); err == nil {
			resp.Body.Close()
			if resp.StatusCode == 200 {
				slog.Info("Zitadel is ready")
				return
			}
		}
		time.Sleep(2 * time.Second)
	}
	fatal("Zitadel not ready after 60 attempts")

}

func (s *seeder) readPAT() {
	switch {
	case s.cfg.PAT != "":
		// PAT provided directly via env var — use as-is.
	case s.cfg.PATFile != "":
		data, err := os.ReadFile(s.cfg.PATFile)
		if err != nil {
			fatal("PAT file not found", "path", s.cfg.PATFile)
		}
		s.cfg.PAT = strings.TrimSpace(string(data))
		if s.cfg.PAT == "" {
			fatal("PAT file is empty")
		}
	default:
		fatal("Either PAT or PAT_FILE must be set")
	}
}

func (s *seeder) connect() {
	slog.Info("Connecting to Zitadel gRPC", "host", s.cfg.Host, "port", s.cfg.Port)

	opts := []client.Option{
		client.WithAuth(client.PAT(s.cfg.PAT)),
	}

	// When gRPC host differs from Zitadel's external domain (e.g., Docker
	// container name vs "localhost"), override the :authority header.
	if s.cfg.Host != s.cfg.Domain {
		opts = append(opts, client.WithGRPCDialOptions(
			grpc.WithAuthority(s.cfg.Domain+":"+s.cfg.Port),
		))
	}

	c, err := client.New(
		s.ctx,
		zitadel.New(s.cfg.Host, zitadel.WithInsecure(s.cfg.Port)),
		opts...,
	)
	if err != nil {
		fatal("Failed to connect to Zitadel", "error", err)
	}

	s.client = c
	slog.Info("Connected to Zitadel gRPC")
}

func (s *seeder) resolveOrgID() {
	orgs, err := s.client.OrganizationServiceV2().ListOrganizations(s.ctx, &orgv2.ListOrganizationsRequest{})
	if err != nil {
		fatal("Failed to list organizations", "error", err)
	}
	if len(orgs.GetResult()) == 0 {
		fatal("No organizations found")
	}
	if len(orgs.GetResult()) > 1 {
		fatal("Multiple organizations found, expected exactly one", "count", len(orgs.GetResult()))
	}
	s.orgID = orgs.GetResult()[0].GetId()
	slog.Info("Resolved organization", "id", s.orgID, "name", orgs.GetResult()[0].GetName())
	s.secrets.set("org-id", s.orgID)
}
