# grok-build-executor

**Codex (GPT‑5.6 Sol) plans and accepts. Grok 4.5 executes — via documents or a hardened CLI.**

OpenAI Codex multi-agent cannot spawn Grok models. This skill documents two battle-tested bridges:

```text
Mode A (preferred for product work)
  Sol → grok-agent-jobs/.../PROMPT.md
      → human opens in Grok Build (optional 总控 + subagents)
      → RESULT.md on disk
      → Sol re-diff + re-test → merge

Mode B (micro / automated)
  Sol → task card + invoke-grok-executor.ps1
      → grok-4.5 headless (isolated SuperGrok OAuth, allowlists)
      → JSON envelope → Sol verifies
```

Field notes, pitfalls, and anti-patterns: **[docs/COLLABORATION.md](docs/COLLABORATION.md)**  
X drafts: **[docs/X-PROMO.md](docs/X-PROMO.md)**

## Install

```bash
npx skills add Zion74/grok-build-executor -g -y
```

Headless Mode B also needs Grok Build CLI + SuperGrok OAuth into `~/.grok-executor` — see [docs/CODING-AGENT-SETUP.md](docs/CODING-AGENT-SETUP.md) and `scripts/install-executor.ps1`.

## Use in Codex

### Mode A — document handoff (default for real slices)

```text
$grok-build-executor

Create a job under D:\Projects\grok-agent-jobs\<project>\<job-id>\
with PROMPT.md (and MAIN_AGENT_PROMPT.md for me). Exclusive writable files,
forbidden git ops, acceptance commands, RESULT path outside the product repo.
I will ask the human to run PROMPT in Grok Build. When RESULT.md exists I will
re-review the full diff and re-run tests myself—never trust Grok “ok” alone.
```

Templates: `examples/job-folder.template/`.

### Mode B — headless wrapper (small clean worktrees)

```text
$grok-build-executor

Right-sized task card under %USERPROFILE%\.grok-executor\task-cards\.
Split multi-domain research first (references/task-sizing.md).
Invoke with -RequireCleanIsolation; research: -ReadOnly -AllowedCommandPrefix git
-MaxTurns 80 and host timeout >= 300s. Require stopReason=EndTurn.
```

## What failed before (short)

| Approach | Failure |
|---|---|
| Raw `grok -p` / `--yolo` | No ownership; unsafe dirty trees |
| PowerShell `Start-Process` / bad quoting | Args split (`node --test` → `-test`); instant abort |
| One mega headless card | `stopReason: Cancelled`, useless preamble |
| Missing allow prefixes / web | Silent `dontAsk` denials |
| Short Codex `timeout_ms` | Mid-run kill looks like Cancelled |
| Project `.mcp.json` Figma | 30s×N init timeouts |
| Trusting Grok RESULT as done | Missed regressions outside the slice |

Details in [docs/COLLABORATION.md](docs/COLLABORATION.md).

## Repo layout

```text
SKILL.md
agents/openai.yaml
assets/config.toml              # isolated headless home template
scripts/install-executor.ps1
scripts/invoke-grok-executor.ps1
references/task-sizing.md       # split mega headless cards
docs/COLLABORATION.md           # dual-mode + failure log (share this)
docs/CODING-AGENT-SETUP.md
docs/X-PROMO.md
examples/job-folder.template/   # PROMPT + MAIN_AGENT_PROMPT
examples/task-card.template.md  # Mode B cards
examples/AGENTS.md.snippet
```

## Safety

- No secrets in prompts/results committed to product repos
- Exclusive file ownership for parallel Grok writers
- Sol always re-verifies
- MIT licensed; not affiliated with xAI or OpenAI
