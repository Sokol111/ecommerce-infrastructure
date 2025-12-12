package main

import (
	"log"
)

func main() {
	config, err := loadConfig("config.yaml")
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	seedData, err := loadSeedDataJSON(config.DataFile)
	if err != nil {
		log.Fatalf("Failed to load seed data: %v", err)
	}

	seeder, err := NewSeeder(config, seedData, "assets")
	if err != nil {
		log.Fatalf("Failed to create seeder: %v", err)
	}

	if err := seeder.Run(); err != nil {
		log.Fatalf("Seeding failed: %v", err)
	}
}
