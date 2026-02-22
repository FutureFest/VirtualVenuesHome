# Platform Target And Migration Plan

Last updated: 2026-02-21
Purpose: desired FutureFest platform state and migration path.

## Executive Summary
- This document is a migration brief for FutureFest platform/environment architecture.
- Core context: development currently runs against a production-like environment, creating delivery and operational risk.
- This document is intentionally structured in three sections so readers can move from facts to direction to execution:
  - **Section 1 (As-Is):** where the platform stands today, including current deployment/account realities.
  - **Section 2 (To-Be):** the intended target operating model and deployment/auth strategy.
  - **Section 3 (Migration Work):** the phased actions required to move from current state to target state.

### Working definitions (for this document)
- `ff-web-app` (also referenced as `ff-web`) is the legacy FutureFest web app and is out of scope for this migration wave.
- `vv-web-app` is the current VirtualVenues web app and is in scope for this migration wave.
- `prod` refers to the legacy FutureFest production runtime.
- `fractal-testing` started as testing/staging and is currently operating as the primary production-like runtime for VV operations, including external client work (Intersect).

## Problem Statement
- Development work is currently happening against an environment that is effectively production in day-to-day use.
- That production-like environment originated from what was previously a testing/staging environment.
- Resulting risk:
  - A breaking change during development/testing can impact production users.
  - Production-critical activity can block or slow down development/testing work.
- The current model creates operational coupling between product development and live operations, which this migration plan is intended to remove.

## 1) How Things Currently Are (As-Is)

### Runtime/account shape
- Current setup is mixed across management and non-management accounts.
- Fractal testing is currently acting as production in practice.
- Aurora Dev was created for safer/destructive testing and is disposable.

### Current environment usage snapshot
- `fractal-testing`:
  - Originally used as staging.
  - Currently used as the primary production-like environment in day-to-day operations.
  - This became especially important during partner work (Intersect).
- `prod`:
  - Legacy/older FutureFest production environment.
  - Currently not the actively used primary runtime for current VV operations.
- Other environments currently present (usage varies by team/workstream):
  - `aurora-dev`:
    - Personal development environment for Jimmy.
    - Recently created for safer/destructive testing.
    - Expected to be decommissioned.
  - `amoeba-dev`:
    - Personal development environment for Jimmy.
    - Similar role to `aurora-dev`.
    - Expected to be decommissioned.
  - `microscope-dev`:
    - Personal development environment for Jimmy.
    - Similar role to `aurora-dev`.
    - Expected to be decommissioned.
  - `crystal-testing`:
    - Owner: Steven.
    - Purpose is currently unknown.
  - `crystal-staging`:
    - Owner: Steven.
    - Purpose is currently unknown.
  - `unite`:
    - Owner: Steven.
    - Purpose is currently unknown.

### Backend provisioning and deployment
- FFAPI backend infrastructure is managed with Terraform.
- Amplify is used for web app delivery.
- Amplify app/branch/domain resources are currently mostly console-managed rather than Terraform-managed.
- This creates drift risk between Terraform-defined intent and Amplify console settings.

### Identity/authentication
- FFAPI is Auth0-centric today.
- Auth0 tenant/environment setup is currently a manual bottleneck for creating new envs.

### Detailed resource inventory
- Detailed AWS/ASEC-A resource inventories are maintained in:
  - `AWS_AND_ASEC_A_RESOURCE_INVENTORY.md` (companion inventory document; location may vary by distribution channel)
- This includes:
  - AWS Organizations account/OU snapshot
  - Auth0 tenant inventory
  - DynamoDB/S3/API Gateway/SNS inventories
  - Amplify app + branch/domain mappings
  - environment-to-resource mapping table
  - noted outliers

## 2) How Things Should Be (To-Be)

### Target platform model
- Keep three repos in this migration wave:
  - `ff-api`
  - `vv-web-app`
  - `vv-admin-app`
- This migration wave covers `ff-api`, `vv-web-app`, and `vv-admin-app`; legacy `ff-web-app` is excluded.
- Use Amplify Gen 2 branch-based environments for fast non-prod bring-up.
- Keep Terraform as the infrastructure control plane, including Amplify app/branch/domain resources.
- Use one dedicated non-prod runtime account and one dedicated prod runtime account.
- Keep management account as control-plane/admin only.
- Dedicated non-prod account usage depends on AWS account verification readiness, including ability to provision required S3 buckets.
- Until verification clears, temporary hosting remains in `sandbox-jimmy-sambuo`.

### Target environment model
- Non-prod long-lived environments:
  - `shared-dev`
  - `jimmy-dev`
  - `steven-dev`
  - `nebula-testing`
- Branch naming convention across all three repos:
  - `env/shared-dev`
  - `env/jimmy-dev`
  - `env/steven-dev`
  - `env/nebula-testing`
- Prod:
  - `prod` in separate account with tighter IAM/release controls.

### Non-prod data stability policy
- Tier A (high-churn dev): `shared-dev`, `jimmy-dev`, and `steven-dev` are intentionally disposable and may be reset, refreshed, or deleted at any time.
- Tier B (lower-churn pre-release validation): `nebula-testing` is long-lived for promotion validation, and resets are expected to be less frequent and announced when possible.
- `nebula-testing` remains non-prod and recreatable; no persistence guarantees equivalent to prod should be assumed.
- Any persistent/critical data expectations should remain limited to controlled prod workflows.

