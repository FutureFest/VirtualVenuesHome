#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VVH_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MANIFEST="${VVH_ROOT}/onboarding/repos.github.txt"
WORKSPACE_DIR="."
NON_INTERACTIVE=0
SKIP_AWS_CHECKS=0
SKIP_GH_CHECKS=0
FORCE_AGENTS=0

declare -a REPOS=()
declare -a GH_ACCESS_FAILURES=()
declare -a AWS_FAILURES=()
declare -a CLONED_REPOS=()
declare -a SKIPPED_REPOS=()
declare -a FAILED_CLONES=()

MANAGED_AGENTS_CONTENT="# VirtualVenues Workspace Agent Entry Point

Primary shared agent guidance lives in:

- \`VirtualVenuesHome/AGENTS.md\`

Treat each subfolder in this workspace as a standalone repository with its own
README and tooling. Make changes inside the specific subfolder you are working
on.
"

usage() {
  cat <<'EOF'
Usage: init-workspace.sh [options]

Options:
  --manifest <path>       Path to repo manifest file
  --workspace-dir <path>  Workspace directory to operate in (default: .)
  --non-interactive       Fail fast instead of attempting interactive login
  --skip-aws-checks       Skip AWS profile preflight checks
  --skip-gh-checks        Skip GitHub auth/repo-access preflight checks
  --force-agents          Overwrite existing AGENTS.md with managed delegate
  -h, --help              Show this help
EOF
}

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

fatal() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fatal "Required command not found: ${cmd}"
  fi
}

trim_line() {
  local value="$1"
  value="${value%$'\r'}"
  value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  printf '%s' "$value"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --manifest)
        [[ $# -ge 2 ]] || fatal "--manifest requires a value"
        MANIFEST="$2"
        shift 2
        ;;
      --workspace-dir)
        [[ $# -ge 2 ]] || fatal "--workspace-dir requires a value"
        WORKSPACE_DIR="$2"
        shift 2
        ;;
      --non-interactive)
        NON_INTERACTIVE=1
        shift
        ;;
      --skip-aws-checks)
        SKIP_AWS_CHECKS=1
        shift
        ;;
      --skip-gh-checks)
        SKIP_GH_CHECKS=1
        shift
        ;;
      --force-agents)
        FORCE_AGENTS=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fatal "Unknown option: $1"
        ;;
    esac
  done
}

resolve_path() {
  local input="$1"
  if [[ "$input" = /* ]]; then
    printf '%s' "$input"
  else
    printf '%s/%s' "$(pwd)" "$input"
  fi
}

load_manifest() {
  local line cleaned

  [[ -f "$MANIFEST" ]] || fatal "Manifest not found: ${MANIFEST}"

  while IFS= read -r line || [[ -n "$line" ]]; do
    cleaned="${line%%#*}"
    cleaned="$(trim_line "$cleaned")"

    [[ -z "$cleaned" ]] && continue

    if [[ ! "$cleaned" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
      fatal "Invalid manifest entry: ${cleaned}"
    fi

    REPOS+=("$cleaned")
  done < "$MANIFEST"

  if [[ ${#REPOS[@]} -eq 0 ]]; then
    fatal "Manifest is empty: ${MANIFEST}"
  fi
}

ensure_agents_delegate() {
  local workspace_abs="$1"
  local agents_path="${workspace_abs}/AGENTS.md"
  local tmp_file

  tmp_file="$(mktemp)"
  printf '%s' "$MANAGED_AGENTS_CONTENT" > "$tmp_file"

  if [[ -f "$agents_path" ]]; then
    if cmp -s "$tmp_file" "$agents_path"; then
      log "AGENTS delegate already up to date: ${agents_path}"
    elif [[ "$FORCE_AGENTS" -eq 1 ]]; then
      cp "$tmp_file" "$agents_path"
      log "AGENTS delegate overwritten: ${agents_path}"
    else
      warn "AGENTS.md exists and differs from managed delegate: ${agents_path}"
      warn "Use --force-agents to overwrite it."
    fi
  else
    cp "$tmp_file" "$agents_path"
    log "AGENTS delegate created: ${agents_path}"
  fi

  rm -f "$tmp_file"
}

check_gh_access() {
  local repo="$1"
  if ! gh repo view "$repo" --json name >/dev/null 2>&1; then
    GH_ACCESS_FAILURES+=("$repo")
  fi
}

check_aws_profile() {
  local profile="$1"

  if aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
    log "AWS profile check passed: ${profile}"
    return 0
  fi

  if [[ "$NON_INTERACTIVE" -eq 1 || ! -t 0 ]]; then
    AWS_FAILURES+=("$profile")
    return 1
  fi

  warn "AWS profile ${profile} is not authenticated. Attempting aws sso login."
  if aws sso login --profile "$profile"; then
    if aws sts get-caller-identity --profile "$profile" >/dev/null 2>&1; then
      log "AWS profile check passed after login: ${profile}"
      return 0
    fi
  fi

  AWS_FAILURES+=("$profile")
  return 1
}

preflight_checks() {
  require_cmd git
  require_cmd gh

  if [[ "$SKIP_AWS_CHECKS" -eq 0 ]]; then
    require_cmd aws
  fi

  if [[ "$SKIP_GH_CHECKS" -eq 0 ]]; then
    if ! gh auth status >/dev/null 2>&1; then
      fatal "GitHub CLI is not authenticated. Run: gh auth login"
    fi

    for repo in "${REPOS[@]}"; do
      check_gh_access "$repo"
    done

    if [[ ${#GH_ACCESS_FAILURES[@]} -gt 0 ]]; then
      printf '[ERROR] GitHub access check failed for:\n' >&2
      printf '  - %s\n' "${GH_ACCESS_FAILURES[@]}" >&2
      fatal "Fix GitHub org/repo access or use --skip-gh-checks."
    fi
  else
    log "Skipping GitHub preflight checks."
  fi

  if [[ "$SKIP_AWS_CHECKS" -eq 0 ]]; then
    check_aws_profile "futurefest-mgmt" || true
    check_aws_profile "futurefest-mgmt-ro" || true

    if [[ ${#AWS_FAILURES[@]} -gt 0 ]]; then
      printf '[ERROR] AWS profile check failed for:\n' >&2
      printf '  - %s\n' "${AWS_FAILURES[@]}" >&2
      if [[ "$NON_INTERACTIVE" -eq 1 || ! -t 0 ]]; then
        fatal "Authenticate first: aws sso login --profile <profile>, then rerun."
      fi
      fatal "Unable to authenticate required AWS profiles."
    fi
  else
    log "Skipping AWS preflight checks."
  fi
}

clone_repos() {
  local workspace_abs="$1"
  local repo target_name target_path

  for repo in "${REPOS[@]}"; do
    target_name="${repo##*/}"
    target_path="${workspace_abs}/${target_name}"

    if [[ -e "$target_path" ]]; then
      SKIPPED_REPOS+=("$repo")
      log "Skipping existing repo directory: ${target_name}"
      continue
    fi

    if (cd "$workspace_abs" && gh repo clone "$repo" "$target_name"); then
      CLONED_REPOS+=("$repo")
      log "Cloned ${repo} -> ${target_name}"
    else
      FAILED_CLONES+=("$repo")
      warn "Failed to clone ${repo}"
    fi
  done
}

main() {
  local workspace_abs

  parse_args "$@"

  if [[ ! -d "$WORKSPACE_DIR" ]]; then
    mkdir -p "$WORKSPACE_DIR"
  fi

  workspace_abs="$(cd "$WORKSPACE_DIR" && pwd)"
  MANIFEST="$(resolve_path "$MANIFEST")"

  load_manifest
  preflight_checks
  ensure_agents_delegate "$workspace_abs"
  clone_repos "$workspace_abs"

  log "Summary:"
  log "  Cloned:  ${#CLONED_REPOS[@]}"
  log "  Skipped: ${#SKIPPED_REPOS[@]}"
  log "  Failed:  ${#FAILED_CLONES[@]}"

  if [[ ${#FAILED_CLONES[@]} -gt 0 ]]; then
    printf '[ERROR] Clone failures:\n' >&2
    printf '  - %s\n' "${FAILED_CLONES[@]}" >&2
    exit 1
  fi
}

main "$@"
