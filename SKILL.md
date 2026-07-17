---
name: grok-build-executor
description: Coordinate GPT/Codex with Grok 4.5 as an external executor. Default is document handoff under product-root .grok_subagent/<named-task>/ (PROMPT/RESULT/follow-ups); rules for when to create a new job vs reuse, and when the human may close Grok windows. Independent worktrees optional. Headless CLI only for very small clean-tree tasks.
---

# Grok Build Executor

Treat **Grok 4.5** as an **executor**, not the delivery owner. The calling agent (typically Codex **`gpt-5.6-sol`**) keeps planning, risk calls, merge/complete authority, and **independent verification**.

Codex native multi-agent **cannot** select Grok models. Integration is always external.

## Default rule (non-negotiable)

| Priority | Mode | When |
|---|---|---|
| **Default** | **A — Document handoff (`PROMPT.md`)** | Almost everything: product slices, multi-file edits, research, dirty trees, long builds, Grok 总控 + subagents |
| **Exception only** | **B — Headless CLI** | **Very small** tasks only: smoke, one-liner / ≤ ~2 files on a **clean** git tree, tiny peek |

**When in doubt → Mode A (`PROMPT.md`). Do not reach for headless.**

Field experience: headless is fragile (PowerShell quoting, `Cancelled`, host timeouts, silent `dontAsk` denials). **`PROMPT.md` + interactive Grok is more stable and better quality.**

Full narrative: **`docs/COLLABORATION.md`**.

---

## Workspace policy (worktree is optional)

Do **not** invent an independent worktree by default.

| Concept | Required? | Meaning |
|---|---|---|
| **Mode A on product tree** | **Yes (default)** | Grok works in the real repo with exclusive writable paths; dirty unrelated files must be preserved |
| **Git status clean** | Mode B only | Headless wrapper refuses a dirty tree so post-run `changedFiles` is attributable |
| **Independent `git worktree`** | **Optional** | Use only when the main tree is too dirty for Mode B, for true parallel long forks, or high-risk experiments |
| **`RequireCleanIsolation`** | Mode B hygiene | OAuth/`HOME` isolation (not a git worktree) |

**Decision tree**

```text
Normal product / multi-file / dirty tree
  → Mode A on product repo (no extra worktree)

Tiny headless card and product tree is already clean
  → Mode B with -WorkingDirectory = product repo (or any clean checkout)

Tiny headless but product tree is dirty
  → temporary clean worktree OR skip headless → Mode A

High-risk rewrite / long parallel forks
  → optional independent worktree + Sol-owned merge (see below)
```

### When you do use an independent worktree

Sol owns create/merge/cleanup. Grok does not push.

1. `git worktree add <path> -b gw/job-<id> <base-sha>`
2. Point PROMPT/card `WorkingDirectory` at that path; job notes still under the **product root** `.grok_subagent/<task>/` (or the main product’s `.grok_subagent` if worktree is a side checkout).
3. Grok finishes → Sol verifies **inside the worktree**.
4. Integrate into the main line (prefer order): **cherry-pick / format-patch** → **merge job branch** → file copy only as last resort.
5. Re-run acceptance **on the main line** (slice green ≠ product green).
6. `git worktree remove` + delete local job branch when done.

Never `git reset --hard` the shared main tree to “clean up” after a Grok experiment.

---

## Mode A — Document handoff (default)

### Job folder placement (required)

**Default root:** product repository root → **`.grok_subagent/`**.

One named folder per task (same shape as the former `grok-agent-jobs/...` practice folders):

```text
<product-repo>/
  .grok_subagent/
    <YYYYMMDD-HHMM-slug>/
      PROMPT.md                 # Grok executes this (required)
      RESULT.md                 # Grok writes this (required when done)
      MAIN_AGENT_PROMPT.md      # optional: Sol post-review checklist
      MAIN_AGENT_REVIEW_01.md   # optional: Sol round notes / follow-ups
      PROMPT-01.md / RESULT-01.md   # optional exclusive sub-slices
      RESULT_REVIEW_*.md        # optional review artifacts
  .gitignore                    # must ignore .grok_subagent/
```

