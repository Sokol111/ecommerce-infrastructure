package data

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// SeedData represents demo content (categories/products/attributes) loaded from JSON files.
type SeedData struct {
	Categories []Category
	Products   []Product
	Attributes []Attribute
}

type Category struct {
	ID         string              `json:"id"`
	Name       string              `json:"name"`
	Enabled    bool                `json:"enabled"`
	Attributes []CategoryAttribute `json:"attributes,omitempty"`
}

type CategoryAttribute struct {
	AttributeID string `json:"attributeId"`
	Role        string `json:"role"`
	SortOrder   int    `json:"sortOrder,omitempty"`
	Filterable  bool   `json:"filterable"`
	Searchable  bool   `json:"searchable"`
}

type Product struct {
	ID          string             `json:"id"`
	Name        string             `json:"name"`
	Description string             `json:"description"`
	Price       float64            `json:"price"`
	Quantity    int                `json:"quantity"`
	CategoryID  string             `json:"categoryId"`
	Enabled     bool               `json:"enabled"`
	Attributes  []ProductAttribute `json:"attributes,omitempty"`
}

type ProductAttribute struct {
	AttributeID      string   `json:"attributeId"`
	OptionSlugValue  string   `json:"optionSlugValue,omitempty"`
	OptionSlugValues []string `json:"optionSlugValues,omitempty"`
	NumericValue     *float64 `json:"numericValue,omitempty"`
	TextValue        string   `json:"textValue,omitempty"`
	BooleanValue     *bool    `json:"booleanValue,omitempty"`
}

type Attribute struct {
	ID      string            `json:"id"`
	Name    string            `json:"name"`
	Slug    string            `json:"slug"`
	Type    string            `json:"type"`
	Unit    string            `json:"unit,omitempty"`
	Enabled bool              `json:"enabled"`
	Options []AttributeOption `json:"options,omitempty"`
}

type AttributeOption struct {
	Name      string `json:"name"`
	Slug      string `json:"slug"`
	ColorCode string `json:"colorCode,omitempty"`
	SortOrder int    `json:"sortOrder,omitempty"`
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

	attributes, err := loadFile[Attribute](filepath.Join(dir, "attributes.json"))
	if err != nil {
		return nil, fmt.Errorf("failed to load attributes: %w", err)
	}

	return &SeedData{
		Categories: categories,
		Products:   products,
		Attributes: attributes,
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
