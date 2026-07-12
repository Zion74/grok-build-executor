---
name: grok-build-executor
description: Execute a user-approved, bounded software task card with the official Grok Build CLI (Grok 4.5) over SuperGrok OAuth. Use when Codex / GPT-5.6 should delegate implementation to Grok as an external executor; also use to install, smoke-test, or diagnose the local Grok executor integration.
---

# Grok Build Executor

Treat **Grok 4.5** as an external executor, never as the delivery orchestrator. Keep planning, acceptance, integration, and completion authority with the calling agent (typically Codex **`gpt-5.6-sol`**).

Codex native `spawn_agent` / multi-agent **cannot** select Grok models. Always use this skill + the official Grok Build headless CLI. Do not pretend Grok is a native Codex subagent.

## First-time setup (coding agents)

If the user asks to install or configure this skill, follow `docs/CODING-AGENT-SETUP.md` and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "<this-skill>/scripts/install-executor.ps1"
```

Human must complete SuperGrok OAuth once:

```powershell
$env:GROK_HOME = "$HOME\.grok-executor"
grok login
```

## Gate the delegation

Do not invoke the executor until every condition is true:

1. The user approved this exact Grok task, model, scope, and evidence contract.
2. The task card is self-contained (not the parent transcript).
3. Working directory is a **clean** isolated Git worktree owned by the same Windows user as the executor OAuth session.
4. Writable paths and allowed command prefixes are explicit.
5. Until concurrency is forward-tested, run only **one** Grok executor process.

## Runtime layout

| Path | Purpose |
|---|---|
| `~/.grok-executor` | Isolated `GROK_HOME` (OAuth + executor config) |
| `~/.grok-executor/task-cards/` | **Only** place for task card files |
| `~/.grok` | Interactive Grok (leave alone) |
| `scripts/invoke-grok-executor.ps1` | Safe headless wrapper |

Confirm readiness:

```powershell
$env:GROK_HOME = "$HOME\.grok-executor"
grok models   # must list grok-4.5
```

## Execute one task card

```powershell
$card = "$HOME\.grok-executor\task-cards\$(Get-Date -Format 'yyyyMMdd-HHmmss')-task.md"
# write approved task card to $card, then:

$skill = "$HOME\.agents\skills\grok-build-executor"  # or project install path
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$skill\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath $card `
  -WorkingDirectory "<clean-isolated-worktree>" `
  -WritablePath "src/feature/**" `
  -AllowedCommandPrefix "npm test --" `
  -RequireCleanIsolation
```

- Evidence-only: `-ReadOnly` (no writable paths).
- Web: `-AllowWebSearch` only when the task card names an external evidence gap.
- Diagnostics only: `-AllowExternalTaskCard`.

### Wrapper guarantees

- Model fixed to **`grok-4.5`**
- `--no-subagents --no-memory --no-plan`
- `dontAsk` + edit/shell allowlists + destructive denials
- Isolated OS profile (shadow `HOME`/`USERPROFILE`) so personal `~/.agents` skills are not inherited
- Clean worktree required; post-run scope check + `git diff --check`
- Structured JSON envelope on stdout (no Grok reasoning field)

### What Codex receives

Stdout JSON (also logged under `~/.grok-executor/logs/executor/`):

| Field | Meaning |
|---|---|
| `ok` | Wrapper success (exit 0 + EndTurn + no scope violations + diff check) |
| `stopReason` | Should be `EndTurn` |
| `model` | `grok-4.5` |
| `text` | Grok natural-language summary (**lead, not evidence**) |
| `changedFiles` | Relative paths touched |
| `scopeViolations` | Paths outside allowlist |
| `resultLog` / `stderrLog` | On-disk logs |

After success, the orchestrator **must** independently `git diff` and re-run the acceptance command.

## Windows / Codex sandbox notes

Codex host sandbox (`elevated` etc.) only needs to allow running the wrapper + network for OAuth/API. **Blast radius control is the wrapper**, not `--yolo`.

## Claude residue warning

Grok may still read real-user `~/.claude/settings*.json` via the Windows profile path even when `HOME` is shadowed. If Claude is unused, archive `~/.claude` (see setup doc). `PowerShell(...)` permission rules from Claude settings produce harmless skip warnings.

## Safety non-negotiables

- Never print `auth.json`
- Never use `--yolo` / `bypassPermissions` as a shortcut
- Never write task cards into product repos
- Max one concurrent Grok executor until tested
- Count Grok toward the first-round max of three child tasks
