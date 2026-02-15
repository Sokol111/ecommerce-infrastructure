package main

import (
	"context"
	"log"
	"os/signal"
	"syscall"

	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/config"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/data"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/seeder"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	args := config.Parse()

	seedData, err := data.LoadFromDir(args.DataDir)
	if err != nil {
		log.Fatalf("Failed to load seed data: %v", err)
	}

	s, err := seeder.New(args.Config, seedData, args.AssetsDir)
	if err != nil {
		log.Fatalf("Failed to create seeder: %v", err)
	}

	if err := s.Run(ctx); err != nil {
		log.Fatalf("Seeding failed: %v", err)
	}
}