### Target routing and domain model
- Frontend domains per environment:
  - VV Web: `web.<env>.virtualvenues.io`
  - VV Admin: `admin.<env>.virtualvenues.io`
- FFAPI endpoint in first wave:
  - Use environment-specific API Gateway execute-api URLs.
  - Publish the URL via Amplify outputs for per-branch frontend wiring.
- API Gateway custom domains are intentionally deferred to a later hardening phase.

### Target deployment policy
- Existing Amplify apps and their current production-like branch mappings remain unchanged in this migration.
- New parallel Amplify apps are created for non-prod and watch only `env/*` branches.
- Applies to parallel non-prod apps for:
  - `ff-api`
  - `vv-web-app`
  - `vv-admin-app`
- Non-prod promotion model within `env/*` branches:
  - `env/shared-dev` is the shared integration branch
  - explicit promotion -> `env/nebula-testing`
  - personal branches (`env/jimmy-dev`, `env/steven-dev`) remain isolated and disposable

### Target authentication model
- FFAPI supports multiple providers via OIDC/JWT abstraction layer.
- Providers:
  - Auth0
  - Cognito
- Migrate non-prod to Cognito first.
- Keep Auth0 available during transition and for rollback.

## 3) What We Need To Do To Get There (Migration Work)

### Phase 0: FFAPI pilot (manual, throwaway)
- Manually create only the `ff-api` Amplify Gen 2 app in the temporary non-prod host account.
- Deploy only `env/shared-dev` as a vertical-slice pilot.
- Keep Auth0 and API Gateway behavior unchanged in this pilot.
- Confirm pilot success criteria:
  - initial deploy succeeds,
  - redeploy/update succeeds,
  - backend endpoint is usable from outputs,
  - health/smoke checks pass.
- Capture exact manual setup inputs so they can be codified in Terraform later.

### Phase 0.2: auth evaluation spike (time-boxed)
- Run a focused evaluation spike for FFAPI OIDC abstraction and Cognito fit.
- Produce a short decision note:
  - implementation effort estimate,
  - migration risks,
  - recommended cutover sequence,
  - rollback approach.
- Decision gate:
  - Phase 1 must not begin unless Phase 0.2 confirms a viable "zero-working" auth path for non-prod.
  - If Cognito/OIDC is not viable, pause migration after Phase 0.2, document blockers/deferral rationale, and re-plan before any Terraform codification phase.

### Phase 1: codify pilot and bootstrap Amplify control plane with Terraform
- Recreate pilot resources cleanly via Terraform (do not rely on pilot resources long-term).
- Add Terraform resources/modules to manage Amplify app control plane:
  - `aws_amplify_app`
  - `aws_amplify_branch`
  - `aws_amplify_domain_association`
- Provision three Amplify apps (one per repo):
  - `ff-api` (backend-only Gen 2 app)
  - `vv-web-app`
  - `vv-admin-app`
- Configure branch pattern `env/*` and register long-lived env branches.
- Configure frontend custom domains for each environment.
- Configure Terraform-managed GitHub connection using a managed token secret source.
- Do not register `main` on new non-prod apps.
- Keep original Amplify apps as-is with no branch remapping.

### Phase 2: scale branch wiring and frontend/backend parity
- In frontend builds, fetch backend outputs for the matching branch:
  - `npx ampx generate outputs --branch $AWS_BRANCH --app-id <BACKEND_APP_ID>`
- Replace manual backend URL wiring with generated outputs consumption.
- Validate each frontend env branch points to its matching FFAPI env branch.
- Keep API Gateway path in front of FFAPI for this wave (no function URL migration yet).

### Phase 3: parallel non-prod operations and guardrails
- Run new non-prod apps in parallel while original Amplify apps remain untouched.
- Enforce branch guardrails for `env/*` promotion flow:
  - `env/shared-dev` -> `env/nebula-testing`
  - no automatic coupling to existing `main` production-like mappings
- Add release/process checks to avoid accidental changes to original Amplify app configuration.

### Phase 4: deferred decommission and cleanup
- Decommission disposable personal environments after new flow is stable:
  - `aurora-dev`
  - `amoeba-dev`
  - `microscope-dev`
- No export/snapshot and no data retention is required for these environments.
- Optional cleanup candidates (pending Steven's feedback/approval):
  - `crystal-testing`
  - `crystal-staging`
  - `unite`

### Immediate execution backlog
- Create migration epic with child tasks:
  - FFAPI manual pilot and decision checklist
  - auth evaluation spike (Phase 0.2), decision note, and implementation/cutover work
  - Terraform Amplify control-plane module work
  - FFAPI Amplify Gen 2 backend app bootstrap
  - frontend outputs-based API wiring
  - parallel non-prod app guardrails (original Amplify apps untouched)
  - deferred decommission actions
- Create implementation RFC/runbook for:
  - branch naming lifecycle (`env/*`)
  - environment ownership and lifecycle
  - rollback sequence (Cognito <-> Auth0 in non-prod)

### Open questions to resolve
- Verification clearance criteria and timing for dedicated non-prod account cutover from temporary `sandbox-jimmy-sambuo` hosting.
- Exact cutover path from execute-api URLs to API custom domains.
