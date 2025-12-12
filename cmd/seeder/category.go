package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"

	"github.com/google/uuid"

	categoryapi "github.com/Sokol111/ecommerce-category-service-api/gen/httpapi"
)

func (s *Seeder) createCategories() error {
	ctx := context.Background()

	for _, cat := range s.config.Categories {
		// Check if category already exists by ID
		if cat.ID != "" {
			exists, err := s.categoryExists(ctx, cat.ID)
			if err != nil {
				return fmt.Errorf("failed to check category %s: %w", cat.Name, err)
			}
			if exists {
				log.Printf("  ⏭ Category already exists: %s (ID: %s)", cat.Name, cat.ID)
				continue
			}
		}

		req := categoryapi.CreateCategoryJSONRequestBody{
			Name:    cat.Name,
			Enabled: cat.Enabled,
		}

		// Use client-provided ID if specified
		if cat.ID != "" {
			parsedUUID, err := uuid.Parse(cat.ID)
			if err != nil {
				return fmt.Errorf("invalid category UUID %s: %w", cat.ID, err)
			}
			req.Id = &parsedUUID
		}

		resp, err := s.categoryClient.CreateCategory(ctx, req)
		if err != nil {
			return fmt.Errorf("failed to create category %s: %w", cat.Name, err)
		}
		defer resp.Body.Close()

		if resp.StatusCode >= 300 {
			body, _ := io.ReadAll(resp.Body)
			return fmt.Errorf("failed to create category %s: status %d, body: %s", cat.Name, resp.StatusCode, string(body))
		}

		var catResp categoryapi.CategoryResponse
		if err := json.NewDecoder(resp.Body).Decode(&catResp); err != nil {
			return fmt.Errorf("failed to parse category response for %s: %w", cat.Name, err)
		}

		log.Printf("  ✓ Created category: %s (ID: %s)", cat.Name, catResp.Id)
	}
	return nil
}

func (s *Seeder) categoryExists(ctx context.Context, id string) (bool, error) {
	resp, err := s.categoryClient.GetCategoryById(ctx, id)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	return resp.StatusCode == 200, nil
}
