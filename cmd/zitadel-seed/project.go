package main

import (
	"log/slog"

	filterv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/filter/v2"
	projectv2 "github.com/zitadel/zitadel-go/v3/pkg/client/zitadel/project/v2"
)

func (s *seeder) setupProject() {
	slog.Info("Setting up project")

	projects, err := s.projects.ListProjects(s.ctx, &projectv2.ListProjectsRequest{
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

	if len(projects.GetProjects()) > 0 {
		s.projectID = projects.GetProjects()[0].GetProjectId()
		slog.Info("Project already exists", "id", s.projectID)
	} else {
		result, err := s.projects.CreateProject(s.ctx, &projectv2.CreateProjectRequest{
			Name:                 "ecommerce",
			ProjectRoleAssertion: true,
		})
		if err != nil {
			fatal("Failed to create project", "error", err)
		}
		s.projectID = result.GetProjectId()
		slog.Info("Created project", "id", s.projectID)
	}

	roles := []struct{ key, display string }{
		{"super_admin", "Super Admin"},
		{"catalog_manager", "Catalog Manager"},
		{"viewer", "Viewer"},
		{"service_account", "Service Account"},
	}
	group := "ecommerce"
	for _, r := range roles {
		//nolint:errcheck // roles are idempotent — duplicates return "already exists"
		s.projects.AddProjectRole(s.ctx, &projectv2.AddProjectRoleRequest{
			ProjectId:   s.projectID,
			RoleKey:     r.key,
			DisplayName: r.display,
			Group:       &group,
		})
	}
	slog.Info("Roles configured")
}
