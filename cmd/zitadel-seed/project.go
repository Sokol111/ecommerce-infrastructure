package main

import (
	"log/slog"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	filterv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/filter/v2"
	projectv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/project/v2"
)

func (s *seeder) setupProject() {
	slog.Info("Setting up project")

	projects, err := s.client.ProjectServiceV2().ListProjects(s.ctx, &projectv2.ListProjectsRequest{
		Filters: []*projectv2.ProjectSearchFilter{{
			Filter: &projectv2.ProjectSearchFilter_ProjectNameFilter{
				ProjectNameFilter: &projectv2.ProjectNameFilter{
					ProjectName: "ecommerce",
					Method:      filterv2.TextFilterMethod_TEXT_FILTER_METHOD_EQUALS,
				},
			},
		}},
	})
	if err != nil {
		fatal("Failed to list projects", "error", err)
	}

	if len(projects.GetProjects()) > 1 {
		fatal("Multiple projects named 'ecommerce' found", "count", len(projects.GetProjects()))
	}

	if len(projects.GetProjects()) == 1 {
		s.projectID = projects.GetProjects()[0].GetProjectId()
		slog.Info("Project already exists", "id", s.projectID)
	} else {
		req := &projectv2.CreateProjectRequest{
			OrganizationId:       s.orgID,
			Name:                 "ecommerce",
			ProjectRoleAssertion: true,
		}
		result, err := s.client.ProjectServiceV2().CreateProject(s.ctx, req)
		if err != nil {
			fatal("Failed to create project", "error", err)
		}
		s.projectID = result.GetProjectId()
		slog.Info("Created project", "id", s.projectID)
	}
	s.secrets.set("project-id", s.projectID)

	roles := []struct{ key, display string }{
		{"super_admin", "Super Admin"},
		{"catalog_manager", "Catalog Manager"},
		{"viewer", "Viewer"},
		{"service_account", "Service Account"},
	}
	group := "ecommerce"
	for _, r := range roles {
		_, err := s.client.ProjectServiceV2().AddProjectRole(s.ctx, &projectv2.AddProjectRoleRequest{
			ProjectId:   s.projectID,
			RoleKey:     r.key,
			DisplayName: r.display,
			Group:       &group,
		})
		if err != nil {
			if status.Code(err) == codes.AlreadyExists {
				continue
			}
			fatal("Failed to add project role", "role", r.key, "error", err)
		}
	}
	slog.Info("Roles configured")
}
