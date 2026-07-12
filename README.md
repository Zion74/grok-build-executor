# grok-build-executor

**Let Codex (GPT‑5.6 Sol) orchestrate. Let Grok 4.5 execute — safely.**

OpenAI Codex multi-agent cannot spawn Grok models. This skill bridges them with the **official Grok Build headless CLI** + SuperGrok OAuth, behind a hard allowlist wrapper.

```text
You → Codex gpt-5.6-sol → task card → invoke-grok-executor.ps1
     → grok -p (grok-4.5, dontAsk, scoped) → JSON envelope → Sol verifies
```

## Install (humans)

### 1. Install the skill

```bash
npx skills add Zion74/grok-build-executor -g -y
```

Or:

```bash
npx skills add https://github.com/Zion74/grok-build-executor -g -y
```

### 2. Install Grok Build CLI

Follow [xAI / Grok Build docs](https://docs.x.ai/). You need the `grok` binary on PATH (Windows: typically `%USERPROFILE%\.grok\bin\grok.exe`).

### 3. One-shot executor setup

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$HOME\.agents\skills\grok-build-executor\scripts\install-executor.ps1"
```

### 4. SuperGrok OAuth (human browser)

```powershell
$env:GROK_HOME = "$HOME\.grok-executor"
grok login
grok models   # must show grok-4.5
```

> Interactive Grok stays in `~/.grok`. The executor uses a **separate** home: `~/.grok-executor`.

## Install (coding agents)

Paste this into Codex / Claude Code / Cursor:

```text
Install and configure https://github.com/Zion74/grok-build-executor
Follow docs/CODING-AGENT-SETUP.md exactly.
Run scripts/install-executor.ps1.
Stop for human OAuth when asked.
Never print or commit credentials / auth files.
Then show me a minimal smoke plan.
```

Full playbook: [`docs/CODING-AGENT-SETUP.md`](docs/CODING-AGENT-SETUP.md)

## Use in Codex

```text
$grok-build-executor

Write a self-contained, right-sized task card under %USERPROFILE%\.grok-executor\task-cards\.
If the work is multi-domain research/architecture, split into evidence cards first
(see references/task-sizing.md). Show cards for confirmation, then invoke with
-RequireCleanIsolation (research: -ReadOnly -AllowedCommandPrefix git -MaxTurns 80,
host timeout >= 300s). After JSON returns, require stopReason=EndTurn; git diff +
re-run acceptance yourself. Never treat Cancelled + short preamble as success.
```

Or with routing:

```text
$agentic-delivery
# when a slice is Grok-shaped, delegate via $grok-build-executor
```

### Invoke shape

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$HOME\.agents\skills\grok-build-executor\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath "$HOME\.grok-executor\task-cards\my-task.md" `
  -WorkingDirectory "D:\path\to\clean-worktree" `
  -WritablePath "src/feature/**" `
  -AllowedCommandPrefix "npm test --" `
  -RequireCleanIsolation
```

## What comes back

Stdout JSON envelope (example fields):

```json
{
  "ok": true,
  "stopReason": "EndTurn",
  "model": "grok-4.5",
  "text": "…natural language summary…",
  "changedFiles": ["src/foo.ts"],
  "scopeViolations": [],
  "resultLog": "…/.grok-executor/logs/executor/….result.json"
}
```

- **`text`** = lead, not evidence  
- **Truth** = git diff in the worktree + orchestrator-run tests  

## Safety model

| Control | Default |
|---|---|
| Model | `grok-4.5` only |
| Nested Grok subagents | off |
| Memory / plan mode | off |
| Web search | off unless opt-in |
| Permission mode | `dontAsk` + explicit `--allow` |
| Task cards | only under `~/.grok-executor/task-cards/` |
| Concurrency | single process mutex |
| Implicit skill fire | disabled (`allow_implicit_invocation: false`) |

## Repo layout

```text
SKILL.md                      # agent skill entry
agents/openai.yaml            # Codex UI metadata
assets/config.toml            # isolated executor config template
scripts/install-executor.ps1  # first-time setup
scripts/invoke-grok-executor.ps1
docs/CODING-AGENT-SETUP.md
docs/ARCHITECTURE.md
examples/task-card.template.md
examples/AGENTS.md.snippet
```

## Requirements

- Windows (primary; PowerShell wrapper)
- [Grok Build CLI](https://docs.x.ai/) + SuperGrok-capable account
- Codex CLI / ChatGPT Codex (or any agent that can run shell + skills)
- Git

## License

MIT — see [LICENSE](LICENSE)

## Disclaimer

Not affiliated with xAI or OpenAI. You are responsible for OAuth credentials, code changes Grok makes, and review gates. The wrapper reduces blast radius; it does not remove the need for human judgment on merges.
