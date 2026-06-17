package seeder

import (
	"context"
	"fmt"
	"log"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	catalogv1 "github.com/Sokol111/ecommerce-catalog-service-api/gen/connect/catalog/v1"
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
	req := &catalogv1.CreateAttributeRequest{
		Name:    attr.Name,
		Slug:    attr.Slug,
		Type:    toAttributeType(attr.Type),
		Enabled: attr.Enabled,
		Options: toAttributeOptionInputs(attr.Options),
	}
	if attr.ID != "" {
		req.Id = &attr.ID
	}
	if attr.Unit != "" {
		req.Unit = &attr.Unit
	}

	resp, err := s.attributeClient.CreateAttribute(s.outgoingCtx(ctx), req)
	if err != nil {
		return fmt.Errorf("failed to create attribute %s: %w", attr.Name, err)
	}

	log.Printf("  ✓ Created attribute: %s (ID: %s)", attr.Name, resp.Attribute.GetId())
	return nil
}

func (s *Seeder) updateAttribute(ctx context.Context, attr data.Attribute, version int32) error {
	req := &catalogv1.UpdateAttributeRequest{
		Id:      attr.ID,
		Name:    attr.Name,
		Enabled: attr.Enabled,
		Version: version,
		Options: toAttributeOptionInputs(attr.Options),
	}
	if attr.Unit != "" {
		req.Unit = &attr.Unit
	}

	resp, err := s.attributeClient.UpdateAttribute(s.outgoingCtx(ctx), req)
	if err != nil {
		return fmt.Errorf("failed to update attribute %s: %w", attr.Name, err)
	}

	log.Printf("  ✏ Updated attribute: %s (ID: %s)", attr.Name, resp.Attribute.GetId())
	return nil
}

func (s *Seeder) getAttribute(ctx context.Context, id string) (*catalogv1.Attribute, error) {
	resp, err := s.attributeClient.GetAttributeById(s.outgoingCtx(ctx), &catalogv1.GetAttributeByIdRequest{Id: id})
	if err != nil {
		if st, ok := status.FromError(err); ok && st.Code() == codes.NotFound {
			return nil, nil
		}
		return nil, err
	}
	return resp.Attribute, nil
}

func toAttributeType(t string) catalogv1.AttributeType {
	switch t {
	case "SINGLE":
		return catalogv1.AttributeType_ATTRIBUTE_TYPE_SINGLE
	case "MULTIPLE":
		return catalogv1.AttributeType_ATTRIBUTE_TYPE_MULTIPLE
	case "RANGE":
		return catalogv1.AttributeType_ATTRIBUTE_TYPE_RANGE
	case "BOOLEAN":
		return catalogv1.AttributeType_ATTRIBUTE_TYPE_BOOLEAN
	case "TEXT":
		return catalogv1.AttributeType_ATTRIBUTE_TYPE_TEXT
	default:
		return catalogv1.AttributeType_ATTRIBUTE_TYPE_UNSPECIFIED
	}
}

func toAttributeOptionInputs(options []data.AttributeOption) []*catalogv1.AttributeOptionInput {
	if len(options) == 0 {
		return nil
	}

	inputs := make([]*catalogv1.AttributeOptionInput, len(options))
	for i, opt := range options {
		input := &catalogv1.AttributeOptionInput{
			Name: opt.Name,
			Slug: opt.Slug,
		}
		if opt.ColorCode != "" {
			input.ColorCode = &opt.ColorCode
		}
		if opt.SortOrder > 0 {
			so := int32(opt.SortOrder)
			input.SortOrder = &so
		}
		inputs[i] = input
	}
	return inputs
}
