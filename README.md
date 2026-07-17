# grok-build-executor

**Codex (GPT‑5.6 Sol) plans and accepts. Grok 4.5 executes — default via `PROMPT.md`, not headless.**

OpenAI Codex multi-agent cannot spawn Grok models. This skill documents the battle-tested bridge:

```text
Mode A — DEFAULT (stable, better quality)
  Sol → <product>/.grok_subagent/<YYYYMMDD-HHMM-slug>/PROMPT.md
      → human opens in Grok Build (optional 总控 + subagents)
      → RESULT.md + follow-ups in the same folder
      → Sol re-diff + re-test → merge
  (.grok_subagent/ must be gitignored)

Mode B — EXCEPTION only (very small tasks)
  Sol → task card + invoke-grok-executor.ps1
      → grok-4.5 headless (isolated SuperGrok OAuth, allowlists)
      → JSON envelope → Sol verifies
  Use only for: executor smoke, one-liner / ≤~2 files on a clean git tree, tiny peek.
  Clean product repo is enough — independent worktree is optional (only if main is dirty).
  When in doubt → Mode A. Do not default to headless.
```

**Workspace:** Mode A runs on the **product tree** (dirty OK with exclusive ownership). Independent `git worktree` is optional, not required.  
**Permissions:** Mode A is not default-read-only — give write globs + read-only git + acceptance commands; forbid reset/clean/push/secrets.  
**Mode B extras (borrowed, still exception-only):** prompt-as-file, host timeout, JSON lead + Sol verify, optional resume/json-schema for tiny peeks — see `references/headless-recipes.md`. Never headless-as-default or yolo.

**Why default PROMPT.md:** headless hits PowerShell quoting bugs, `stopReason: Cancelled` on non-tiny cards, host timeouts, silent `dontAsk` denials, and project MCP drag. Interactive Grok + job files is more stable and more effective.

Field notes, pitfalls, and anti-patterns: **[docs/COLLABORATION.md](docs/COLLABORATION.md)**  
X drafts: **[docs/X-PROMO.md](docs/X-PROMO.md)**

## Install

```bash
npx skills add Zion74/grok-build-executor -g -y
```

Headless Mode B (rarely needed) also needs Grok Build CLI + SuperGrok OAuth into `~/.grok-executor` — see [docs/CODING-AGENT-SETUP.md](docs/CODING-AGENT-SETUP.md) and `scripts/install-executor.ps1`.

## Use in Codex

### Mode A — document handoff (**always prefer this**)

```text
$grok-build-executor

Create a job under <product-repo>/.grok_subagent/<YYYYMMDD-HHMM-slug>/
with PROMPT.md (RESULT.md + optional MAIN_AGENT_* / reviews in the same folder).
Ensure .grok_subagent/ is gitignored. Product code changes stay in normal paths.
Permission pack: directory writable globs, read-only git, acceptance commands;
forbid reset/clean/commit/push/secrets.
No independent worktree unless isolation is truly needed.
I will say whether this is a NEW .grok_subagent job or REUSE of an existing slug,
and when the human may close the Grok window (after RESULT is on disk / after accept).
I will ask the human to run PROMPT in Grok Build. When RESULT.md exists I will
re-review the full product diff and re-run tests myself—never trust Grok “ok” alone.
```

Templates: `examples/job-folder.template/`.

### Mode B — headless (**very small only**)

```text
$grok-build-executor

Only if the task is truly tiny (smoke / one-liner / ≤~2 files).
WorkingDirectory = clean product repo OR temp worktree if main is dirty.
Presets: evidence (-ReadOnly + git) or micro-edit (WritablePath + git + tests).
Otherwise write PROMPT.md instead.
Task card under %USERPROFILE%\.grok-executor\task-cards\.
Invoke with -RequireCleanIsolation. Require stopReason=EndTurn.
```

## What failed before (short)

| Approach | Failure |
|---|---|
| Raw `grok -p` / `--yolo` | No ownership; unsafe dirty trees |
| PowerShell `Start-Process` / bad quoting | Args split (`node --test` → `-test`); instant abort |
| One mega headless card | `stopReason: Cancelled`, useless preamble |
| Defaulting to headless for product work | Fragile vs PROMPT.md |
| Missing allow prefixes / web | Silent `dontAsk` denials |
| Read-only Mode A / no git/tests | Grok cannot finish; quality tanks |
| Forced worktree for every job | Merge tax with no safety gain |
| Short Codex `timeout_ms` | Mid-run kill looks like Cancelled |
| Project `.mcp.json` Figma | 30s×N init timeouts |
| Trusting Grok RESULT as done | Missed regressions outside the slice |

Details in [docs/COLLABORATION.md](docs/COLLABORATION.md).

## Repo layout

```text
SKILL.md
agents/openai.yaml
assets/config.toml              # isolated headless home template (Mode B only)
scripts/install-executor.ps1
scripts/invoke-grok-executor.ps1
references/task-sizing.md       # if you still use headless, keep cards tiny / split
docs/COLLABORATION.md           # dual-mode + failure log (share this)
docs/CODING-AGENT-SETUP.md
docs/X-PROMO.md
examples/job-folder.template/   # PROMPT + MAIN_AGENT_PROMPT (Mode A default)
examples/task-card.template.md  # Mode B only
references/headless-recipes.md  # tiny headless recipes (not default path)
examples/AGENTS.md.snippet
```

## Safety

- No secrets in prompts/results committed to product repos
- Exclusive file ownership for parallel Grok writers
- Sol always re-verifies
- **Default Mode A; Mode B only for very small tasks**
- MIT licensed; not affiliated with xAI or OpenAI
