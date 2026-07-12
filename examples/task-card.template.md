# Task card template

> Sizing: one card = one evidence domain. If this needs multi-chapter architecture + all root causes + migration, **split** first (`references/task-sizing.md`).

## Goal
<one sentence: what changes or which evidence is produced>

## Baseline
- Commit SHA: `<frozen sha>`
- Worktree: clean isolated clone/worktree only

## Scope / ownership
- Mode: edit | read-only
- Writable paths (edit only): `<relative/glob/**>`
- Readable focus paths: `<dirs/files>`
- Do NOT modify: `<paths>`
- Do NOT create files outside writable paths
- Do NOT git commit / push / reset --hard / clean

## Required sources
- `<path or symbol>`
- `<path or symbol>`

## Tool needs (must match invoke flags)
- Shell prefixes required: `<none | git | node --test | …>`
- Web search: `<no | yes — list allowed doc hosts>`

## Work
1. Read required sources (small targeted reads).
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
- No web search unless listed under Tool needs
- No covering other evidence domains (those are other cards)
