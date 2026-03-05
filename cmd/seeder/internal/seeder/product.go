package seeder

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

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
	imageID := s.resolveProductImage(ctx, prod)
	enabled := prod.Enabled
	if enabled && !imageID.IsSet() {
		log.Printf("  ⚠ No image found for product %s, creating as disabled", prod.Name)
		enabled = false
	}

	req := &catalogapi.CreateProductRequest{
		Name:       prod.Name,
		Price:      float64(prod.Price),
		Quantity:   prod.Quantity,
		Enabled:    enabled,
		CategoryId: s.parseOptUUID(prod.CategoryID),
		ImageId:    imageID,
		ID:         s.parseOptUUID(prod.ID),
		Attributes: toAttributeValueInputs(prod.Attributes),
	}
	if prod.Description != "" {
		req.Description = catalogapi.NewOptString(prod.Description)
	}

	resp, err := s.catalogClient.CreateProduct(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to create product %s: %w", prod.Name, err)
	}

	switch r := resp.(type) {
	case *catalogapi.ProductResponse:
		log.Printf("  ✓ Created product: %s (ID: %s)", prod.Name, r.ID)
		return nil
	case *catalogapi.CreateProductBadRequest:
		return fmt.Errorf("failed to create product %s: %s", prod.Name, r.Title)
	default:
		return fmt.Errorf("unexpected response type %T for product %s", resp, prod.Name)
	}
}

func (s *Seeder) updateProduct(ctx context.Context, prod data.Product, version int) error {
	prodUUID, _ := uuid.Parse(prod.ID)
	imageID := s.resolveProductImage(ctx, prod)
	enabled := prod.Enabled
	if enabled && !imageID.IsSet() {
		log.Printf("  ⚠ No image found for product %s, updating as disabled", prod.Name)
		enabled = false
	}

	req := &catalogapi.UpdateProductRequest{
		ID:         prodUUID,
		Name:       prod.Name,
		Price:      float64(prod.Price),
		Quantity:   prod.Quantity,
		Enabled:    enabled,
		CategoryId: s.parseOptUUID(prod.CategoryID),
		ImageId:    imageID,
		Version:    version,
		Attributes: toAttributeValueInputs(prod.Attributes),
	}
	if prod.Description != "" {
		req.Description = catalogapi.NewOptString(prod.Description)
	}

	resp, err := s.catalogClient.UpdateProduct(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to update product %s: %w", prod.Name, err)
	}

	switch r := resp.(type) {
	case *catalogapi.ProductResponse:
		log.Printf("  ✏ Updated product: %s (ID: %s)", prod.Name, r.ID)
		return nil
	case *catalogapi.UpdateProductBadRequest:
		return fmt.Errorf("failed to update product %s: %s", prod.Name, r.Title)
	default:
		return fmt.Errorf("unexpected response type %T for product %s", resp, prod.Name)
	}
}

func (s *Seeder) resolveProductImage(ctx context.Context, prod data.Product) catalogapi.OptUUID {
	if prod.ID != "" {
		imageFile := prod.ID + ".jpg"
		if s.imageFileExists(imageFile) {
			if imgID := s.tryUploadImage(ctx, imageFile, prod.Name); imgID.IsSet() {
				return imgID
			}
		}
	}

	if prod.CategoryID != "" {
		fallbackFile := fmt.Sprintf("category-%s.jpg", prod.CategoryID)
		if s.imageFileExists(fallbackFile) {
			return s.tryUploadImage(ctx, fallbackFile, prod.Name)
		}
	}

	return catalogapi.OptUUID{}
}

func (s *Seeder) imageFileExists(filename string) bool {
	imagePath := filepath.Join(s.assetsDir, filename)
	_, err := os.Stat(imagePath)
	return err == nil
}

func (s *Seeder) tryUploadImage(ctx context.Context, filename, altText string) catalogapi.OptUUID {
	imgIDStr, err := s.uploadImage(ctx, filename, altText)
	if err != nil {
		log.Printf("  ⚠ Warning: failed to upload image %s: %v", filename, err)
		return catalogapi.OptUUID{}
	}

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

func toAttributeValueInputs(attrs []data.ProductAttribute) []catalogapi.AttributeValueInput {
	if len(attrs) == 0 {
		return nil
	}

	inputs := make([]catalogapi.AttributeValueInput, len(attrs))
	for i, a := range attrs {
		attrUUID, _ := uuid.Parse(a.AttributeID)
		inputs[i] = catalogapi.AttributeValueInput{
			AttributeId: attrUUID,
		}
		if a.OptionSlugValue != "" {
			inputs[i].OptionSlugValue = catalogapi.NewOptString(a.OptionSlugValue)
		}
		if len(a.OptionSlugValues) > 0 {
			inputs[i].OptionSlugValues = a.OptionSlugValues
		}
		if a.NumericValue != nil {
			inputs[i].NumericValue = catalogapi.NewOptFloat64(*a.NumericValue)
		}
		if a.TextValue != "" {
			inputs[i].TextValue = catalogapi.NewOptString(a.TextValue)
		}
		if a.BooleanValue != nil {
			inputs[i].BooleanValue = catalogapi.NewOptBool(*a.BooleanValue)
		}
	}
	return inputs
}
