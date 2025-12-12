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
- ✅ Idempotent: skips entities that already exist (GET-by-ID)
- ✅ Endpoints via YAML + demo data via JSON

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
```

## Configuration Files

This seeder uses two files:

- `config.yaml` for service endpoints and the data file pointer
- `seed-data.json` for demo content (categories/products)

### config.yaml (endpoints)

```yaml
services:
  categoryService: http://localhost:8081
  productService: http://localhost:8082
  imageService: http://localhost:8084

dataFile: seed-data.json
```

### seed-data.json (data)

```json
{
  "categories": [
    {"id": "13ef613d-038b-4010-8462-835e57713025", "name": "Electronics", "enabled": true}
  ],
  "products": [
    {
      "id": "3780f1b5-434f-48c5-813a-abb7b936cb3c",
      "name": "iPhone 15 Pro Max",
      "description": "Apple's flagship smartphone",
      "price": 1199.99,
      "quantity": 50,
      "categoryId": "eff2c798-bfaa-49dc-a6e2-209a30822625",
      "imageFile": "iphone-15-pro.jpg",
      "enabled": true
    }
  ]
}
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
go run .
```

## Adding More Demo Data

Edit `seed-data.json` to add:
- New categories
- New products
- Update service URLs in `config.yaml`

The seeder will:
1. Create all categories first
2. Upload images (if specified)
3. Create products with proper category and image references
