# VirtualVenues Workspace Notes For Coding Agents

This workspace is a container for multiple repositories. Treat each subfolder
as a standalone project with its own README and tooling. Make changes inside
the specific repository you are working on.

## Repositories
- `VirtualVenuesHome`: Central shared docs/reference repo for cross-project
  architecture, terminology, and standards.
- `ff-api`: Go API service for Future Fest. Local dev uses Docker Compose; see
  `ff-api/README.md`.
- `ff-web-app`: React web app. Local dev uses Docker Compose; see
  `ff-web-app/README.md`.
- `ff-infrastructure`: Terraform code for AWS infra; see
  `ff-infrastructure/README.md` and the `modules/` and `infrastructure/` dirs.
- `vv-admin-app`: Admin console app for VirtualVenues management workflows; see
  `vv-admin-app/README.md`.
- `vv-web-app`: VirtualVenues web app; see `vv-web-app/README.md`.
