package seeder

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	catalogv1 "github.com/Sokol111/ecommerce-catalog-service-api/gen/connect/catalog/v1"
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
	if enabled && imageID == "" {
		log.Printf("  ⚠ No image found for product %s, creating as disabled", prod.Name)
		enabled = false
	}

	req := &catalogv1.CreateProductRequest{
		Name:       prod.Name,
		Price:      prod.Price,
		Quantity:   int32(prod.Quantity),
		Enabled:    enabled,
		Attributes: toAttributeValueInputs(prod.Attributes),
	}
	if prod.ID != "" {
		req.Id = &prod.ID
	}
	if prod.Description != "" {
		req.Description = &prod.Description
	}
	if prod.CategoryID != "" {
		req.CategoryId = &prod.CategoryID
	}
	if imageID != "" {
		req.ImageId = &imageID
	}

	resp, err := s.productClient.CreateProduct(s.outgoingCtx(ctx), req)
	if err != nil {
		return fmt.Errorf("failed to create product %s: %w", prod.Name, err)
	}

	log.Printf("  ✓ Created product: %s (ID: %s)", prod.Name, resp.Product.GetId())
	return nil
}

func (s *Seeder) updateProduct(ctx context.Context, prod data.Product, version int64) error {
	imageID := s.resolveProductImage(ctx, prod)
	enabled := prod.Enabled
	if enabled && imageID == "" {
		log.Printf("  ⚠ No image found for product %s, updating as disabled", prod.Name)
		enabled = false
	}

	req := &catalogv1.UpdateProductRequest{
		Id:         prod.ID,
		Name:       prod.Name,
		Price:      prod.Price,
		Quantity:   int32(prod.Quantity),
		Enabled:    enabled,
		Version:    version,
		Attributes: toAttributeValueInputs(prod.Attributes),
	}
	if prod.Description != "" {
		req.Description = &prod.Description
	}
	if prod.CategoryID != "" {
		req.CategoryId = &prod.CategoryID
	}
	if imageID != "" {
		req.ImageId = &imageID
	}

	resp, err := s.productClient.UpdateProduct(s.outgoingCtx(ctx), req)
	if err != nil {
		return fmt.Errorf("failed to update product %s: %w", prod.Name, err)
	}

	log.Printf("  ✏ Updated product: %s (ID: %s)", prod.Name, resp.Product.GetId())
	return nil
}

func (s *Seeder) resolveProductImage(ctx context.Context, prod data.Product) string {
	if prod.ID != "" {
		imageFile := prod.ID + ".jpg"
		if s.imageFileExists(imageFile) {
			if imgID := s.tryUploadImage(ctx, imageFile, prod.Name); imgID != "" {
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

	return ""
}

func (s *Seeder) imageFileExists(filename string) bool {
	imagePath := filepath.Join(s.assetsDir, filename)
	_, err := os.Stat(imagePath)
	return err == nil
}

func (s *Seeder) tryUploadImage(ctx context.Context, filename, altText string) string {
	imgID, err := s.uploadImage(ctx, filename, altText)
	if err != nil {
		log.Printf("  ⚠ Warning: failed to upload image %s: %v", filename, err)
		return ""
	}
	return imgID
}

func (s *Seeder) getProduct(ctx context.Context, id string) (*catalogv1.Product, error) {
	resp, err := s.productClient.GetProductById(s.outgoingCtx(ctx), &catalogv1.GetProductByIdRequest{Id: id})
	if err != nil {
		if st, ok := status.FromError(err); ok && st.Code() == codes.NotFound {
			return nil, nil
		}
		return nil, err
	}
	return resp.Product, nil
}

func toAttributeValueInputs(attrs []data.ProductAttribute) []*catalogv1.AttributeValueInput {
	if len(attrs) == 0 {
		return nil
	}

	inputs := make([]*catalogv1.AttributeValueInput, len(attrs))
	for i, a := range attrs {
		input := &catalogv1.AttributeValueInput{
			AttributeId: a.AttributeID,
		}
		if a.OptionSlugValue != "" {
			input.Value = &catalogv1.AttributeValueInput_OptionSlugValue{OptionSlugValue: a.OptionSlugValue}
		} else if len(a.OptionSlugValues) > 0 {
			input.Value = &catalogv1.AttributeValueInput_OptionSlugValues{
				OptionSlugValues: &catalogv1.StringList{Values: a.OptionSlugValues},
			}
		} else if a.NumericValue != nil {
			input.Value = &catalogv1.AttributeValueInput_NumericValue{NumericValue: *a.NumericValue}
		} else if a.TextValue != "" {
			input.Value = &catalogv1.AttributeValueInput_TextValue{TextValue: a.TextValue}
		} else if a.BooleanValue != nil {
			input.Value = &catalogv1.AttributeValueInput_BooleanValue{BooleanValue: *a.BooleanValue}
		}
		inputs[i] = input
	}
	return inputs
}
