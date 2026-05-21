package seeder

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/auth"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/config"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/data"

	catalogapi "github.com/Sokol111/ecommerce-catalog-service-api/gen/httpapi"
	imageapi "github.com/Sokol111/ecommerce-image-service-api/gen/httpapi"
)

// tokenSecuritySource implements catalogapi.SecuritySource with a static bearer token.
type tokenSecuritySource struct {
	token string
}

func (s tokenSecuritySource) BearerAuth(ctx context.Context, operationName catalogapi.OperationName) (catalogapi.BearerAuth, error) {
	return catalogapi.BearerAuth{Token: s.token}, nil
}

// tenantTransport injects the X-Tenant-Slug header into every outgoing request.
type tenantTransport struct {
	base       http.RoundTripper
	tenantSlug string
}

func (t *tenantTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	req = req.Clone(req.Context())
	req.Header.Set("X-Tenant-Slug", t.tenantSlug)
	return t.base.RoundTrip(req)
}

type Seeder struct {
	data                *data.SeedData
	httpClient          *http.Client
	assetsDir           string
	storageHostOverride string
	catalogClient       *catalogapi.Client
	imageClient         *imageapi.Client
	imageCache          map[string]string // filename -> imageID
}

func New(cfg *config.Config, seedData *data.SeedData, assetsDir string) (*Seeder, error) {
	transport := http.RoundTripper(http.DefaultTransport)
	if cfg.TenantSlug != "" {
		transport = &tenantTransport{base: transport, tenantSlug: cfg.TenantSlug}
		log.Printf("Seeding for tenant: %s", cfg.TenantSlug)
	}

	httpClient := &http.Client{
		Timeout:   30 * time.Second,
		Transport: transport,
	}

	// Obtain access token from Logto via client_credentials flow
	tp := auth.NewTokenProvider(cfg.LogtoURL, cfg.ClientID, cfg.ClientSecret, cfg.APIResource)
	token, err := tp.FetchToken()
	if err != nil {
		return nil, fmt.Errorf("failed to obtain access token from Logto: %w", err)
	}
	log.Println("✓ Obtained access token from Logto")

	catalogClient, err := catalogapi.NewClient(cfg.CatalogURL, tokenSecuritySource{token: token}, catalogapi.WithClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("failed to create catalog client: %w", err)
	}

	imageClient, err := imageapi.NewClient(cfg.ImageURL, imageapi.WithClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("failed to create image client: %w", err)
	}

	return &Seeder{
		data:                seedData,
		httpClient:          httpClient,
		assetsDir:           assetsDir,
		storageHostOverride: cfg.StorageHostOverride,
		catalogClient:       catalogClient,
		imageClient:         imageClient,
		imageCache:          make(map[string]string),
	}, nil
}

func (s *Seeder) Run(ctx context.Context) error {
	log.Println("🚀 Starting demo data seeder...")

	log.Println("\n🏷 Upserting attributes...")
	if err := s.upsertAttributes(ctx); err != nil {
		return fmt.Errorf("failed to upsert attributes: %w", err)
	}

	log.Println("\n📁 Upserting categories...")
	if err := s.upsertCategories(ctx); err != nil {
		return fmt.Errorf("failed to upsert categories: %w", err)
	}

	log.Println("\n📦 Upserting products...")
	if err := s.upsertProducts(ctx); err != nil {
		return fmt.Errorf("failed to upsert products: %w", err)
	}

	log.Println("\n✅ Demo data seeding completed successfully!")
	return nil
}
