# Coding-agent setup playbook

Instructions for **Codex / Claude Code / Cursor / other coding agents** installing this skill for a human user.

## Hard rules

1. **Never** print, log, commit, or paste `auth.json`, API keys, OAuth tokens, cookies, or chat transcripts that contain secrets.
2. **Never** copy credentials from the user's interactive Grok home into the repo or into chat.
3. Prefer the **official Grok Build CLI** + SuperGrok OAuth. Do not invent third-party proxy endpoints unless the user explicitly asks.
4. Primary platform today: **Windows + PowerShell**. Say so if the host is macOS/Linux (wrapper is PowerShell-first).
5. Stop and ask the human when a **browser OAuth login** is required.

## Goal state

| Item | Expected |
|---|---|
| Skill files | Available as `$grok-build-executor` (user or project skills dir) |
| Grok CLI | `grok` on PATH or under `~/.grok/bin/` |
| Executor home | `~/.grok-executor/` with `config.toml` |
| OAuth | `~/.grok-executor/auth.json` exists (do not open it) |
| Models | `GROK_HOME=~/.grok-executor grok models` lists `grok-4.5` |
| Task cards dir | `~/.grok-executor/task-cards/` |
| Codex guidance | `~/.codex/AGENTS.md` contains the grok-build-executor snippet (optional but recommended) |

## Steps

### 1. Install skill package

```bash
npx skills add Zion74/grok-build-executor -g -y
```

If `npx skills` is unavailable, clone or copy this repository to:

```text
~/.agents/skills/grok-build-executor/
```

Preserve: `SKILL.md`, `scripts/`, `assets/`, `agents/`, `examples/`.

### 2. Ensure Grok Build CLI

```powershell
Get-Command grok -ErrorAction SilentlyContinue
# or
Test-Path "$HOME\.grok\bin\grok.exe"
```

If missing, point the user to official install docs: https://docs.x.ai/  
Do not download random third-party binaries.

### 3. Run installer

```powershell
$skill = "$HOME\.agents\skills\grok-build-executor"
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\install-executor.ps1"
```

If OAuth is not ready yet:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$skill\scripts\install-executor.ps1" -SkipLoginCheck
```

### 4. Human OAuth (blocking)

Tell the user to run locally:

```powershell
$env:GROK_HOME = "$HOME\.grok-executor"
grok login
grok models
```

Resume only after `grok-4.5` appears. **Do not** request their password or paste tokens.

### 5. Optional isolation hygiene

If Grok stderr shows Claude `settings.local.json` noise and the user no longer uses Claude Code, suggest archiving `~/.claude` (reversible rename). Do not delete without confirmation.

### 6. Smoke test plan (after OAuth)

1. Create a disposable clean git repo or worktree.
2. Write a **read-only** task card under `~/.grok-executor/task-cards/`.
3. Invoke `scripts/invoke-grok-executor.ps1` with `-ReadOnly -RequireCleanIsolation`.
4. Confirm JSON: `ok=true`, `model=grok-4.5`, `stopReason=EndTurn`.
5. For write smoke: broken unit → allow one file → acceptance command green → independent re-verify.

### 7. Report back to the user

Return a short checklist:

- skill path
- `GROK_HOME`
- models line showing `grok-4.5` (no secrets)
- how to invoke `$grok-build-executor` in Codex
- any remaining human steps

## Failure handling

| Symptom | Action |
|---|---|
| `auth.json` missing | Stop for human `grok login` with `GROK_HOME` |
| `grok-4.5` missing | Subscription / model availability; do not swap models silently |
| Task card path rejected | Must live under `~/.grok-executor/task-cards/` |
| Scope violations | Tighten task card / writable globs; do not widen to `**` casually |
| Mutex busy | Another executor is running; wait |

## What not to configure

- Do not set wrapper to `--yolo` / `bypassPermissions`
- Do not commit `~/.grok-executor` into projects
- Do not put task cards inside product repositories
- Do not enable Grok nested subagents for this executor profile
