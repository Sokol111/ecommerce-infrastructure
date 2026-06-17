package seeder

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"

	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/auth"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/config"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/data"

	catalogv1 "github.com/Sokol111/ecommerce-catalog-service-api/gen/connect/catalog/v1"
	imagev1 "github.com/Sokol111/ecommerce-image-service-api/gen/connect/image/v1"
)

type Seeder struct {
	data                *data.SeedData
	httpClient          *http.Client
	assetsDir           string
	storageHostOverride string
	token               string
	tenantSlug          string
	catalogConn         *grpc.ClientConn
	imageConn           *grpc.ClientConn
	attributeClient     catalogv1.AttributeServiceClient
	categoryClient      catalogv1.CategoryServiceClient
	productClient       catalogv1.ProductServiceClient
	imageClient         imagev1.ImageServiceClient
	imageCache          map[string]string // filename -> imageID
}

func New(cfg *config.Config, seedData *data.SeedData, assetsDir string) (*Seeder, error) {
	// Obtain access token from Logto via client_credentials flow
	tp := auth.NewTokenProvider(cfg.LogtoURL, cfg.ClientID, cfg.ClientSecret, cfg.APIResource)
	token, err := tp.FetchToken()
	if err != nil {
		return nil, fmt.Errorf("failed to obtain access token from Logto: %w", err)
	}
	log.Println("✓ Obtained access token from Logto")

	catalogConn, err := grpc.NewClient(cfg.CatalogGRPCAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("failed to connect to catalog service: %w", err)
	}

	imageConn, err := grpc.NewClient(cfg.ImageGRPCAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		catalogConn.Close()
		return nil, fmt.Errorf("failed to connect to image service: %w", err)
	}

	httpClient := &http.Client{
		Timeout: 30 * time.Second,
	}

	return &Seeder{
		data:                seedData,
		httpClient:          httpClient,
		assetsDir:           assetsDir,
		storageHostOverride: cfg.StorageHostOverride,
		token:               token,
		tenantSlug:          cfg.TenantSlug,
		catalogConn:         catalogConn,
		imageConn:           imageConn,
		attributeClient:     catalogv1.NewAttributeServiceClient(catalogConn),
		categoryClient:      catalogv1.NewCategoryServiceClient(catalogConn),
		productClient:       catalogv1.NewProductServiceClient(catalogConn),
		imageClient:         imagev1.NewImageServiceClient(imageConn),
		imageCache:          make(map[string]string),
	}, nil
}

// outgoingCtx attaches the bearer token and tenant slug to outgoing gRPC metadata.
func (s *Seeder) outgoingCtx(ctx context.Context) context.Context {
	md := metadata.Pairs("authorization", "Bearer "+s.token)
	if s.tenantSlug != "" {
		md.Append("x-tenant-slug", s.tenantSlug)
	}
	return metadata.NewOutgoingContext(ctx, md)
}

func (s *Seeder) Close() {
	s.catalogConn.Close()
	s.imageConn.Close()
}

func (s *Seeder) Run(ctx context.Context) error {
	if s.tenantSlug != "" {
		log.Printf("Seeding for tenant: %s", s.tenantSlug)
	}

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