**Naming**

- Prefer: `YYYYMMDD-HHMM-<short-kebab-slug>`  
  Example: `20260712-2320-p0-fallback-stream-root-fix`
- One task = one folder; do not dump multiple unrelated jobs into the same folder.
- Multi-slice under one coordinator: same folder with `PROMPT.md` + `PROMPT-0N.md` / `RESULT-0N.md`.

**Git safety (non-negotiable)**

- Job materials live **under the product tree path** for locality, but must **never be committed**.
- On first use in a repo, ensure `.gitignore` contains:

```gitignore
# Grok / Codex document-handoff job folders (PROMPT, RESULT, reviews)
.grok_subagent/
```

- Code changes stay in normal product paths (under writable ownership). Only orchestration notes go in `.grok_subagent/`.
- If `.gitignore` cannot be updated yet, still create the job folder but **warn the user** and do not `git add` it.

**Legacy / fallback:** an external jobs root such as `~/grok-agent-jobs/<project>/<job-id>/` is acceptable only when the product root is unavailable, multi-repo jobs need a neutral host, or the user explicitly asks. Prefer `.grok_subagent/` for new work.

Templates: `examples/job-folder.template/`.

### Job lifecycle — new vs reuse vs close windows

Tell the **human** explicitly at each handoff (do not assume they know).  
Terminology: **job folder** = `.grok_subagent/<slug>/`；**Grok 窗口** = 人打开的 Grok Build 会话（可含总控 + 其子 agent）。

#### When to **create a new** job folder (+ usually a new Grok session)

Create `.grok_subagent/<YYYYMMDD-HHMM-new-slug>/` when **any** of these hold:

| Signal | Why new |
|---|---|
| New goal / new feature slice / new bug | Different acceptance and ownership |
| Writable file sets would **overlap** an in-flight or unfinished job | Avoid dual writers |
| Previous job is **accepted** (or abandoned) and this work is unrelated | Keep history clean |
| Previous `RESULT` is final for that slug; this is a **new** scope even if same area | Don’t rewrite history of a closed job without intent |
| Parallel work with non-overlapping ownership that you want separate RESULT trails | One folder per parallel track (or one 总控 folder with child PROMPTs—see below) |

Default posture for a **fresh user request**: **new folder + ask human to open PROMPT in a new (or idle) Grok session**.

#### When to **reuse** the same job folder (and often the same Grok session)

Stay in the existing `.grok_subagent/<slug>/` when:

| Signal | How |
|---|---|
| Same goal; Sol rejected RESULT and wants a **fix round** | Append `MAIN_AGENT_REVIEW_0N.md` + optional `PROMPT-fix-0N.md` or update PROMPT with “Round N”; point RESULT to same or `RESULT-round-0N.md` if cleaner |
| Same goal; Grok returned `blocked` / `partial` and scope is unchanged | Same folder; human can continue in the **same** Grok window if context is still warm |
| Multi-slice under **one** Grok 总控 | Same folder: orchestrator `PROMPT.md` + `PROMPT-0N.md` / `RESULT-0N.md`; **one** parent Grok session |
| Human says “接着上一个 Grok 做” and ownership still matches | Reuse folder + session |

**Do not** reuse a folder for an unrelated task just to “save a directory.”  
**Do not** spawn a second Grok writer on the same writable paths while the first job is in-flight (no RESULT yet, or sources dirty under ownership without RESULT).

#### When the human **may close** Grok window(s)

| Situation | Close? |
|---|---|
| `RESULT.md` (and child `RESULT-0N` if any) is on disk **and** Sol has been told / can read it | **Yes** — code + RESULT survive; window is optional |
| Sol has finished re-verify and **accepted** the job | **Yes** — safe to close all related Grok windows |
| Job is **blocked** and user will not continue soon | **Yes** — notes are in the folder; reopen later via PROMPT/RESULT |
| Grok is **still running** or ownership files are mid-edit without RESULT | **No** — closing may lose in-memory progress; wait or ask Grok to flush RESULT first |
| Sol is about to send a **fix round** in the same session | **Prefer keep open** if the same window still has useful context; else close and reopen on updated PROMPT |
| Multiple child Grok writers under 总控 | Close a **child** only after its `RESULT-0N.md` exists; close **parent** after parent `RESULT.md` exists |

