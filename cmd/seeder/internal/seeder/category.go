package seeder

import (
	"context"
	"fmt"
	"log"

	"github.com/google/uuid"

	catalogapi "github.com/Sokol111/ecommerce-catalog-service-api/gen/httpapi"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/data"
)

func (s *Seeder) upsertCategories(ctx context.Context) error {
	for _, cat := range s.data.Categories {
		if err := s.upsertCategory(ctx, cat); err != nil {
			return err
		}
	}
	return nil
}

func (s *Seeder) upsertCategory(ctx context.Context, cat data.Category) error {
	if cat.ID == "" {
		return s.createCategory(ctx, cat)
	}

	existing, err := s.getCategory(ctx, cat.ID)
	if err != nil {
		return fmt.Errorf("failed to check category %s: %w", cat.Name, err)
	}

	if existing != nil {
		return s.updateCategory(ctx, cat, existing.Version)
	}
	return s.createCategory(ctx, cat)
}

func (s *Seeder) createCategory(ctx context.Context, cat data.Category) error {
	req := &catalogapi.CreateCategoryRequest{
		Name:    cat.Name,
		Enabled: cat.Enabled,
		ID:      s.parseOptUUID(cat.ID),
	}

	resp, err := s.catalogClient.CreateCategory(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to create category %s: %w", cat.Name, err)
	}

	catResp, ok := resp.(*catalogapi.CategoryResponse)
	if !ok {
		return fmt.Errorf("unexpected response type %T for category %s", resp, cat.Name)
	}

	log.Printf("  ✓ Created category: %s (ID: %s)", cat.Name, catResp.ID)
	return nil
}

func (s *Seeder) updateCategory(ctx context.Context, cat data.Category, version int) error {
	catUUID, _ := uuid.Parse(cat.ID)

	req := &catalogapi.UpdateCategoryRequest{
		ID:      catUUID,
		Name:    cat.Name,
		Enabled: cat.Enabled,
		Version: version,
	}

	resp, err := s.catalogClient.UpdateCategory(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to update category %s: %w", cat.Name, err)
	}

	catResp, ok := resp.(*catalogapi.CategoryResponse)
	if !ok {
		return fmt.Errorf("unexpected response type %T for category %s", resp, cat.Name)
	}

	log.Printf("  ✏ Updated category: %s (ID: %s)", cat.Name, catResp.ID)
	return nil
}

func (s *Seeder) getCategory(ctx context.Context, id string) (*catalogapi.CategoryResponse, error) {
	parsedUUID, err := uuid.Parse(id)
	if err != nil {
		return nil, fmt.Errorf("invalid UUID: %w", err)
	}

	resp, err := s.catalogClient.GetCategoryById(ctx, catalogapi.GetCategoryByIdParams{ID: parsedUUID})
	if err != nil {
		return nil, err
	}

	switch r := resp.(type) {
	case *catalogapi.CategoryResponse:
		return r, nil
	case *catalogapi.GetCategoryByIdNotFound:
		return nil, nil
	default:
		return nil, fmt.Errorf("unexpected response type: %T", resp)
	}
}
