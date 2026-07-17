# Headless recipes (Mode B only)

> **Default delivery path remains Mode A** (`.grok_subagent/<task>/PROMPT.md`).  
> These recipes improve tiny headless runs. They are adapted from community `grok-cli` patterns (prompt-file, timeout, JSON, resume, json-schema) **without** adopting headless-as-default or `--always-approve` / yolo.

## 1. Micro-edit via wrapper (preferred for any product file change)

```powershell
# 1) Write a short card under ~/.grok-executor/task-cards/
# 2) Clean worktree only
$skill = "$HOME\.agents\skills\grok-build-executor"
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$skill\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath "$HOME\.grok-executor\task-cards\micro.md" `
  -WorkingDirectory "<clean-repo>" `
  -WritablePath "src/foo/**" `
  -AllowedCommandPrefix "git","npm test --" `
  -RequireCleanIsolation
# Host timeout_ms >= 180000
```

Require `stopReason == EndTurn` and Sol re-verify.

## 2. Evidence / second opinion (no writes)

```powershell
# Via wrapper
... -ReadOnly -AllowedCommandPrefix git -MaxTurns 40 -RequireCleanIsolation

# Or pure Q&A (no tools) — still not for multi-file product delivery
timeout 120 grok --output-format json -p "评审这个思路: ..."
# Label output as Grok's opinion; Sol decides
```

## 3. Structured extract

```powershell
grok --json-schema '{"type":"object","properties":{"risk":{"type":"string"},"score":{"type":"number"}},"required":["risk","score"]}' `
  -p "评估风险" 
# Read .structuredOutput; do not ship code from this alone
```

## 4. Tiny resume (same session)

```powershell
$sid = ... # from previous JSON sessionId after EndTurn
grok --resume $sid --output-format json -p "只补测试名，勿扩 scope"
# Prefer GROK_HOME=~/.grok-executor when using executor isolation
# If scope grows → stop and open Mode A job folder
```

## 5. What we deliberately do **not** copy

| Community pattern | Our rule |
|---|---|
| Default: Claude plans, headless Grok implements everything | **Default Mode A** interactive/document handoff |
| `--always-approve` / `bypassPermissions` for speed | **Forbidden** as convenience; allowlists only |
| Shared `~/.grok` + `~/.claude` for automation | Prefer isolated **`~/.grok-executor`** |
| One long headless run for big features | Split or **Mode A** |

## 6. Failure → escalate to Mode A

If you see `Cancelled`, silent denials, host timeout, or scope creep past ~2 files → **stop stacking headless**. Create `.grok_subagent/<slug>/PROMPT.md` instead.