**Always tell the user in plain language**, for example:

```text
新建任务：已创建 .grok_subagent/<slug>/PROMPT.md
请在 Grok Build 中打开该 PROMPT 执行（建议新会话，勿与进行中的其它写任务共用同一写集合）。
完成后请回复「Grok 写完了」；RESULT 与代码落盘后即可关闭该 Grok 窗口。
```

```text
沿用任务：继续 .grok_subagent/<slug>/（第 N 轮）
请在同一 Grok 窗口继续，或重新打开 PROMPT / PROMPT-fix-0N.md。
本轮 RESULT 更新后可关窗口；未完成前请勿关。
```

```text
可关闭：.grok_subagent/<slug>/RESULT.md 已存在（或本轮已验收）。
相关 Grok 窗口可以关掉，不影响后续 Sol 审 diff / 重跑测试。
```

### Recommended permission pack (give enough to finish)

Mode A is **not** “default read-only.” Execution jobs need write scope + commands. Prefer **read-wide, write-narrow, forbid irreversible**.

| Layer | Recommended default |
|---|---|
| **Read** | Entire product repo (and linked packages as needed) |
| **Write** | Directory-level globs preferred (`src/feature/**`, `tests/feature/**`), not a single file unless truly one-liner |
| **Git (read)** | Always allow: `git status`, `git diff`, `git log`, `git rev-parse`, `git branch` (read-only) |
| **Shell** | Exact acceptance commands (`npm test -- …`, `pnpm`, `pytest`, targeted docker compose, etc.) |
| **Forbidden** | `git reset` / `checkout --` / `clean` / force branch switch; **commit / push / deploy / merge** unless human explicitly allows; secrets / `.env` / credentials |
| **Dirty tree** | Snapshot status+HEAD+existing diff first; **preserve** unrelated dirty files; if blocked → `RESULT` status `blocked`, do not expand scope |

**Do not** starve Grok of `git status` or the acceptance command—silent inability looks like failure and tanks quality.

Still exclusive across parallel writers: ownership sets must not overlap.

### Orchestrator (Sol) steps

1. Decide **new vs reuse** (lifecycle section); ensure `.grok_subagent/` is gitignored.
2. Create or open `.grok_subagent/<slug>/`; write/update `PROMPT.md` with **writable paths**, forbidden ops, **acceptance commands**, and exact `RESULT.md` path **in the same folder**.
3. Multi-slice: multiple job folders **or** one 总控 folder with `PROMPT-0N.md` (non-overlapping ownership).
4. Tell the human: open which PROMPT, **new vs continue session**, and **when they may close** the Grok window(s).
5. Do not block forever—if RESULT never appears, offer to implement yourself.
6. Read `RESULT.md` as **untrusted**; keep follow-ups (`MAIN_AGENT_REVIEW_0N.md`, etc.) in the same folder.
7. Review full scoped **product** diff; re-run every acceptance command; only then accept.
8. After RESULT is on disk (and especially after accept), explicitly tell the human they **may close** related Grok windows.

### Grok 总控 pattern

- Prefer **one parent Grok session** per 总控 job folder.
- Preflight each child: RESULT exists → validate only; sources dirty without RESULT → in-flight, **no second writer**.
- Non-overlapping ownership; parent writes aggregate `RESULT.md`.
- Child windows: close after `RESULT-0N.md`; parent: after parent `RESULT.md`.
- Sol still re-verifies.

### Gate for Mode A

