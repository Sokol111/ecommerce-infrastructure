package main

import (
	"log"
)

func main() {
	config, err := loadConfig("seed-data.yaml")
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	seeder, err := NewSeeder(config, "assets")
	if err != nil {
		log.Fatalf("Failed to create seeder: %v", err)
	}

	if err := seeder.Run(); err != nil {
		log.Fatalf("Seeding failed: %v", err)
	}
}
