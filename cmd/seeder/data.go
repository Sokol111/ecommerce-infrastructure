package main

import (
	"encoding/json"
	"fmt"
	"os"
)

// SeedData represents demo content (categories/products) loaded from JSON.
// Endpoint configuration is kept in config.yaml.
//
// File format (seed-data.json):
// {
//   "categories": [...],
//   "products": [...]
// }
type SeedData struct {
	Categories []Category `json:"categories"`
	Products   []Product  `json:"products"`
}

type Category struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Enabled bool   `json:"enabled"`
}

type Product struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Price       float32 `json:"price"`
	Quantity    int     `json:"quantity"`
	CategoryID  string  `json:"categoryId"` // Direct category UUID
	ImageFile   string  `json:"imageFile"`  // Local file path for image
	Enabled     bool    `json:"enabled"`
}

func loadSeedDataJSON(path string) (*SeedData, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read seed data file: %w", err)
	}

	var seed SeedData
	if err := json.Unmarshal(data, &seed); err != nil {
		return nil, fmt.Errorf("failed to parse seed data file: %w", err)
	}

	return &seed, nil
}
