# Init Workspace

This guide describes how to bootstrap a VirtualVenues multi-repo workspace
using the scripts in `VirtualVenuesHome/scripts`.

## Default behavior

Both scripts:

- Run against the current directory by default (`--workspace-dir .`)
- Read repos from `onboarding/repos.github.txt`
- Read optional Unity repos from `onboarding/repos.uvcs.txt`
- Clone missing repositories with `gh repo clone`
- Create missing UVCS workspaces with `cm workspace create`
- Skip repositories that already exist locally
- Ensure root `AGENTS.md` is the managed delegate file
- Run strict preflight checks by default for:
  - required tools
  - GitHub auth/access
  - AWS profile auth (`futurefest-mgmt`, `futurefest-mgmt-ro`)
  - Unity Version Control auth (`cm checkconnection`, `cm whoami`) when UVCS
    manifest entries exist

## Run on macOS/Linux

```bash
./VirtualVenuesHome/scripts/init-workspace.sh
```

## Run on Windows PowerShell

```powershell
.\VirtualVenuesHome\scripts\init-workspace.ps1
```

## CLI flags

- `--manifest <path>`: override repo manifest file
- `--uvcs-manifest <path>`: override UVCS manifest file
- `--workspace-dir <path>`: target workspace directory (default: `.`)
- `--non-interactive`: do not prompt or attempt interactive re-login
- `--skip-aws-checks`: skip AWS profile preflight checks
- `--skip-gh-checks`: skip GitHub auth/repo access preflight checks
- `--skip-uvcs-checks`: skip UVCS auth preflight checks
- `--force-agents`: overwrite existing root `AGENTS.md` with managed delegate
- `--help`: print usage

## Examples

### Run non-interactive for agents

```bash
./VirtualVenuesHome/scripts/init-workspace.sh \
  --workspace-dir . \
  --manifest ./VirtualVenuesHome/onboarding/repos.github.txt \
  --uvcs-manifest ./VirtualVenuesHome/onboarding/repos.uvcs.txt \
  --non-interactive
```

```powershell
.\VirtualVenuesHome\scripts\init-workspace.ps1 `
  --workspace-dir . `
  --manifest .\VirtualVenuesHome\onboarding\repos.github.txt `
  --uvcs-manifest .\VirtualVenuesHome\onboarding\repos.uvcs.txt `
  --non-interactive
```

### Force AGENTS delegate rewrite

```bash
./VirtualVenuesHome/scripts/init-workspace.sh --force-agents
```

```powershell
.\VirtualVenuesHome\scripts\init-workspace.ps1 --force-agents
```

## UVCS manifest format

The UVCS manifest is optional and line-based. Use one entry per line:

```text
workspace_name|relative_or_absolute_target_path|repository_spec
```

Rules:

- `#` starts a comment.
- Blank lines are ignored.
- Target paths are resolved relative to workspace root unless absolute.
- If the target path already exists, the workspace is skipped.

## After bootstrap

After repos are synced locally, use the shared project board for task
selection and status tracking:

- [Beam Backlog Work Tracking](work-tracking.md)
