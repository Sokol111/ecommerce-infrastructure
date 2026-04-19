package main

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"log/slog"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/zitadel/zitadel-go/v3/pkg/client"
	instancev2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/instance/v2"
	"github.com/zitadel/zitadel-go/v3/pkg/zitadel"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// addCustomDomains registers additional custom domains so that Zitadel
// routes requests with Host headers other than ZITADEL_EXTERNALDOMAIN.
// This requires System API auth (system.domain.write).
// Skipped if TRUSTED_DOMAINS or SYSTEM_PRIVATE_KEY are not set.
func (s *seeder) addCustomDomains() {
	if len(s.cfg.TrustedDomains) == 0 || s.cfg.SystemPrivateKey == "" {
		return
	}

	slog.Info("Adding custom domains via System API")

	// Sign a JWT for System API authentication.
	issuerURL := fmt.Sprintf("http://%s:%s", s.cfg.Domain, s.cfg.Port)
	token := signSystemJWT(s.cfg.SystemUser, s.cfg.SystemPrivateKey, issuerURL)

	// Create a separate gRPC client with system JWT auth.
	opts := []client.Option{
		client.WithAuth(client.PreSignedJWT(token)),
	}
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
		fatal("Failed to connect system client", "error", err)
	}

	instanceClient := c.InstanceServiceV2()

	// Resolve instance ID.
	instances, err := instanceClient.ListInstances(s.ctx, &instancev2.ListInstancesRequest{})
	if err != nil {
		fatal("Failed to list instances", "error", err)
	}
	if len(instances.GetInstances()) == 0 {
		fatal("No instances found")
	}
	instanceID := instances.GetInstances()[0].GetId()
	slog.Info("Resolved instance", "id", instanceID)

	for _, domain := range s.cfg.TrustedDomains {
		_, err := instanceClient.AddCustomDomain(s.ctx, &instancev2.AddCustomDomainRequest{
			InstanceId:   instanceID,
			CustomDomain: domain,
		})
		if err != nil {
			if status.Code(err) == codes.AlreadyExists {
				slog.Info("Custom domain already exists", "domain", domain)
				continue
			}
			fatal("Failed to add custom domain", "domain", domain, "error", err)
		}
		slog.Info("Added custom domain", "domain", domain)
	}
}

// signSystemJWT creates a signed RS256 JWT for Zitadel System API authentication.
func signSystemJWT(systemUser, privateKeyPEM, audience string) string {
	block, _ := pem.Decode([]byte(privateKeyPEM))
	if block == nil {
		fatal("Failed to decode system private key PEM")
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		fatal("Failed to parse system private key", "error", err)
	}
	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		fatal("System private key is not RSA")
	}

	now := time.Now()
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss": systemUser,
		"sub": systemUser,
		"aud": audience,
		"iat": jwt.NewNumericDate(now),
		"exp": jwt.NewNumericDate(now.Add(time.Hour)),
	})

	signed, err := token.SignedString(rsaKey)
	if err != nil {
		fatal("Failed to sign system JWT", "error", err)
	}

	return signed
}
