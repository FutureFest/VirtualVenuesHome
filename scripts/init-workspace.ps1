#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$vvhRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path

$manifest = Join-Path $vvhRoot "onboarding/repos.github.txt"
$workspaceDir = "."
$nonInteractive = $false
$skipAwsChecks = $false
$skipGhChecks = $false
$forceAgents = $false

$managedAgentsContent = @"
# VirtualVenues Workspace Agent Entry Point

Primary shared agent guidance lives in:

- `VirtualVenuesHome/AGENTS.md`

Treat each subfolder in this workspace as a standalone repository with its own
README and tooling. Make changes inside the specific subfolder you are working
on.
"@

function Show-Usage {
  @"
Usage: init-workspace.ps1 [options]

Options:
  --manifest <path>       Path to repo manifest file
  --workspace-dir <path>  Workspace directory to operate in (default: .)
  --non-interactive       Fail fast instead of attempting interactive login
  --skip-aws-checks       Skip AWS profile preflight checks
  --skip-gh-checks        Skip GitHub auth/repo-access preflight checks
  --force-agents          Overwrite existing AGENTS.md with managed delegate
  -h, --help              Show this help
"@
}

function Write-Info([string]$Message) {
  Write-Host "[INFO] $Message"
}

function Write-WarnLine([string]$Message) {
  Write-Warning $Message
}

function Stop-Fatal([string]$Message) {
  throw $Message
}

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Stop-Fatal "Required command not found: $Name"
  }
}

function Parse-Args {
  param([string[]]$Tokens)

  $i = 0
  while ($i -lt $Tokens.Count) {
    switch ($Tokens[$i]) {
      "--manifest" {
        if ($i + 1 -ge $Tokens.Count) {
          Stop-Fatal "--manifest requires a value"
        }
        $script:manifest = $Tokens[$i + 1]
        $i += 2
      }
      "--workspace-dir" {
        if ($i + 1 -ge $Tokens.Count) {
          Stop-Fatal "--workspace-dir requires a value"
        }
        $script:workspaceDir = $Tokens[$i + 1]
        $i += 2
      }
      "--non-interactive" {
        $script:nonInteractive = $true
        $i += 1
      }
      "--skip-aws-checks" {
        $script:skipAwsChecks = $true
        $i += 1
      }
      "--skip-gh-checks" {
        $script:skipGhChecks = $true
        $i += 1
      }
      "--force-agents" {
        $script:forceAgents = $true
        $i += 1
      }
      "--help" {
        Show-Usage
        exit 0
      }
      "-h" {
        Show-Usage
        exit 0
      }
      default {
        Stop-Fatal "Unknown option: $($Tokens[$i])"
      }
    }
  }
}

function Load-Manifest([string]$ManifestPath) {
  if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Stop-Fatal "Manifest not found: $ManifestPath"
  }

  $repos = @()
  foreach ($raw in Get-Content -LiteralPath $ManifestPath) {
    $line = ($raw -replace "#.*$", "").Trim()
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    if ($line -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
      Stop-Fatal "Invalid manifest entry: $line"
    }
    $repos += $line
  }

  if ($repos.Count -eq 0) {
    Stop-Fatal "Manifest is empty: $ManifestPath"
  }

  return ,$repos
}

function Ensure-AgentsDelegate([string]$WorkspacePath) {
  $agentsPath = Join-Path $WorkspacePath "AGENTS.md"
  if (Test-Path -LiteralPath $agentsPath) {
    $existing = Get-Content -LiteralPath $agentsPath -Raw
    if ($existing -eq $managedAgentsContent) {
      Write-Info "AGENTS delegate already up to date: $agentsPath"
      return
    }

    if ($forceAgents) {
      Set-Content -LiteralPath $agentsPath -Value $managedAgentsContent
      Write-Info "AGENTS delegate overwritten: $agentsPath"
    }
    else {
      Write-WarnLine "AGENTS.md exists and differs from managed delegate: $agentsPath"
      Write-WarnLine "Use --force-agents to overwrite it."
    }
    return
  }

  Set-Content -LiteralPath $agentsPath -Value $managedAgentsContent
  Write-Info "AGENTS delegate created: $agentsPath"
}

