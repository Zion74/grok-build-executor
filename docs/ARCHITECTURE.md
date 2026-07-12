# Architecture

## Problem

Codex multi-agent can only spawn OpenAI Codex models. Grok 4.5 lives in the **Grok Build** CLI with SuperGrok OAuth. Teams want:

- GPT‑5.6 Sol (or similar) as **orchestrator**
- Grok 4.5 as **bounded executor**
- Clear evidence handoff, not prompt soup

## Solution

A Skill + PowerShell wrapper around official headless Grok:

```text
Orchestrator agent (Codex)
  writes task card → ~/.grok-executor/task-cards/
  prepares clean git worktree
  runs invoke-grok-executor.ps1
        │
        ▼
  GROK_HOME=~/.grok-executor
  grok -p <task> --model grok-4.5 --output-format json
       --no-subagents --no-memory --no-plan
       --permission-mode dontAsk
       --allow Edit(**/scope) Bash(prefix*)
        │
        ▼
  JSON envelope on stdout
  file changes only in worktree
        │
        ▼
Orchestrator verifies diff + acceptance command
```

## Trust boundaries

| Boundary | Mechanism |
|---|---|
| Auth isolation | Separate `GROK_HOME` from interactive `~/.grok` |
| Skill isolation | Shadow process `HOME`/`USERPROFILE` for Grok child |
| Write scope | Relative path allowlist + post-hoc `changedFiles` check |
| Shell scope | Command prefix allowlist + destructive denials |
| Fan-out | `--no-subagents` + process mutex |
| Context | Task card only (no parent transcript dump) |

## Return contract

Orchestrator consumes **stdout JSON**, not Grok reasoning traces.

Critical fields: `ok`, `stopReason`, `model`, `text`, `changedFiles`, `scopeViolations`, `resultLog`.

`text` is a narrative lead. Ground truth is the worktree + re-run tests.

## Non-goals

- Replacing Codex native multi-agent for OpenAI models
- Hosting Grok as an MCP server (possible later; not required)
- Multi-tenant cloud runner
- Automatic merge/push
