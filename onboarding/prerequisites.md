# Prerequisites

This guide standardizes local setup so scripts and runbooks work consistently
across contributors.

## Access requirements

- You must be in the `FutureFest` GitHub organization with access to the
  required repositories.
- You must have AWS access for FutureFest with SSO roles:
  - `AdministratorAccess` (write profile)
  - `ReadOnlyAccess` (read-only profile)

## Required tools

- Git
- GitHub CLI (`gh`)
- AWS CLI v2 (`aws`)

## Install on macOS (Homebrew)

```bash
brew install git gh awscli
```

## Install on Windows (winget)

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id Amazon.AWSCLI -e
```

## GitHub authentication

Authenticate with GitHub CLI:

```bash
gh auth login
```

Verify auth:

```bash
gh auth status
```

Verify org/repo access:

```bash
gh repo view FutureFest/VirtualVenuesHome --json name,url
```

## AWS profile standard

Use these exact profile names:

- `futurefest-mgmt` -> `AdministratorAccess`
- `futurefest-mgmt-ro` -> `ReadOnlyAccess`

Do not rely on the `default` profile for FutureFest workflows.

### Configure write profile

```bash
aws configure sso --profile futurefest-mgmt
```

### Configure read-only profile

```bash
aws configure sso --profile futurefest-mgmt-ro
```

### Login and verify both profiles

```bash
aws sso login --profile futurefest-mgmt
aws sts get-caller-identity --profile futurefest-mgmt

aws sso login --profile futurefest-mgmt-ro
aws sts get-caller-identity --profile futurefest-mgmt-ro
```
