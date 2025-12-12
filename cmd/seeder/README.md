# Demo Data Seeder

CLI tool for populating the ecommerce database with demo data through service APIs.

## Why through APIs?

This seeder calls actual service endpoints instead of directly inserting into databases because:
- Ensures all Kafka events are properly emitted
- Validates data through the same business logic as production
- Query services receive proper events to update their read models
- Maintains data consistency across all services

## Features

- ✅ Creates categories via Category Service API
- ✅ Creates products via Product Service API  
- ✅ Uploads images via Image Service API (presigned URL flow)
- ✅ Automatic category → product linking
- ✅ Dry-run mode for testing
- ✅ Configurable via YAML

## Prerequisites

All services must be running:
- `ecommerce-category-service` (default: http://localhost:8081)
- `ecommerce-product-service` (default: http://localhost:8082)
- `ecommerce-image-service` (default: http://localhost:8084)

## Usage

### Build

```bash
cd cmd/seeder
go build -o seeder .
```

### Run

```bash
# With default configuration
./seeder

# With custom config file
./seeder -config /path/to/seed-data.yaml

# With custom assets directory (for images)
./seeder -assets /path/to/images

# Dry run (no actual API calls)
./seeder -dry-run

# Verbose output
./seeder -verbose
```

### Command Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `-config` | `seed-data.yaml` | Path to seed data configuration file |
| `-assets` | `assets` | Path to assets directory containing images |
| `-dry-run` | `false` | Perform a dry run without making actual API calls |
| `-verbose` | `false` | Enable verbose output |

## Configuration File

The seed data is configured in `seed-data.yaml`:

```yaml
services:
  categoryService: http://localhost:8081
  productService: http://localhost:8082
  imageService: http://localhost:8084

categories:
  - name: "Electronics"
    enabled: true
  - name: "Smartphones"
    enabled: true

products:
  - name: "iPhone 15 Pro"
    description: "Apple's flagship smartphone"
    price: 1199.99
    quantity: 50
    categoryRef: "Smartphones"  # References category by name
    imageFile: "iphone-15.jpg"  # File from assets directory
    enabled: true
```

## Adding Images

1. Place your product images in the `assets/` directory
2. Reference the filename in the product's `imageFile` field
3. Supported formats: JPEG, PNG, WebP, GIF

## Running with Docker Compose

If using the local development environment:

```bash
# Start all services
cd ecommerce-infrastructure
make dev

# In another terminal, run the seeder
cd cmd/seeder
go run . -verbose
```

## Adding More Demo Data

Edit `seed-data.yaml` to add:
- New categories
- New products
- Update service URLs

The seeder will:
1. Create all categories first
2. Map category names to their generated IDs
3. Upload images (if specified)
4. Create products with proper category and image references