1. User approved the job boundary (or standing authority).
2. Job folder under `.grok_subagent/<named-task>/`; `PROMPT.md` complete; permission pack present.
3. `.grok_subagent/` gitignored (or user warned).
4. Dirty tree acknowledged; unrelated product changes preserved.
5. `RESULT.md` path is **inside the job folder** (not scattered into `src/`).

---

## Mode B — Headless CLI (exception: very small only)

**Do not use Mode B for normal product work.** Prefer Mode A unless the job is smoke / one-liner scale.  
Borrowed practices below improve **small** headless runs; they **do not** promote headless to the default path.

Eligible:

- Executor install smoke (`ok` + `EndTurn`)
- One-liner or ≤ ~2 files on a **clean** git directory (product repo if clean, **or** a temporary worktree—either is fine)
- Tiny read-only peek / structured second opinion (quality-critical product work still → Mode A)

### Setup

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "<this-skill>/scripts/install-executor.ps1"
# human: GROK_HOME=~/.grok-executor ; grok login
```

Isolated home stays **`~/.grok-executor`** (not interactive `~/.grok`). Do not default to `--always-approve` / `bypassPermissions`.

### Task cards (prefer files over shell strings)

```text
~/.grok-executor/task-cards/<run-id>.md
```

- Long prompts always go in a **file** (`-TaskCardPath` / equivalent of `--prompt-file`) — avoid PowerShell/CLI quoting traps.
- Keep scope tiny. Prefer Mode A over a stack of headless cards. See **`references/task-sizing.md`**.
- Optional recipes: **`references/headless-recipes.md`**.

### Working directory requirement

The wrapper requires:

- Path is a git work tree
- **`git status` clean** before start

It does **not** require a separate `git worktree add`. Use the product repo when clean; use a disposable worktree only when the main tree is dirty or you want discardable isolation.

### Permission presets (Mode B)

Default tool surface is **Read + Grep only** until you pass flags. Give enough for the card—do not leave micro-edits on ReadOnly.

| Preset | Flags | Use |
|---|---|---|
| **evidence** | `-ReadOnly -AllowedCommandPrefix git` | Tiny read-only peek / smoke |
| **micro-edit** | `-WritablePath '<dir/**>'` + `-AllowedCommandPrefix git` + test prefix | One-liner / ≤2 files |
| **opinion** | `-ReadOnly` (+ web only if needed) | Second opinion / structured extract; no product edits |

Always keep fixed denies (push, reset --hard, clean, rm/del, etc.). Never `--yolo` / `--always-approve` as convenience.

### Host timeout (borrowed discipline)

- Wrap headless runs so the **host** outlives the agent: Codex/orchestrator `timeout_ms` (or shell `timeout`) **≥ expected wall time** — often **≥ 180s** for micro-edit, **≥ 300s** for research peeks.
- Short host kill looks like random `Cancelled`; raise timeout or switch to Mode A — do not blind-retry the same mega card.

### Invoke (product micro-edit — preferred Mode B path)

Use the hardened wrapper (allowlists + scope check). Do not raw `grok -p` on product trees.

```powershell
$skill = "$HOME\.agents\skills\grok-build-executor"
# micro-edit example — WorkingDirectory = any CLEAN git tree
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$skill\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath "$HOME\.grok-executor\task-cards\<card>.md" `
  -WorkingDirectory "<clean-product-repo-or-temp-worktree>" `
  -WritablePath "src/feature/**" `
  -AllowedCommandPrefix "git","npm test --" `
  -RequireCleanIsolation
