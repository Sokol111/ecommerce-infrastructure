package main

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// Config represents the seeder runtime configuration (endpoints + paths).
type Config struct {
	Services ServicesConfig `yaml:"services"`
	DataFile string         `yaml:"dataFile"`
}

type ServicesConfig struct {
	CategoryService string `yaml:"categoryService"`
	ProductService  string `yaml:"productService"`
	ImageService    string `yaml:"imageService"`
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

	if config.DataFile == "" {
		config.DataFile = "seed-data.json"
	}

	return &config, nil
}
