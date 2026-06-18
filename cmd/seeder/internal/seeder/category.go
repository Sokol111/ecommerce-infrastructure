package seeder

import (
	"context"
	"fmt"
	"log"
	"strings"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	catalogv1 "github.com/Sokol111/ecommerce-catalog-service-api/gen/connect/catalog/v1"
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
	req := &catalogv1.CreateCategoryRequest{
		Name:       cat.Name,
		Enabled:    cat.Enabled,
		Attributes: toCategoryAttributeInputs(cat.Attributes),
	}
	if cat.ID != "" {
		req.Id = &cat.ID
	}

	resp, err := s.categoryClient.CreateCategory(s.outgoingCtx(ctx), req)
	if err != nil {
		return fmt.Errorf("failed to create category %s: %w", cat.Name, err)
	}

	log.Printf("  ✓ Created category: %s (ID: %s)", cat.Name, resp.Category.GetId())
	return nil
}

func (s *Seeder) updateCategory(ctx context.Context, cat data.Category, version int32) error {
	req := &catalogv1.UpdateCategoryRequest{
		Id:         cat.ID,
		Name:       cat.Name,
		Enabled:    cat.Enabled,
		Version:    version,
		Attributes: toCategoryAttributeInputs(cat.Attributes),
	}

	resp, err := s.categoryClient.UpdateCategory(s.outgoingCtx(ctx), req)
	if err != nil {
		return fmt.Errorf("failed to update category %s: %w", cat.Name, err)
	}

	log.Printf("  ✏ Updated category: %s (ID: %s)", cat.Name, resp.Category.GetId())
	return nil
}

func (s *Seeder) getCategory(ctx context.Context, id string) (*catalogv1.Category, error) {
	resp, err := s.categoryClient.GetCategoryById(s.outgoingCtx(ctx), &catalogv1.GetCategoryByIdRequest{Id: id})
	if err != nil {
		if st, ok := status.FromError(err); ok && st.Code() == codes.NotFound {
			return nil, nil
		}
		return nil, err
	}
	return resp.Category, nil
}

func toCategoryAttributeInputs(attrs []data.CategoryAttribute) []*catalogv1.CategoryAttributeInput {
	result := make([]*catalogv1.CategoryAttributeInput, 0, len(attrs))
	for _, a := range attrs {
		input := &catalogv1.CategoryAttributeInput{
			AttributeId: a.AttributeID,
			Role:        toCategoryAttributeRole(a.Role),
			Filterable:  a.Filterable,
			Searchable:  a.Searchable,
		}
		if a.SortOrder > 0 {
			so := int32(a.SortOrder)
			input.SortOrder = &so
		}
		result = append(result, input)
	}
	return result
}

func toCategoryAttributeRole(role string) catalogv1.CategoryAttributeRole {
	switch strings.ToUpper(role) {
	case "VARIANT":
		return catalogv1.CategoryAttributeRole_CATEGORY_ATTRIBUTE_ROLE_VARIANT
	case "SPECIFICATION":
		return catalogv1.CategoryAttributeRole_CATEGORY_ATTRIBUTE_ROLE_SPECIFICATION
	default:
		return catalogv1.CategoryAttributeRole_CATEGORY_ATTRIBUTE_ROLE_UNSPECIFIED
	}
}
