---
name: grok-build-executor
description: Coordinate GPT/Codex with Grok 4.5 as an external executor—prefer document handoff (PROMPT/RESULT job folders + interactive Grok or Grok 总控 agent); optionally use the headless SuperGrok CLI wrapper for small clean-worktree cards. Use when delegating implementation or research to Grok, sizing/splitting work to avoid Cancelled runs, recovering from CLI/PowerShell failures, or installing and diagnosing the local executor.
---

# Grok Build Executor

Treat **Grok 4.5** as an **executor**, not the delivery owner. The calling agent (typically Codex **`gpt-5.6-sol`**) keeps planning, risk calls, merge/complete authority, and **independent verification**.

Codex native multi-agent **cannot** select Grok models. Integration is always external:

| Mode | Mechanism | Prefer when |
|---|---|---|
| **A. Document handoff** | Job folder `PROMPT.md` → human opens in **Grok Build UI** (optional Grok 总控 + subagents) → `RESULT.md` → Sol re-verifies | Real product slices, dirty trees, multi-file ownership, long builds, parallel Grok subagents |
| **B. Headless CLI** | `invoke-grok-executor.ps1` + task card under `~/.grok-executor/task-cards/` | Micro edits / smoke / narrow read-only evidence on a **clean** worktree |

**Field default for product work: Mode A.** Mode B remains for automation and isolation-hardened micro jobs.

Full narrative + failure history for GitHub/X: **`docs/COLLABORATION.md`**.

---

## Mode A — Document handoff (preferred)

### Layout

```text
grok-agent-jobs/<project>/<job-id>/
  PROMPT.md                 # Grok executes this
  RESULT.md                 # Grok writes this
  MAIN_AGENT_PROMPT.md      # optional: Sol post-review checklist
  PROMPT-01.md / RESULT-01.md   # optional exclusive sub-slices
```

Templates: `examples/job-folder.template/`.

Practice root example:

```text
D:\Projects\grok-agent-jobs\<project>\<YYYYMMDD-HHMM-slug>\
```

Never store job notes inside the product git tree.

### Orchestrator (Sol) steps

1. Create the job folder; write `PROMPT.md` with **exclusive writable paths**, forbidden ops, acceptance commands, and exact `RESULT.md` path.
2. For multi-slice work, either:
   - multiple job folders, or
   - one **orchestrator** `PROMPT.md` that points at child `PROMPT-0N.md` files with **non-overlapping** ownership and a parent `RESULT.md`.
3. Ask the human to start Grok Build on `PROMPT.md` (paste or open file). Do **not** block forever—if RESULT never appears, offer to implement yourself.
4. When the human reports done (or RESULT mtime updates), read `RESULT.md` as **untrusted**.
5. Personally review full scoped diff; re-run every acceptance command; only then accept.
6. Grok UI windows may be closed once RESULT + code are on disk.

### Grok 总控 pattern

When one interactive Grok coordinates several subagents:

- Preflight each child: if `RESULT-0N.md` exists → validate only; if sources dirty without RESULT → treat in-flight, **do not** spawn a second writer.
- Exclusive ownership sets must not overlap.
- Parent writes aggregate `RESULT.md` with status matrix + command logs.
- Sol still re-verifies; never trust Grok “ok” alone.

### Gate for Mode A

1. User approved the job boundary (or standing authority for this goal).
2. `PROMPT.md` is complete and right-sized (split multi-domain work across jobs/children).
3. Product dirty tree is acknowledged; unrelated changes must be preserved.
4. RESULT path is outside product repo.

---

## Mode B — Headless CLI wrapper

Use only after Mode A is a poor fit (unattended micro card, isolation smoke).

### Setup

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "<this-skill>/scripts/install-executor.ps1"
# human: GROK_HOME=~/.grok-executor ; grok login
```

### Task cards

```text
~/.grok-executor/task-cards/<run-id>.md
```

Right-size before invoke—mega research cards often end as `stopReason: Cancelled`. Details: **`references/task-sizing.md`**.

### Invoke

```powershell
$skill = "$HOME\.agents\skills\grok-build-executor"
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$skill\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath "$HOME\.grok-executor\task-cards\<card>.md" `
  -WorkingDirectory "<clean-isolated-worktree>" `
  -WritablePath "src/feature/**" `
  -AllowedCommandPrefix "npm test --" `
  -RequireCleanIsolation
```

| Flag | When |
|---|---|
| `-ReadOnly` | Evidence-only |
| `-AllowedCommandPrefix` | Any shell (`git`, tests). Default allow is **Read+Grep only** |
| `-AllowWebSearch` | Card names external evidence |
| `-MaxTurns N` | Default 40; research often **60–80** |
| `-RequireCleanIsolation` | Prefer on |

Research preset: `-ReadOnly -AllowedCommandPrefix git -MaxTurns 80` and host **`timeout_ms` ≥ 300000**.

### Success envelope

`ok: true` requires `stopReason == EndTurn` (not `Cancelled`), no scope violations, diff check clean. JSON `text` is a lead only.

---

## Choosing mode (quick)

| Job | Mode |
|---|---|
| Multi-file product fix, dirty tree, ownership across modules | **A** |
| Grok 总控 + 2–3 writer subagents | **A** |
| Docker/long build inside Grok | **A** |
| Clean worktree one-liner / smoke / tiny read-only card | **B** |
| Unattended CI-style micro task with SuperGrok OAuth | **B** (tight allowlists) |

---

## Failure lessons (summary)

Publishable detail: **`docs/COLLABORATION.md`**.

1. **PowerShell / `grok.exe` quoting** — `Start-Process` and bad splits turn `node --test` into fake `-test` params; prefer Mode A or a single carefully quoted wrapper call.
2. **Headless mega-cards** — full-stack surveys → frequent `Cancelled` + short preamble; split evidence domains.
3. **`dontAsk` without tool prefixes** — silent deny loops.
4. **Host shell timeouts** — 60–120s kills real work mid-run.
5. **Project `.mcp.json` (e.g. Figma)** — still loaded when Claude/Cursor MCP compat is off; strip unused servers.
6. **Skill catalog miss** — files exist but `$skill` not listed; use explicit paths / restart.
7. **Policy** — Codex may be blocked from shipping private source into external headless automation; human-started Grok already on disk is cleaner.
8. **Duplicate writers** — always exclusive file sets + RESULT preflight.
9. **Trust** — slice green ≠ product green; Sol re-runs expanded suites.

---

## Safety non-negotiables

- Never print `auth.json`, API keys, or tokens
- Never `--yolo` / `bypassPermissions` as convenience
- Never put job PROMPT/RESULT into product git
- Never overlapping writable ownership across parallel Grok writers
- Never treat Grok RESULT/`text` as final acceptance
- Prefer Mode A for product delivery; use Mode B only when its constraints fit
