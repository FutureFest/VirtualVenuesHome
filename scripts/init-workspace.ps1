#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$vvhRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path

$manifest = Join-Path $vvhRoot "onboarding/repos.github.txt"
$uvcsManifest = Join-Path $vvhRoot "onboarding/repos.uvcs.txt"
$workspaceDir = "."
$nonInteractive = $false
$skipAwsChecks = $false
$skipGhChecks = $false
$skipUvcsChecks = $false
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
  --uvcs-manifest <path>  Path to UVCS manifest file
  --workspace-dir <path>  Workspace directory to operate in (default: .)
  --non-interactive       Fail fast instead of attempting interactive login
  --skip-aws-checks       Skip AWS profile preflight checks
  --skip-gh-checks        Skip GitHub auth/repo-access preflight checks
  --skip-uvcs-checks      Skip UVCS auth preflight checks
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
      "--uvcs-manifest" {
        if ($i + 1 -ge $Tokens.Count) {
          Stop-Fatal "--uvcs-manifest requires a value"
        }
        $script:uvcsManifest = $Tokens[$i + 1]
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
      "--skip-uvcs-checks" {
        $script:skipUvcsChecks = $true
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

function Load-UvcsManifest([string]$ManifestPath) {
  if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Stop-Fatal "UVCS manifest not found: $ManifestPath"
  }

  $entries = @()
  foreach ($raw in Get-Content -LiteralPath $ManifestPath) {
    $line = ($raw -replace "#.*$", "").Trim()
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }

    $parts = $line -split "\|", 3
    if ($parts.Count -lt 3) {
      Stop-Fatal "Invalid UVCS manifest entry: $line"
    }

    $workspaceName = $parts[0].Trim()
    $targetPath = $parts[1].Trim()
    $repositorySpec = $parts[2].Trim()

    if ([string]::IsNullOrWhiteSpace($workspaceName) -or
        [string]::IsNullOrWhiteSpace($targetPath) -or
        [string]::IsNullOrWhiteSpace($repositorySpec)) {
      Stop-Fatal "Invalid UVCS manifest entry: $line"
    }

    $entries += [PSCustomObject]@{
      WorkspaceName = $workspaceName
      TargetPath = $targetPath
      RepositorySpec = $repositorySpec
    }
  }

  return ,$entries
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

function Test-UvcsAccess {
  param([string[]]$RepositorySpecs)

  $seenServers = @{}
  foreach ($repoSpec in $RepositorySpecs) {
    $parts = $repoSpec -split "@", 2
    if ($parts.Count -lt 2) {
      return $false
    }
    $repServer = $parts[1]
    if ([string]::IsNullOrWhiteSpace($repServer)) {
      return $false
    }

    if ($seenServers.ContainsKey($repServer)) {
      continue
    }
    $seenServers[$repServer] = $true

    try {
      & cm checkconnection $repServer *> $null
    }
    catch {
      return $false
    }
  }

  try {
    & cm whoami *> $null
    return $true
  }
  catch {
    return $false
  }
}

function Run-Preflight([string[]]$Repos, $UvcsEntries) {
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

  if ($UvcsEntries.Count -gt 0) {
    Require-Command "cm"
    $uvcsRepositorySpecs = @($UvcsEntries | ForEach-Object { $_.RepositorySpec })
    if (-not $skipUvcsChecks) {
      if (-not (Test-UvcsAccess -RepositorySpecs $uvcsRepositorySpecs)) {
        Stop-Fatal "UVCS check failed. Configure Unity Version Control client and authenticate, then retry."
      }
      Write-Info "UVCS preflight checks passed."
    }
    else {
      Write-Info "Skipping UVCS preflight checks."
    }
  }
  else {
    Write-Info "No UVCS manifest entries found; skipping UVCS bootstrap."
  }
}

function Clone-GithubRepos([string]$WorkspacePath, [string[]]$Repos) {
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

  return [PSCustomObject]@{
    Cloned = $cloned
    Skipped = $skipped
    Failed = $failed
  }
}

function Resolve-RepoTarget([string]$WorkspacePath, [string]$InputPath) {
  if ([System.IO.Path]::IsPathRooted($InputPath)) {
    return $InputPath
  }
  return Join-Path $WorkspacePath $InputPath
}

function Init-UvcsWorkspaces([string]$WorkspacePath, $UvcsEntries) {
  $created = @()
  $skipped = @()
  $failed = @()

  foreach ($entry in $UvcsEntries) {
    $targetPath = Resolve-RepoTarget -WorkspacePath $WorkspacePath -InputPath $entry.TargetPath

    if (Test-Path -LiteralPath $targetPath) {
      $skipped += $entry.WorkspaceName
      Write-Info "Skipping existing UVCS target: $targetPath"
      continue
    }

    $parentPath = Split-Path -Parent $targetPath
    if (-not [string]::IsNullOrWhiteSpace($parentPath) -and -not (Test-Path -LiteralPath $parentPath)) {
      New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }

    try {
      & cm workspace create $entry.WorkspaceName $targetPath $entry.RepositorySpec *> $null
      Push-Location $targetPath
      try {
        & cm update *> $null
      }
      finally {
        Pop-Location
      }
      $created += $entry.WorkspaceName
      Write-Info "Created UVCS workspace $($entry.WorkspaceName) at $targetPath"
    }
    catch {
      $failed += $entry.WorkspaceName
      Write-WarnLine "Failed to create or update UVCS workspace $($entry.WorkspaceName)"
    }
  }

  return [PSCustomObject]@{
    Created = $created
    Skipped = $skipped
    Failed = $failed
  }
}

Parse-Args -Tokens $args

if (-not (Test-Path -LiteralPath $workspaceDir)) {
  New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null
}

$workspacePath = (Resolve-Path -LiteralPath $workspaceDir).Path
$manifestPath = (Resolve-Path -LiteralPath $manifest).Path
$uvcsManifestPath = (Resolve-Path -LiteralPath $uvcsManifest).Path

$repos = Load-Manifest -ManifestPath $manifestPath
$uvcsEntries = Load-UvcsManifest -ManifestPath $uvcsManifestPath
Run-Preflight -Repos $repos -UvcsEntries $uvcsEntries
Ensure-AgentsDelegate -WorkspacePath $workspacePath

$ghResults = Clone-GithubRepos -WorkspacePath $workspacePath -Repos $repos
$uvcsResults = Init-UvcsWorkspaces -WorkspacePath $workspacePath -UvcsEntries $uvcsEntries

Write-Info "Summary:"
Write-Info "  GitHub cloned:  $($ghResults.Cloned.Count)"
Write-Info "  GitHub skipped: $($ghResults.Skipped.Count)"
Write-Info "  GitHub failed:  $($ghResults.Failed.Count)"
Write-Info "  UVCS created:   $($uvcsResults.Created.Count)"
Write-Info "  UVCS skipped:   $($uvcsResults.Skipped.Count)"
Write-Info "  UVCS failed:    $($uvcsResults.Failed.Count)"

if ($ghResults.Failed.Count -gt 0 -or $uvcsResults.Failed.Count -gt 0) {
  if ($ghResults.Failed.Count -gt 0) {
    $ghFailed = ($ghResults.Failed | ForEach-Object { "  - $_" }) -join "`n"
    Write-Error "GitHub clone failures:`n$ghFailed"
  }
  if ($uvcsResults.Failed.Count -gt 0) {
    $uvcsFailed = ($uvcsResults.Failed | ForEach-Object { "  - $_" }) -join "`n"
    Write-Error "UVCS workspace failures:`n$uvcsFailed"
  }
  exit 1
}
