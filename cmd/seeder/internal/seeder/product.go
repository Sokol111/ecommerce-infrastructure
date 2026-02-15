package seeder

import (
	"context"
	"fmt"
	"log"

	"github.com/google/uuid"

	catalogapi "github.com/Sokol111/ecommerce-catalog-service-api/gen/httpapi"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/data"
)

func (s *Seeder) upsertProducts(ctx context.Context) error {
	for _, prod := range s.data.Products {
		if err := s.upsertProduct(ctx, prod); err != nil {
			return err
		}
	}
	return nil
}

func (s *Seeder) upsertProduct(ctx context.Context, prod data.Product) error {
	if prod.ID == "" {
		return s.createProduct(ctx, prod)
	}

	existing, err := s.getProduct(ctx, prod.ID)
	if err != nil {
		return fmt.Errorf("failed to check product %s: %w", prod.Name, err)
	}

	if existing != nil {
		return s.updateProduct(ctx, prod, existing.Version)
	}
	return s.createProduct(ctx, prod)
}

func (s *Seeder) createProduct(ctx context.Context, prod data.Product) error {
	req := &catalogapi.CreateProductRequest{
		Name:       prod.Name,
		Price:      float64(prod.Price),
		Quantity:   prod.Quantity,
		Enabled:    prod.Enabled,
		CategoryId: s.parseOptUUID(prod.CategoryID),
		ImageId:    s.resolveProductImage(ctx, prod),
		ID:         s.parseOptUUID(prod.ID),
	}
	if prod.Description != "" {
		req.Description = catalogapi.NewOptString(prod.Description)
	}

	resp, err := s.catalogClient.CreateProduct(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to create product %s: %w", prod.Name, err)
	}

	prodResp, ok := resp.(*catalogapi.ProductResponse)
	if !ok {
		return fmt.Errorf("unexpected response type %T for product %s", resp, prod.Name)
	}

	log.Printf("  ✓ Created product: %s (ID: %s)", prod.Name, prodResp.ID)
	return nil
}

func (s *Seeder) updateProduct(ctx context.Context, prod data.Product, version int) error {
	prodUUID, _ := uuid.Parse(prod.ID)

	req := &catalogapi.UpdateProductRequest{
		ID:         prodUUID,
		Name:       prod.Name,
		Price:      float64(prod.Price),
		Quantity:   prod.Quantity,
		Enabled:    prod.Enabled,
		CategoryId: s.parseOptUUID(prod.CategoryID),
		ImageId:    s.resolveProductImage(ctx, prod),
		Version:    version,
	}
	if prod.Description != "" {
		req.Description = catalogapi.NewOptString(prod.Description)
	}

	resp, err := s.catalogClient.UpdateProduct(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to update product %s: %w", prod.Name, err)
	}

	prodResp, ok := resp.(*catalogapi.ProductResponse)
	if !ok {
		return fmt.Errorf("unexpected response type %T for product %s", resp, prod.Name)
	}

	log.Printf("  ✏ Updated product: %s (ID: %s)", prod.Name, prodResp.ID)
	return nil
}

func (s *Seeder) resolveProductImage(ctx context.Context, prod data.Product) catalogapi.OptUUID {
	imageFile := prod.ID + ".jpg"
	if imgID := s.tryUploadImage(ctx, imageFile, prod.Name); imgID.IsSet() {
		return imgID
	}

	if prod.CategoryID != "" {
		fallbackFile := fmt.Sprintf("category-%s.png", prod.CategoryID)
		return s.tryUploadImage(ctx, fallbackFile, prod.Name)
	}

	return catalogapi.OptUUID{}
}

func (s *Seeder) tryUploadImage(ctx context.Context, filename, altText string) catalogapi.OptUUID {
	// Check cache first
	if cachedID, ok := s.imageCache[filename]; ok {
		return s.parseOptUUID(cachedID)
	}

	imgIDStr, err := s.uploadImage(ctx, filename, altText)
	if err != nil {
		log.Printf("  ⚠ Warning: failed to upload image %s: %v", filename, err)
		return catalogapi.OptUUID{}
	}

	// Cache the result
	s.imageCache[filename] = imgIDStr
	return s.parseOptUUID(imgIDStr)
}

func (s *Seeder) parseOptUUID(str string) catalogapi.OptUUID {
	if str == "" {
		return catalogapi.OptUUID{}
	}
	parsed, err := uuid.Parse(str)
	if err != nil {
		log.Printf("  ⚠ Warning: invalid UUID %s: %v", str, err)
		return catalogapi.OptUUID{}
	}
	return catalogapi.NewOptUUID(parsed)
}

func (s *Seeder) getProduct(ctx context.Context, id string) (*catalogapi.ProductResponse, error) {
	parsedUUID, err := uuid.Parse(id)
	if err != nil {
		return nil, fmt.Errorf("invalid UUID: %w", err)
	}

	resp, err := s.catalogClient.GetProductById(ctx, catalogapi.GetProductByIdParams{ID: parsedUUID})
	if err != nil {
		return nil, err
	}

	switch r := resp.(type) {
	case *catalogapi.ProductResponse:
		return r, nil
	case *catalogapi.GetProductByIdNotFound:
		return nil, nil
	default:
		return nil, fmt.Errorf("unexpected response type: %T", resp)
	}
}
