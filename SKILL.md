---
name: grok-build-executor
description: Execute a user-approved, bounded software task card with the official Grok Build CLI (Grok 4.5) over SuperGrok OAuth. Use when Codex / GPT-5.6 should delegate implementation or scoped research to Grok as an external executor; also when sizing or splitting large Grok work to avoid Cancelled runs; also to install, smoke-test, or diagnose the local Grok executor integration.
---

# Grok Build Executor

Treat **Grok 4.5** as an external executor, never as the delivery orchestrator. Keep planning, task sizing, acceptance, integration, and completion authority with the calling agent (typically Codex **`gpt-5.6-sol`**).

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
2. The task card is **right-sized** (see [Task sizing](#task-sizing-split-large-work-before-invoke)) and self-contained (not the parent transcript).
3. Working directory is a **clean** isolated Git worktree owned by the same Windows user as the executor OAuth session.
4. Writable paths and/or allowed command prefixes match what the card actually needs.
5. Until concurrency is forward-tested, run only **one** Grok executor process.

If any condition is false, fix the card or return to the orchestrator workflow; do not weaken the wrapper.

## Task sizing: split large work before invoke

**One headless run is a bounded worker, not a full research program.**

Forward-tested pattern:

| Shape | Typical outcome |
|---|---|
| Monolithic "survey whole agent stack + all bugs + target arch + migration" | Often `stopReason: Cancelled` with only a short preamble; `ok: false` |
| Several **evidence-domain** cards (topology / one bug family / target seams / external-doc fit) | Often `EndTurn` with usable multi-KB `text` |

### Must split when

- Many subsystems must be traced in one go
- Deliverable is multi-chapter (status + root causes + target design + roadmap)
- Card needs both deep local evidence **and** official external docs
- Acceptance cannot be stated as one cheap command or a short checklist
- Expected tool-heavy runtime is clearly longer than a few minutes

### Orchestrator procedure

1. Freeze baseline SHA + clean worktree once.
2. Partition by **non-overlapping evidence domains** (paths + questions), not by report headings alone.
3. Write one task card per domain under `~/.grok-executor/task-cards/`.
4. Invoke **serially** (mutex) unless concurrency is later proven.
5. On each result: require `ok: true` and `stopReason: EndTurn`; keep logs.
6. **Synthesize** across cards yourself; never ask Grok to "remember" prior runs.
7. On `Cancelled`: **do not** blind-retry the same card—narrow, re-flag tools, raise `-MaxTurns`, or split further.

Load the full playbook, presets, and failure signatures from:

**`references/task-sizing.md`**

### Research / architecture invoke preset

```powershell
$skill = "$HOME\.agents\skills\grok-build-executor"
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$skill\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath "$HOME\.grok-executor\task-cards\<card>.md" `
  -WorkingDirectory "<clean-isolated-worktree>" `
  -ReadOnly `
  -AllowedCommandPrefix "git" `
  -MaxTurns 80 `
  -RequireCleanIsolation
# -AllowWebSearch only if the card names external evidence gaps
```

Host orchestrator shell **`timeout_ms` should be ≥ 300000** (prefer 600000) for research cards. A 60–120s host timeout will look like random `Cancelled` failures.

## Runtime layout

| Path | Purpose |
|---|---|
| `~/.grok-executor` | Isolated `GROK_HOME` (OAuth + executor config) |
| `~/.grok-executor/task-cards/` | **Only** place for task card files |
| `~/.grok` | Interactive Grok (leave alone) |
| `scripts/invoke-grok-executor.ps1` | Safe headless wrapper |
| `references/task-sizing.md` | Split / sizing detail |

Confirm readiness:

```powershell
$env:GROK_HOME = "$HOME\.grok-executor"
grok models   # must list grok-4.5
```

## Execute one task card

```powershell
$card = "$HOME\.grok-executor\task-cards\$(Get-Date -Format 'yyyyMMdd-HHmmss')-task.md"
# write approved task card to $card, then:

$skill = "$HOME\.agents\skills\grok-build-executor"
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$skill\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath $card `
  -WorkingDirectory "<clean-isolated-worktree>" `
  -WritablePath "src/feature/**" `
  -AllowedCommandPrefix "npm test --" `
  -RequireCleanIsolation
```

| Flag | When |
|---|---|
| `-ReadOnly` | Evidence-only; no writable paths |
| `-AllowedCommandPrefix` | Any shell need (`git`, `node --test`, …). Read-only default is **Read+Grep only** |
| `-AllowWebSearch` | Card names an external evidence gap |
| `-MaxTurns N` | Default 40; use **60–80** for research cards |
| `-RequireCleanIsolation` | Prefer on; fail if personal skill/claude sources leak |
| `-AllowExternalTaskCard` | Diagnostics only |

### Wrapper guarantees

- Model fixed to **`grok-4.5`**
- `--no-subagents --no-memory --no-plan`
- `dontAsk` + edit/shell allowlists + destructive denials
- Isolated OS profile (shadow `HOME`/`USERPROFILE`) so personal `~/.agents` skills are not inherited
- Clean worktree required; post-run scope check + `git diff --check`
- Structured JSON envelope on stdout (no Grok reasoning field)

### What the orchestrator receives

Stdout JSON (also under `~/.grok-executor/logs/executor/`):

| Field | Meaning |
|---|---|
| `ok` | Wrapper success (`EndTurn` + scope + diff check) |
| `stopReason` | Must be **`EndTurn`**. **`Cancelled` = failure** even if `exitCode` is 0 |
| `model` | `grok-4.5` |
| `text` | Narrative report (**lead, not evidence**) |
| `changedFiles` | Paths touched |
| `scopeViolations` | Outside allowlist |
| `resultLog` / `stderrLog` | On-disk logs |

After success, the orchestrator **must** independently `git diff` / re-read cited paths and re-run acceptance commands.

## Diagnose `Cancelled` and other failures

| Observation | Action |
|---|---|
| `stopReason: Cancelled`, short preamble | Card too large or tools denied → split / fix allows / raise `-MaxTurns` + host timeout |
| Cancels ~1–2 min with almost no progress | Raise orchestrator `timeout_ms`; ensure research preset |
| Needs `git`/`tests` but no prefix | Add `-AllowedCommandPrefix` |
| Needs official docs but no web | Add `-AllowWebSearch` **or** remove that requirement from the card |
| Same card cancelled twice | Stop retrying; split or hand back to orchestrator |

Preserve worktree and logs; do not silently retry identical cards.

## Windows / Codex sandbox notes

Codex host sandbox only needs to run the wrapper + network for OAuth/API. **Blast radius control is the wrapper**, not `--yolo`.

- Prefer dedicated worktree roots under a bridge workspace (e.g. project `grok-codex-bridge/worktrees`), not a dirty main tree.
- Worktree owner must match the OAuth Windows user.
- Long research invokes need a **long host shell timeout**, not only higher `-MaxTurns`.

## Claude residue warning

Grok may still read real-user `~/.claude/settings*.json` via the Windows profile path even when `HOME` is shadowed. If Claude is unused, archive `~/.claude`. `PowerShell(...)` rules produce skip warnings only.

## Safety non-negotiables

- Never print `auth.json` or tokens
- Never use `--yolo` / `bypassPermissions` as a shortcut
- Never write task cards into product repos
- Never ship a multi-domain mega-card when split criteria match
- Max one concurrent Grok executor until concurrency is forward-tested
- Count each Grok invoke toward the first-round max of three child tasks
- Grok `text` is never final acceptance by itself
