# VirtualVenues Workspace Notes For Coding Agents

This is the authoritative agent guidance for the VirtualVenues multi-repo
workspace.
If root `AGENTS.md` differs from this document, follow this file.

The workspace root is a container directory and is not a Git repository.
Treat each subfolder as a standalone project with its own README and tooling.
Make changes inside the specific repository you are working on.

## AGENTS Delegate Workflow
- Do not edit workspace-root `AGENTS.md` directly.
- Keep policy changes in this file (`VirtualVenuesHome/AGENTS.md`).
- If delegate wording must change, update managed template content in both
  `VirtualVenuesHome/scripts/init-workspace.sh` and
  `VirtualVenuesHome/scripts/init-workspace.ps1`.
- Regenerate root delegate with `--force-agents`:
  - macOS/Linux: `./VirtualVenuesHome/scripts/init-workspace.sh --force-agents`
  - PowerShell: `.\VirtualVenuesHome\scripts\init-workspace.ps1 --force-agents`

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

## Non-Git Workspace Folders
- `FutureFestWorlds`
- `FutureFestXR`
- `VirtualVenuesWorldCreator`

## Collaboration Rules
- Do not commit or push code changes until the user has reviewed the local diff
  and explicitly approved pushing.
- When updating GitHub issues/PRs, edit or delete prior comments if correction
  is needed; do not post duplicate "formatting correction" follow-up comments.
- When posting multi-line GitHub comments from terminal commands, use
  `--body-file` to avoid shell interpolation issues.
