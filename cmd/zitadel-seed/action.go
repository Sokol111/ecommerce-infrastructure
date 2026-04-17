package main

import (
	"log/slog"
	"time"

	"google.golang.org/protobuf/types/known/durationpb"

	actionv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/action/v2"
	filterv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/filter/v2"
)

func (s *seeder) setupPermissionsAction() {
	slog.Info("Setting up permissions webhook (Actions v2)")

	// Find or create Target pointing to the webhook handler.
	targets, err := s.actions.ListTargets(s.ctx, &actionv2.ListTargetsRequest{
		Filters: []*actionv2.TargetSearchFilter{{
			Filter: &actionv2.TargetSearchFilter_TargetNameFilter{
				TargetNameFilter: &actionv2.TargetNameFilter{
					TargetName: "permissions-webhook",
					Method:     filterv2.TextFilterMethod_TEXT_FILTER_METHOD_EQUALS,
				},
			},
		}},
	})
	if err != nil {
		fatal("Failed to list targets", "error", err)
	}

	var targetID string
	if len(targets.GetTargets()) > 0 {
		targetID = targets.GetTargets()[0].GetId()
		_, err := s.actions.UpdateTarget(s.ctx, &actionv2.UpdateTargetRequest{
			Id:   targetID,
			Name: strPtr("permissions-webhook"),
			TargetType: &actionv2.UpdateTargetRequest_RestCall{
				RestCall: &actionv2.RESTCall{InterruptOnError: true},
			},
			Timeout:  durationpb.New(10 * time.Second),
			Endpoint: &s.cfg.WebhookURL,
		})
		if err != nil {
			fatal("Failed to update target", "error", err)
		}
		slog.Info("Target updated", "id", targetID)
	} else {
		result, err := s.actions.CreateTarget(s.ctx, &actionv2.CreateTargetRequest{
			Name: "permissions-webhook",
			TargetType: &actionv2.CreateTargetRequest_RestCall{
				RestCall: &actionv2.RESTCall{InterruptOnError: true},
			},
			Timeout:  durationpb.New(10 * time.Second),
			Endpoint: s.cfg.WebhookURL,
		})
		if err != nil {
			fatal("Failed to create target", "error", err)
		}
		targetID = result.GetId()
		slog.Info("Created target", "id", targetID)
	}

	// Bind target to preaccesstoken function.
	_, err = s.actions.SetExecution(s.ctx, &actionv2.SetExecutionRequest{
		Condition: &actionv2.Condition{
			ConditionType: &actionv2.Condition_Function{
				Function: &actionv2.FunctionExecution{Name: "preaccesstoken"},
			},
		},
		Targets: []string{targetID},
	})
	if err != nil {
		fatal("Failed to set preaccesstoken execution", "error", err)
	}
	slog.Info("Execution set for preaccesstoken")

	// Bind target to preuserinfo function.
	_, err = s.actions.SetExecution(s.ctx, &actionv2.SetExecutionRequest{
		Condition: &actionv2.Condition{
			ConditionType: &actionv2.Condition_Function{
				Function: &actionv2.FunctionExecution{Name: "preuserinfo"},
			},
		},
		Targets: []string{targetID},
	})
	if err != nil {
		fatal("Failed to set preuserinfo execution", "error", err)
	}
	slog.Info("Execution set for preuserinfo")
}

func strPtr(s string) *string { return &s }
