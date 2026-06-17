package config

import (
	"flag"
	"os"
)

// Config represents the seeder runtime configuration.
type Config struct {
	CatalogGRPCAddr     string
	ImageGRPCAddr       string
	LogtoURL            string
	ClientID            string
	ClientSecret        string
	APIResource         string
	TenantSlug          string
	StorageHostOverride string
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

	flag.StringVar(&args.Config.CatalogGRPCAddr, "catalog-grpc-addr", envOr("CATALOG_GRPC_ADDR", "ecommerce-catalog-service.127.0.0.1.nip.io:8080"), "Catalog service gRPC address (host:port)")
	flag.StringVar(&args.Config.ImageGRPCAddr, "image-grpc-addr", envOr("IMAGE_GRPC_ADDR", "ecommerce-image-service.127.0.0.1.nip.io:8080"), "Image service gRPC address (host:port)")
	flag.StringVar(&args.Config.LogtoURL, "logto-url", envOr("LOGTO_URL", "http://localhost:3001"), "Logto OIDC issuer URL")
	flag.StringVar(&args.Config.ClientID, "client-id", envOr("LOGTO_CLIENT_ID", ""), "Logto M2M application client ID")
	flag.StringVar(&args.Config.ClientSecret, "client-secret", envOr("LOGTO_CLIENT_SECRET", ""), "Logto M2M application client secret")
	flag.StringVar(&args.Config.APIResource, "api-resource", envOr("API_RESOURCE_INDICATOR", "https://api.sokolshop.com"), "Logto API resource indicator")
	flag.StringVar(&args.Config.TenantSlug, "tenant-slug", envOr("TENANT_SLUG", ""), "Tenant slug to seed data for (sets X-Tenant-Slug header)")
	flag.StringVar(&args.Config.StorageHostOverride, "storage-host-override", envOr("STORAGE_HOST_OVERRIDE", ""), "Override presigned URL host (e.g. minio:9000 for in-cluster access)")
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
