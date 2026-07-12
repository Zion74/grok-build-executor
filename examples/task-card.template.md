# Task card template

## Goal
<one sentence: what changes by the end>

## Scope / ownership
- Writable paths: `<relative/glob/**>`
- Do NOT modify: `<paths>`
- Do NOT create files outside writable paths
- Do NOT git commit / push / reset --hard / clean

## Required sources
- `<path or symbol>`
- `<path or symbol>`

## Work
1. Read required sources.
2. Implement the change.
3. Run the acceptance command.
4. Stop when green.

## Acceptance command
```
<exact command that must exit 0>
```

## Done when
1. Acceptance command exits 0
2. Only allowed paths changed
3. Final line: `TASK_OK` or `TASK_FAIL`

## Non-goals
- No drive-by refactors
- No dependency installs unless explicitly allowed
- No web search unless this card names an external evidence gap
