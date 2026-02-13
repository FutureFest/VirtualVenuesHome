# Init Workspace

This guide describes how to bootstrap a VirtualVenues multi-repo workspace
using the scripts in `VirtualVenuesHome/scripts`.

## Default behavior

Both scripts:

- Run against the current directory by default (`--workspace-dir .`)
- Read repos from `onboarding/repos.github.txt`
- Clone missing repositories with `gh repo clone`
- Skip repositories that already exist locally
- Ensure root `AGENTS.md` is the managed delegate file
- Run strict preflight checks by default for:
  - required tools
  - GitHub auth/access
  - AWS profile auth (`futurefest-mgmt`, `futurefest-mgmt-ro`)

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
- `--workspace-dir <path>`: target workspace directory (default: `.`)
- `--non-interactive`: do not prompt or attempt interactive re-login
- `--skip-aws-checks`: skip AWS profile preflight checks
- `--skip-gh-checks`: skip GitHub auth/repo access preflight checks
- `--force-agents`: overwrite existing root `AGENTS.md` with managed delegate
- `--help`: print usage

## Examples

### Run non-interactive for agents

```bash
./VirtualVenuesHome/scripts/init-workspace.sh \
  --workspace-dir . \
  --manifest ./VirtualVenuesHome/onboarding/repos.github.txt \
  --non-interactive
```

```powershell
.\VirtualVenuesHome\scripts\init-workspace.ps1 `
  --workspace-dir . `
  --manifest .\VirtualVenuesHome\onboarding\repos.github.txt `
  --non-interactive
```

### Force AGENTS delegate rewrite

```bash
./VirtualVenuesHome/scripts/init-workspace.sh --force-agents
```

```powershell
.\VirtualVenuesHome\scripts\init-workspace.ps1 --force-agents
```
