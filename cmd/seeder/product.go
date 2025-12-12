package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"

	"github.com/google/uuid"

	productapi "github.com/Sokol111/ecommerce-product-service-api/gen/httpapi"
)

func (s *Seeder) createProducts() error {
	ctx := context.Background()

	for _, prod := range s.data.Products {
		// Check if product already exists by ID
		if prod.ID != "" {
			exists, err := s.productExists(ctx, prod.ID)
			if err != nil {
				return fmt.Errorf("failed to check product %s: %w", prod.Name, err)
			}
			if exists {
				log.Printf("  ⏭ Product already exists: %s (ID: %s)", prod.Name, prod.ID)
				continue
			}
		}

		// Parse category ID if specified
		var categoryID *uuid.UUID
		if prod.CategoryID != "" {
			parsedUUID, err := uuid.Parse(prod.CategoryID)
			if err != nil {
				return fmt.Errorf("invalid category UUID %s for product %s: %w", prod.CategoryID, prod.Name, err)
			}
			categoryID = &parsedUUID
		}

		// Upload image if specified
		var imageID *uuid.UUID
		if prod.ImageFile != "" {
			imgIDStr, err := s.uploadImage(prod.ImageFile, prod.Name)
			if err != nil {
				log.Printf("  ⚠ Warning: failed to upload image for %s: %v", prod.Name, err)
			} else if imgIDStr != "" {
				parsedUUID, err := uuid.Parse(imgIDStr)
				if err != nil {
					log.Printf("  ⚠ Warning: invalid image UUID %s: %v", imgIDStr, err)
				} else {
					imageID = &parsedUUID
				}
			}
		}

		// Build request using generated types
		req := productapi.CreateProductJSONRequestBody{
			Name:     prod.Name,
			Price:    prod.Price,
			Quantity: prod.Quantity,
			Enabled:  prod.Enabled,
		}

		// Use client-provided ID if specified
		if prod.ID != "" {
			parsedUUID, err := uuid.Parse(prod.ID)
			if err != nil {
				return fmt.Errorf("invalid product UUID %s: %w", prod.ID, err)
			}
			req.Id = &parsedUUID
		}

		if prod.Description != "" {
			req.Description = &prod.Description
		}
		if categoryID != nil {
			req.CategoryId = categoryID
		}
		if imageID != nil {
			req.ImageId = imageID
		}

		resp, err := s.productClient.CreateProduct(ctx, req)
		if err != nil {
			return fmt.Errorf("failed to create product %s: %w", prod.Name, err)
		}
		defer resp.Body.Close()

		if resp.StatusCode >= 300 {
			body, _ := io.ReadAll(resp.Body)
			return fmt.Errorf("failed to create product %s: status %d, body: %s", prod.Name, resp.StatusCode, string(body))
		}

		var prodResp productapi.ProductResponse
		if err := json.NewDecoder(resp.Body).Decode(&prodResp); err != nil {
			return fmt.Errorf("failed to parse product response for %s: %w", prod.Name, err)
		}

		log.Printf("  ✓ Created product: %s (ID: %s)", prod.Name, prodResp.Id)
	}
	return nil
}

func (s *Seeder) productExists(ctx context.Context, id string) (bool, error) {
	resp, err := s.productClient.GetProductById(ctx, id)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	return resp.StatusCode == 200, nil
}
