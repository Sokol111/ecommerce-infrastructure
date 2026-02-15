package config

import (
	"flag"
	"os"
)

// Config represents the seeder runtime configuration.
type Config struct {
	CatalogURL string
	ImageURL   string
}

// Args holds all CLI arguments.
type Args struct {
	Config    *Config
	DataDir   string
	AssetsDir string
}

// Parse returns configuration from CLI flags with env variable defaults.
func Parse() *Args {
	args := &Args{
		Config: &Config{},
	}

	flag.StringVar(&args.Config.CatalogURL, "catalog-url", envOr("CATALOG_URL", "http://ecommerce-catalog-service.127.0.0.1.nip.io"), "Catalog service URL")
	flag.StringVar(&args.Config.ImageURL, "image-url", envOr("IMAGE_URL", "http://ecommerce-image-service.127.0.0.1.nip.io"), "Image service URL")
	flag.StringVar(&args.DataDir, "data-dir", envOr("DATA_DIR", "data"), "Path to seed data directory")
	flag.StringVar(&args.AssetsDir, "assets-dir", envOr("ASSETS_DIR", "assets"), "Path to assets directory")
	flag.Parse()

	return args
}

func envOr(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}
