# Job title

You are the Grok Build executor (or coordinator) for this job.

## Working directories

```text
<absolute path to product repo>
```

Branch (if fixed): `<branch>`

> Default: work **in the product repo** above. Independent `git worktree` only if Sol created one for isolation—then use that absolute path instead.

## Result file

When finished, write the full report to **this job folder** (same directory as this PROMPT):

```text
<product-repo>/.grok_subagent/<YYYYMMDD-HHMM-slug>/RESULT.md
```

- Job notes (PROMPT/RESULT/reviews) stay only under `.grok_subagent/` (gitignored).
- Product code changes go under Writable paths only — not into `.grok_subagent/`.
- Terminal reply: compact JSON pointer to `RESULT.md` only.

## Background and goal

<what and why>

## Permissions (recommended pack)

### Read

- Entire working directory above (and linked packages if needed).

### Writable paths only (prefer directory globs)

```text
src/<feature>/**
tests/<feature>/**
```

### Allowed commands

**Git (read-only — always):**

```text
git status
git diff
git log
git rev-parse
git branch
```

**Acceptance / build (fill in exact commands):**

```powershell
<e.g. npm test -- path/to/suite>
```

### Forbidden (hard)

- Edit files outside the writable list
- `git reset` / `git checkout --` / `git clean` / force branch switch
- commit / push / deploy / merge (unless the human explicitly allows in this prompt)
- secrets, `.env`, credentials
- Expanding scope when blocked—write `RESULT.md` with status `blocked` instead

## Git safety

1. Record branch, HEAD, `git status --short`, and pre-existing diff first.
2. Preserve unrelated dirty files (do not stash/reset them away).
3. You may read widely; write only under Writable paths.

## Work

1. …
2. …
3. RED → GREEN using the acceptance commands where applicable.

## RESULT.md must include

- status: `ok` | `blocked` | `partial`
- changed files (must stay inside writable list)
- design notes / invariants
- exact command results
- blockers
- confirmation that forbidden ops did not run
