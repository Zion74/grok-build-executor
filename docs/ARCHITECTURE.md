# Architecture

## Problem

Codex multi-agent can only spawn OpenAI Codex models. Grok 4.5 lives in **Grok Build** (interactive UI + optional headless CLI with SuperGrok OAuth). Teams want:

- GPT‑5.6 Sol (or similar) as **orchestrator**
- Grok 4.5 as **bounded executor**
- Clear evidence handoff, not prompt soup
- **Stability and quality first** (field default: documents, not shelling headless)

## Solution (two paths)

### Path A — Document handoff (**default**)

```text
Orchestrator agent (Codex / Sol)
  writes job folder → <product>/.grok_subagent/<YYYYMMDD-HHMM-slug>/
    PROMPT.md (+ RESULT, MAIN_AGENT_*, child PROMPTs, reviews)
  ensures .grok_subagent/ is gitignored
        │
        ▼
  Human opens PROMPT in Grok Build UI
  (optional: one Grok 总控 + exclusive-ownership subagents)
  Working dir = product repo by default (dirty OK with ownership)
        │
        ▼
  Grok writes RESULT.md in job folder; code changes under owned paths
        │
        ▼
  Sol re-reads RESULT as untrusted → full product diff → re-run acceptance
```

This is the **stable, preferred** path. Job notes are **local and gitignored** under `.grok_subagent/`; they are not committed product source. **Independent git worktree is optional**. Permission pack: read-wide, write-narrow directory globs, read-only git, acceptance commands; forbid reset/clean/push/secrets.

### Path B — Headless CLI (**very small only**)

A Skill + PowerShell wrapper around official headless Grok — smoke / one-liner / tiny cards on a **clean** git tree:

```text
Orchestrator agent (Codex)
  writes task card → ~/.grok-executor/task-cards/
  chooses clean WorkingDirectory
    (product repo if clean, OR temp worktree if main is dirty)
  runs invoke-grok-executor.ps1
        │
        ▼
  GROK_HOME=~/.grok-executor
  grok -p <task> --model grok-4.5 --output-format json
       --no-subagents --no-memory --no-plan
       --permission-mode dontAsk
       --allow Read Grep [Edit] [Bash prefixes]
        │
        ▼
  JSON envelope on stdout
  file changes only under WritablePath
        │
        ▼
Orchestrator verifies diff + acceptance command
```

Presets: **evidence** (`-ReadOnly` + git) vs **micro-edit** (WritablePath + git + tests).  
When in doubt → Path A (`PROMPT.md`). Do not default to headless or to a new worktree.

## Trust boundaries

### Shared (both modes)

| Boundary | Mechanism |
|---|---|
| Orchestrator owns accept | Sol re-diffs + re-runs tests; Grok narrative is a lead only |
| File ownership | Explicit writable sets; no overlapping parallel writers |
| Workspace | Product tree default; optional worktree only when Sol chooses isolation |
| Permissions | Enough to finish (git read + tests); no yolo / no irreversible git |
| Job artifacts | Product-root `.grok_subagent/<task>/` (**gitignored**); Mode B cards under `~/.grok-executor/task-cards/` |

### Headless-only extras (Mode B)

| Boundary | Mechanism |
|---|---|
| Auth isolation | Separate `GROK_HOME` from interactive `~/.grok` |
| Skill isolation | Shadow process `HOME`/`USERPROFILE` for Grok child |
| Write scope | Relative path allowlist + post-hoc `changedFiles` check |
| Shell scope | Command prefix allowlist + destructive denials |
| Fan-out | `--no-subagents` + process mutex |
| Context | Task card only (no parent transcript dump) |

## Return contract

**Mode A:** `RESULT.md` on disk + product tree diff. Sol never treats RESULT alone as acceptance.

**Mode B:** Orchestrator consumes **stdout JSON**, not Grok reasoning traces. Critical fields: `ok`, `stopReason`, `model`, `text`, `changedFiles`, `scopeViolations`, `resultLog`. `ok` requires `stopReason == EndTurn`.

## Non-goals

- Replacing Codex native multi-agent for OpenAI models
- Hosting Grok as an MCP server (possible later; not required)
- Multi-tenant cloud runner
- Automatic merge/push
- Using headless as the default product delivery path
- Requiring an independent worktree for every Grok job
