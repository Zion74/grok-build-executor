# Task card template (Mode B — very small only)

> Prefer Mode A (`PROMPT.md`) for real work. This card is for smoke / one-liner / tiny peek.
> Sizing: one card = one tiny domain. Multi-chapter work → **Mode A**, not more headless cards.

## Goal
<one sentence: what changes or which evidence is produced>

## Baseline
- Commit SHA: `<frozen sha>`
- Working directory: **any clean git tree**
  - Product repo is fine if `git status` is empty
  - Independent worktree only if main tree is dirty or you want discardable isolation
  - Not required: “always use a separate worktree”

## Scope / ownership
- Preset: `evidence` (read-only) | `micro-edit`
- Writable paths (micro-edit): `<relative/glob/**>` — directory globs OK
- Readable focus: `<dirs/files>` (read can be wider than write)
- Do NOT modify outside writable paths
- Do NOT git commit / push / reset --hard / clean

## Required sources
- `<path or symbol>`

## Tool needs (must match invoke flags)

| Preset | Typical flags |
|---|---|
| evidence | `-ReadOnly -AllowedCommandPrefix git` |
| micro-edit | `-WritablePath '…/**' -AllowedCommandPrefix git,<test prefix>` |

- Shell prefixes required: `<git and/or test command prefix>`
- Web search: `<no | yes>`

## Work
1. Read required sources (targeted).
2. Implement or extract evidence only within scope.
3. Run the acceptance command if any.
4. Stop when Done-when is met — do not expand scope.

## Acceptance command
```
<exact command that must exit 0, or "none — read-only; changedFiles must be empty">
```

## Done when
1. Acceptance command exits 0 (or N/A for pure read-only)
2. Only allowed paths changed (or `changedFiles` empty)
3. Required sections present in the final report
4. Final line: `TASK_OK` or `TASK_FAIL`

## Non-goals
- No drive-by refactors
- No dependency installs unless explicitly allowed
- No covering other domains
- No inventing a worktree when the product tree is already clean
