# Work Tracking

`Beam Backlog` is the shared work tracker across FutureFest repositories.

- Project owner: `FutureFest`
- Project number: `2`
- Project URL: <https://github.com/orgs/FutureFest/projects/2>

Use this as the default planning and execution tracker for cross-repo work.

## Team convention

1. Track all meaningful work in GitHub (issue or draft item).
2. Every active branch/PR should map to a tracked project item.
3. Move status as work progresses (`Backlog` -> `Ready` -> `In progress` ->
   `In review` -> `Done`).
4. Use `Priority` and `Size` so sequencing is explicit.
5. Keep cards linked to the source repo issue/PR whenever possible.

## Setup for CLI access

Read-only access:

```bash
gh auth refresh -h github.com -s read:project
```

Write/update access (add/edit items):

```bash
gh auth refresh -h github.com -s project
```

Verify:

```bash
gh project view 2 --owner FutureFest
```

## Common CLI actions

Open project in browser:

```bash
gh project view 2 --owner FutureFest --web
```

Add an existing issue/PR to Beam Backlog:

```bash
gh project item-add 2 --owner FutureFest --url https://github.com/FutureFest/<repo>/issues/<number>
```

Create a draft item directly in the project:

```bash
gh project item-create 2 --owner FutureFest --title "Title" --body "Details"
```

List items (JSON for filtering/automation):

```bash
gh project item-list 2 --owner FutureFest --format json
```

## Lightweight workflow

1. Pick work from `Ready` (or move selected work to `In progress`).
2. Confirm linked issue exists in the correct repo.
3. Implement and open PR linked to that issue.
4. Move card to `In review` when PR is ready.
5. Move card to `Done` after merge.

## Notes for agents

- Prefer linked issue/PR cards over orphan draft cards.
- If no issue exists for the work, create one first, then add it to the
  project.
- Keep status updates in sync with real code state, not intent.
