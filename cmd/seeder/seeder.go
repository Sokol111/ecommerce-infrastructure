package main

import (
	"fmt"
	"log"
	"net/http"
	"time"

	categoryapi "github.com/Sokol111/ecommerce-category-service-api/gen/httpapi"
	imageapi "github.com/Sokol111/ecommerce-image-service-api/gen/httpapi"
	productapi "github.com/Sokol111/ecommerce-product-service-api/gen/httpapi"
)

type Seeder struct {
	config         *Config
	httpClient     *http.Client
	assetsDir      string
	categoryClient *categoryapi.Client
	productClient  *productapi.Client
	imageClient    *imageapi.Client
}

func NewSeeder(config *Config, assetsDir string) (*Seeder, error) {
	httpClient := &http.Client{
		Timeout: 30 * time.Second,
	}

	categoryClient, err := categoryapi.NewClient(config.Services.CategoryService, categoryapi.WithHTTPClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("failed to create category client: %w", err)
	}

	productClient, err := productapi.NewClient(config.Services.ProductService, productapi.WithHTTPClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("failed to create product client: %w", err)
	}

	imageClient, err := imageapi.NewClient(config.Services.ImageService, imageapi.WithHTTPClient(httpClient))
	if err != nil {
		return nil, fmt.Errorf("failed to create image client: %w", err)
	}

	return &Seeder{
		config:         config,
		httpClient:     httpClient,
		assetsDir:      assetsDir,
		categoryClient: categoryClient,
		productClient:  productClient,
		imageClient:    imageClient,
	}, nil
}

func (s *Seeder) Run() error {
	log.Println("🚀 Starting demo data seeder...")

	// Step 1: Create categories
	log.Println("\n📁 Creating categories...")
	if err := s.createCategories(); err != nil {
		return fmt.Errorf("failed to create categories: %w", err)
	}

	// Step 2: Create products with images
	log.Println("\n📦 Creating products...")
	if err := s.createProducts(); err != nil {
		return fmt.Errorf("failed to create products: %w", err)
	}

	log.Println("\n✅ Demo data seeding completed successfully!")
	return nil
}