function Test-AwsProfile([string]$ProfileName) {
  try {
    & aws sts get-caller-identity --profile $ProfileName *> $null
    Write-Info "AWS profile check passed: $ProfileName"
    return $true
  }
  catch {
    return $false
  }
}

function Run-Preflight([string[]]$Repos) {
  Require-Command "git"
  Require-Command "gh"
  if (-not $skipAwsChecks) {
    Require-Command "aws"
  }

  if (-not $skipGhChecks) {
    try {
      & gh auth status *> $null
    }
    catch {
      Stop-Fatal "GitHub CLI is not authenticated. Run: gh auth login"
    }

    $ghFailures = @()
    foreach ($repo in $Repos) {
      try {
        & gh repo view $repo --json name *> $null
      }
      catch {
        $ghFailures += $repo
      }
    }

    if ($ghFailures.Count -gt 0) {
      $formatted = ($ghFailures | ForEach-Object { "  - $_" }) -join "`n"
      Stop-Fatal "GitHub access check failed for:`n$formatted`nFix access or use --skip-gh-checks."
    }
  }
  else {
    Write-Info "Skipping GitHub preflight checks."
  }

  if (-not $skipAwsChecks) {
    $awsFailures = @()
    foreach ($profile in @("futurefest-mgmt", "futurefest-mgmt-ro")) {
      if (Test-AwsProfile $profile) {
        continue
      }

      if ($nonInteractive) {
        $awsFailures += $profile
        continue
      }

      Write-WarnLine "AWS profile $profile is not authenticated. Attempting aws sso login."
      try {
        & aws sso login --profile $profile
      }
      catch {
      }

      if (-not (Test-AwsProfile $profile)) {
        $awsFailures += $profile
      }
    }

    if ($awsFailures.Count -gt 0) {
      $formatted = ($awsFailures | ForEach-Object { "  - $_" }) -join "`n"
      if ($nonInteractive) {
        Stop-Fatal "AWS profile check failed for:`n$formatted`nAuthenticate first: aws sso login --profile <profile>."
      }
      Stop-Fatal "Unable to authenticate required AWS profiles:`n$formatted"
    }
  }
  else {
    Write-Info "Skipping AWS preflight checks."
  }
}

function Clone-Repos([string]$WorkspacePath, [string[]]$Repos) {
  $cloned = @()
  $skipped = @()
  $failed = @()

  foreach ($repo in $Repos) {
    $targetName = ($repo -split "/")[1]
    $targetPath = Join-Path $WorkspacePath $targetName

    if (Test-Path -LiteralPath $targetPath) {
      $skipped += $repo
      Write-Info "Skipping existing repo directory: $targetName"
      continue
    }

    Push-Location $WorkspacePath
    try {
      & gh repo clone $repo $targetName
      $cloned += $repo
      Write-Info "Cloned $repo -> $targetName"
    }
    catch {
      $failed += $repo
      Write-WarnLine "Failed to clone $repo"
    }
    finally {
      Pop-Location
    }
  }

  Write-Info "Summary:"
  Write-Info "  Cloned:  $($cloned.Count)"
  Write-Info "  Skipped: $($skipped.Count)"
  Write-Info "  Failed:  $($failed.Count)"

  if ($failed.Count -gt 0) {
    $formatted = ($failed | ForEach-Object { "  - $_" }) -join "`n"
    Stop-Fatal "Clone failures:`n$formatted"
  }
}

Parse-Args -Tokens $args

if (-not (Test-Path -LiteralPath $workspaceDir)) {
  New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null
}

$workspacePath = (Resolve-Path -LiteralPath $workspaceDir).Path
$manifestPath = (Resolve-Path -LiteralPath $manifest).Path

$repos = Load-Manifest -ManifestPath $manifestPath
Run-Preflight -Repos $repos
Ensure-AgentsDelegate -WorkspacePath $workspacePath
Clone-Repos -WorkspacePath $workspacePath -Repos $repos
