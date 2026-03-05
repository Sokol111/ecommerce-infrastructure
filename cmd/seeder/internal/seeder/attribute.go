package seeder

import (
	"context"
	"fmt"
	"log"

	"github.com/google/uuid"

	catalogapi "github.com/Sokol111/ecommerce-catalog-service-api/gen/httpapi"
	"github.com/Sokol111/ecommerce-infrastructure/cmd/seeder/internal/data"
)

func (s *Seeder) upsertAttributes(ctx context.Context) error {
	for _, attr := range s.data.Attributes {
		if err := s.upsertAttribute(ctx, attr); err != nil {
			return err
		}
	}
	return nil
}

func (s *Seeder) upsertAttribute(ctx context.Context, attr data.Attribute) error {
	if attr.ID == "" {
		return s.createAttribute(ctx, attr)
	}

	existing, err := s.getAttribute(ctx, attr.ID)
	if err != nil {
		return fmt.Errorf("failed to check attribute %s: %w", attr.Name, err)
	}

	if existing != nil {
		return s.updateAttribute(ctx, attr, existing.Version)
	}
	return s.createAttribute(ctx, attr)
}

func (s *Seeder) createAttribute(ctx context.Context, attr data.Attribute) error {
	req := &catalogapi.CreateAttributeRequest{
		Name:    attr.Name,
		Slug:    attr.Slug,
		Type:    catalogapi.CreateAttributeRequestType(attr.Type),
		Enabled: attr.Enabled,
		ID:      s.parseOptUUID(attr.ID),
		Options: toAttributeOptionInputs(attr.Options),
	}
	if attr.Unit != "" {
		req.Unit = catalogapi.NewOptString(attr.Unit)
	}

	resp, err := s.catalogClient.CreateAttribute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to create attribute %s: %w", attr.Name, err)
	}

	attrResp, ok := resp.(*catalogapi.AttributeResponse)
	if !ok {
		return fmt.Errorf("unexpected response type %T for attribute %s", resp, attr.Name)
	}

	log.Printf("  ✓ Created attribute: %s (ID: %s)", attr.Name, attrResp.ID)
	return nil
}

func (s *Seeder) updateAttribute(ctx context.Context, attr data.Attribute, version int) error {
	attrUUID, _ := uuid.Parse(attr.ID)

	req := &catalogapi.UpdateAttributeRequest{
		ID:      attrUUID,
		Name:    attr.Name,
		Enabled: attr.Enabled,
		Version: version,
		Options: toAttributeOptionInputs(attr.Options),
	}
	if attr.Unit != "" {
		req.Unit = catalogapi.NewOptString(attr.Unit)
	}

	resp, err := s.catalogClient.UpdateAttribute(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to update attribute %s: %w", attr.Name, err)
	}

	attrResp, ok := resp.(*catalogapi.AttributeResponse)
	if !ok {
		return fmt.Errorf("unexpected response type %T for attribute %s", resp, attr.Name)
	}

	log.Printf("  ✏ Updated attribute: %s (ID: %s)", attr.Name, attrResp.ID)
	return nil
}

func (s *Seeder) getAttribute(ctx context.Context, id string) (*catalogapi.AttributeResponse, error) {
	parsedUUID, err := uuid.Parse(id)
	if err != nil {
		return nil, fmt.Errorf("invalid UUID: %w", err)
	}

	resp, err := s.catalogClient.GetAttributeById(ctx, catalogapi.GetAttributeByIdParams{ID: parsedUUID})
	if err != nil {
		return nil, err
	}

	switch r := resp.(type) {
	case *catalogapi.AttributeResponse:
		return r, nil
	case *catalogapi.GetAttributeByIdNotFound:
		return nil, nil
	default:
		return nil, fmt.Errorf("unexpected response type: %T", resp)
	}
}

func toAttributeOptionInputs(options []data.AttributeOption) []catalogapi.AttributeOptionInput {
	if len(options) == 0 {
		return nil
	}

	inputs := make([]catalogapi.AttributeOptionInput, len(options))
	for i, opt := range options {
		inputs[i] = catalogapi.AttributeOptionInput{
			Name: opt.Name,
			Slug: opt.Slug,
		}
		if opt.ColorCode != "" {
			inputs[i].ColorCode = catalogapi.NewOptString(opt.ColorCode)
		}
		if opt.SortOrder > 0 {
			inputs[i].SortOrder = catalogapi.OptInt{Value: opt.SortOrder, Set: true}
		}
	}
	return inputs
}
