# Onboarding

This onboarding flow is the canonical setup for both developers and coding
agents working in a VirtualVenues multi-repo workspace.

## What you get

- Standard prerequisites and authentication flow for GitHub and AWS
- A repo manifest that defines which repositories belong in a workspace
- Bootstrap scripts for macOS/Linux (`bash`) and Windows (`PowerShell`)

## Documents

- [Prerequisites](prerequisites.md)
- [Init Workspace](init-workspace.md)
- Repo manifest: [`repos.github.txt`](repos.github.txt)

## Quick start

1. Complete [Prerequisites](prerequisites.md).
2. Open a terminal in your intended workspace container directory.
3. Run one of:
   - macOS/Linux:

     ```bash
     ./VirtualVenuesHome/scripts/init-workspace.sh
     ```

   - Windows PowerShell:

     ```powershell
     .\VirtualVenuesHome\scripts\init-workspace.ps1
     ```

The scripts are idempotent:
- Existing repo directories are skipped.
- Missing repos are cloned.
- Root `AGENTS.md` delegate is created (or warned on conflict).
