package main

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// Config represents the seeder configuration
type Config struct {
	Services   ServicesConfig `yaml:"services"`
	Categories []Category     `yaml:"categories"`
	Products   []Product      `yaml:"products"`
}

type ServicesConfig struct {
	CategoryService string `yaml:"categoryService"`
	ProductService  string `yaml:"productService"`
	ImageService    string `yaml:"imageService"`
}

type Category struct {
	ID      string `yaml:"id"`
	Name    string `yaml:"name"`
	Enabled bool   `yaml:"enabled"`
}

type Product struct {
	ID          string  `yaml:"id"`
	Name        string  `yaml:"name"`
	Description string  `yaml:"description"`
	Price       float32 `yaml:"price"`
	Quantity    int     `yaml:"quantity"`
	CategoryID  string  `yaml:"categoryId"` // Direct category UUID
	ImageFile   string  `yaml:"imageFile"`  // Local file path for image
	Enabled     bool    `yaml:"enabled"`
}

func loadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	return &config, nil
}
