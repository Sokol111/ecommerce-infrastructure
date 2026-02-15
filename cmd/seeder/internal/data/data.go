package data

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// SeedData represents demo content (categories/products) loaded from JSON files.
type SeedData struct {
	Categories []Category
	Products   []Product
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
	CategoryID  string  `json:"categoryId"`
	Enabled     bool    `json:"enabled"`
}

// LoadFromDir loads seed data from a directory containing categories.json and products.json.
func LoadFromDir(dir string) (*SeedData, error) {
	categories, err := loadFile[Category](filepath.Join(dir, "categories.json"))
	if err != nil {
		return nil, fmt.Errorf("failed to load categories: %w", err)
	}

	products, err := loadFile[Product](filepath.Join(dir, "products.json"))
	if err != nil {
		return nil, fmt.Errorf("failed to load products: %w", err)
	}

	return &SeedData{
		Categories: categories,
		Products:   products,
	}, nil
}

func loadFile[T any](path string) ([]T, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var items []T
	if err := json.Unmarshal(data, &items); err != nil {
		return nil, err
	}

	return items, nil
}