```

| Flag | When |
|---|---|
| `-ReadOnly` | evidence / opinion preset |
| `-WritablePath` | required for edit mode (directory globs OK) |
| `-AllowedCommandPrefix` | git + acceptance; default without it is Read+Grep only |
| `-AllowWebSearch` | card needs external docs |
| `-MaxTurns N` | default 40; keep tiny for Mode B |
| `-RequireCleanIsolation` | prefer on for headless |

### JSON envelope & Sol review (borrowed)

- Prefer **`--output-format json`** (wrapper already returns structured envelope).
- Treat `text` as a **lead** (change summary). Sol still re-diffs product files and re-runs acceptance — **do not** skip verification to “save tokens.”
- `ok: true` requires `stopReason == EndTurn` (not `Cancelled`), no scope violations, diff check clean.
- When reporting to the user, label conclusions as **from Grok** vs **Sol-verified**.

### Session resume (borrowed; optional, Mode B only)

Direct `grok` headless can continue a prior session (useful for **tiny** follow-ups without rewriting the whole card):

```powershell
# After a JSON run that returned sessionId (and EndTurn), a small fix-up:
# Prefer isolated GROK_HOME if you use the executor install.
$env:GROK_HOME = "$HOME\.grok-executor"
# sid from previous JSON: .sessionId
grok --resume "$sid" --output-format json -p "补上边界情况并只改允许路径" 
# Still: host timeout, allowlists, no yolo; multi-file product work → Mode A instead
```

- Wrapper invokes are **new session by default**; Cancelled mega-cards → **split / Mode A**, not blind `--resume` of a huge failed card.
- Mode A fix rounds use **job folder** files (`PROMPT-fix-0N.md`), not CLI resume.

### Structured second opinion (borrowed; optional)

For pure analysis (no product write), schema-constrained output is fine:

```powershell
# Example shape — keep the task tiny; this is NOT product implementation
grok --output-format json --json-schema '{"type":"object","properties":{"risk":{"type":"string"},"score":{"type":"number"}},"required":["risk","score"]}' `
  -p "评估以下设计风险（只输出 schema）: ..."
```

Use for risk scores / checklists. **Do not** use as the primary path to ship multi-file features.

---

## Choosing mode (quick)

| Job | Mode | Workspace |
|---|---|---|
| Multi-file product fix, dirty tree | **A** | Product repo |
| Grok 总控 + writers | **A** | Product repo + exclusive ownership |
| Docker / research / architecture | **A** | Product repo |
| Unsure / quality matters | **A** | Product repo |
| Executor smoke / one-liner, tree clean | **B** | Product repo (clean) |
| Same, but main tree dirty | **B** or **A** | Temp clean worktree, or just Mode A |
| High-risk parallel experiment | **A** (or B if tiny) | Optional independent worktree |

**Anti-pattern:** defaulting to headless or defaulting to a new worktree “for safety.” Prefer PROMPT.md + ownership + Sol verify.

---

## Failure lessons (summary)

Publishable detail: **`docs/COLLABORATION.md`**.

1. PowerShell / `grok.exe` quoting → prefer Mode A.
2. Headless mega-cards → `Cancelled`; switch to PROMPT.md.
3. `dontAsk` without tool prefixes → silent denials; **give git + acceptance**.
4. Host shell timeouts kill long headless runs.
5. Project `.mcp.json` (e.g. Figma) can stall startup.
6. Skill catalog miss → explicit paths / restart.
7. Policy: human-started Grok on disk is cleaner than exporting private source into headless.
8. Duplicate writers → exclusive sets + RESULT preflight; never two sessions on same writable set.
9. Closing Grok before RESULT flush → lost progress; always wait for RESULT on disk (or explicit abandon).
10. Trust → slice green ≠ product green.
11. Optional worktree without Sol merge plan → stranded changes.

---

## Safety non-negotiables

- Never print `auth.json`, API keys, or tokens
- Never `--yolo` / `bypassPermissions` as convenience
- Never **commit** job PROMPT/RESULT/reviews — keep them under **gitignored** `.grok_subagent/`
- Never scatter job notes into `src/` or other product source trees
- Never overlapping writable ownership across parallel Grok writers
- Never open a second writer session on an in-flight job without RESULT
- Never treat Grok RESULT/`text` as final acceptance
- Never `reset --hard` / `clean` a shared dirty tree to recover from Grok
- Always tell the human: new vs reuse job, and when Grok windows may close
- **Default Mode A; job folder = product-root `.grok_subagent/<named-task>/`; Mode B only for very small clean-tree tasks; independent worktree optional**
