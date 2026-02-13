# Prerequisites

This guide standardizes local setup so scripts and runbooks work consistently
across contributors.

## Access requirements

- You must be in the `FutureFest` GitHub organization with access to the
  required repositories.
- You must have AWS access for FutureFest with SSO roles:
  - `AdministratorAccess` (write profile)
  - `ReadOnlyAccess` (read-only profile)
- You must have access to the FutureFest Unity Version Control organization and
  the required Unity repositories (if you need Unity source checkout).

## Required tools

- Git
- GitHub CLI (`gh`)
- AWS CLI v2 (`aws`)
- Unity Version Control CLI (`cm`) for Unity source checkout

## Install on macOS (Homebrew)

```bash
brew install git gh awscli
```

Install the Unity Version Control desktop client (includes `cm`) from Unity
Version Control downloads, then ensure `cm` is on your `PATH`.

## Install on Windows (winget)

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id Amazon.AWSCLI -e
```

Install the Unity Version Control desktop client (includes `cm`) from Unity
Version Control downloads.

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

## Unity Version Control authentication

If you need Unity source code in the workspace, configure and verify UVCS CLI.

Verify CLI availability:

```bash
cm version
```

Verify connection and identity:

```bash
cm checkconnection
cm whoami
```

If connection/auth is not configured yet, run the Unity Version Control client
configuration flow and sign in with your Unity credentials.
