package seeder

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/config"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/data"

	catalogapi "github.com/Sokol111/ecommerce-catalog-service-api/gen/httpapi"
	imageapi "github.com/Sokol111/ecommerce-image-service-api/gen/httpapi"
)

// noopSecuritySource implements catalogapi.SecuritySource without authentication.
type noopSecuritySource struct{}

func (noopSecuritySource) BearerAuth(ctx context.Context, operationName catalogapi.OperationName) (catalogapi.BearerAuth, error) {
	return catalogapi.BearerAuth{Token: ""}, nil
}

type Seeder struct {
	data          *data.SeedData
	httpClient    *http.Client
	assetsDir     string
	catalogClient *catalogapi.Client
	imageClient   *imageapi.Client
	imageCache    map[string]string // filename -> imageID
}

func New(cfg *config.Config, seedData *data.SeedData, assetsDir string) (*Seeder, error) {
	httpClient := &http.Client{
		Timeout: 30 * time.Second,
	}

	catalogClient, err := catalogapi.NewClient(cfg.CatalogURL, noopSecuritySource{}, catalogapi.WithClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("failed to create catalog client: %w", err)
	}

	imageClient, err := imageapi.NewClient(cfg.ImageURL, imageapi.WithClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("failed to create image client: %w", err)
	}

	return &Seeder{
		data:          seedData,
		httpClient:    httpClient,
		assetsDir:     assetsDir,
		catalogClient: catalogClient,
		imageClient:   imageClient,
		imageCache:    make(map[string]string),
	}, nil
}

func (s *Seeder) Run(ctx context.Context) error {
	log.Println("🚀 Starting demo data seeder...")

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
