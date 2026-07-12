# Job title

You are the Grok Build executor (or coordinator) for this job.

## Working directories

```text
<absolute path to product repo>
```

Branch (if fixed): `<branch>`

## Result file

When finished, write the full report to:

```text
<absolute path>/RESULT.md
```

Do not write job notes into the product repository. Terminal reply: compact JSON pointer to `RESULT.md` only.

## Background and goal

<what and why>

## Writable files only

```text
<path1>
<path2>
```

## Forbidden

- Edit files outside the writable list
- `git reset` / `git checkout --` / `git clean` / force branch switch
- commit / push / deploy / merge (unless the human explicitly allows)
- secrets, `.env`, credentials

## Git safety

1. Record branch, HEAD, `git status --short`, and pre-existing diff first.
2. Preserve unrelated dirty files.
3. Do not expand scope when blocked—write `RESULT.md` with status `blocked` instead.

## Work

1. …
2. …
3. RED → GREEN tests where applicable.

## Acceptance commands

```powershell
<exact commands from product root>
```

## RESULT.md must include

- status: `ok` | `blocked` | `partial`
- changed files
- design notes / invariants
- exact command results
- blockers
- confirmation that forbidden ops did not run
