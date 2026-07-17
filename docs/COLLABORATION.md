# Codex × Grok collaboration playbook

Field notes from running **GPT‑5.6 Sol (Codex)** as planner/acceptor and **Grok 4.5 (Grok Build)** as executor on real product work. Suitable for publishing on GitHub / X (no secrets, no private source).

## Two modes (default hard, exception narrow)

| Mode | How it runs | Best for | Weak at |
|---|---|---|---|
| **A. Document handoff + interactive Grok** (**default**) | Codex writes job files → human/Grok opens **PROMPT** in Grok Build UI → Grok writes **RESULT** → Codex re-verifies | Almost everything: product slices, multi-file work, research, long builds, dirty trees, Grok 总控 + subagents | Fully unattended CI without a human pasting the prompt |
| **B. Headless CLI wrapper** (**exception only**) | Codex shells into isolated `GROK_HOME` + allowlisted `grok -p` | **Very small** tasks only: executor smoke, one-liner / ≤~2 files on a **clean** git tree, tiny peek | Anything non-tiny: product work, mega research, Docker, multi-file, dirty trees |

**Default always: Mode A (`PROMPT.md`).** Field experience: more stable and better results than headless.  
**Mode B only when the task is truly tiny.** When in doubt → Mode A. Do not default to headless.  
**Independent git worktree is optional**, not a default. Mode A runs on the product tree. Mode B only needs a **clean** tree (product repo if clean, or a temp worktree if main is dirty).

Both modes share the same governance:

1. Sol plans and owns merge/complete.
2. Grok stays inside explicit file ownership (read-wide, write-narrow).
3. Grok’s narrative (`RESULT` / JSON `text`) is a **lead**, never acceptance.
4. Sol personally inspects diff and re-runs acceptance commands.
5. Give enough permissions to finish (git read + acceptance commands); forbid irreversible ops.

---

## Mode A — Document handoff (default; prefer this)

### Layout

```text
<product-repo>/
  .grok_subagent/                      # gitignored
    <YYYYMMDD-HHMM-slug>/              # one named folder per task
      PROMPT.md                        # what Grok (or Grok coordinator) executes
      RESULT.md                        # what Grok writes back
      MAIN_AGENT_PROMPT.md             # optional: Sol post-review checklist
      MAIN_AGENT_REVIEW_0N.md          # optional: Sol round follow-ups
      PROMPT-01.md / RESULT-01.md      # optional exclusive sub-slices
      RESULT_REVIEW_*.md               # optional review artifacts
```

Example:

```text
<path/to/product>/.grok_subagent/20260712-2320-p0-fallback-stream-root-fix/
```

Product **code** stays in normal source paths. Job **notes** live under `.grok_subagent/` and must be **gitignored** (never committed).  
Legacy fallback: `~/grok-agent-jobs/<project>/<job-id>/` only if product-root jobs are impractical.

### Roles

| Actor | Does |
|---|---|
| **Codex / Sol** | Decides **new vs reuse** job folder; writes `PROMPT*.md` + follow-ups; defines ownership + acceptance; later reads `RESULT*.md`, reviews full product diff, re-runs tests; **tells human when to open/close Grok windows**; commits only after evidence |
| **Human** | Opens `PROMPT.md` in Grok Build (new session or continue, as Sol says); closes Grok windows only when Sol says RESULT is on disk / job done (or user abandons) |
| **Grok Build (interactive)** | Executes prompt; may spawn **non-overlapping** subagents; writes `RESULT.md`; does not commit/push/deploy unless prompt allows (default: forbid) |

### Job lifecycle (new / reuse / close)

See skill body section **Job lifecycle**. Summary:

| Action | When |
|---|---|
| **New** `.grok_subagent/<slug>/` | New goal, new ownership set, parallel unrelated track, or prior job closed |
| **Reuse** same folder | Same goal: fix round, blocked→continue, or multi-slice under one 总控 |
| **Close Grok window** | After `RESULT.md` (and child RESULTs) on disk; safe after Sol accept; **not** while mid-edit without RESULT |

### Coordinator pattern (Grok as 总控)

For multiple slices:

1. Sol writes one **orchestrator** `PROMPT.md` that points at child `PROMPT-01.md` paths and exclusive writable file sets.
2. User starts **one** Grok session on that orchestrator prompt.
3. Grok parent:
   - preflights each child (`RESULT` present? in-flight writer?);
   - spawns at most N writers with **non-overlapping** ownership;
   - never two writers on the same files;
   - validates child results;
   - writes parent `RESULT.md` with status matrix + command logs.
4. Sol uses `MAIN_AGENT_PROMPT.md` (or skill rules) to **independently** re-check everything.

### Minimal `PROMPT.md` contract

- Working directories / branches (**product repo by default**; independent worktree only if Sol created one)
- Job folder: `<product>/.grok_subagent/<YYYYMMDD-HHMM-slug>/` (gitignored)
- **Permission pack:** read-wide; writable **directory** globs preferred; always allow read-only git (`status`/`diff`/`log`); exact acceptance commands
- Forbidden ops (reset/clean/commit/push/deploy/secrets) — hard list
- Implementation or analysis requirements
- Exact path for `RESULT.md` **in the same job folder**
- Final terminal reply: compact pointer JSON only (optional)

Do **not** default the job to read-only when Grok must implement. Starving `git status` or tests causes silent failure and worse output.

### Minimal `RESULT.md` contract

- Status: `ok` / `blocked` / `partial`
- Changed files + ownership notes
- Design invariants
- Exact command outputs / pass counts
- Blockers
- Confirmation of no commit/push/deploy (when required)

### Minimal `MAIN_AGENT_PROMPT.md` contract (Sol)

- Paths to PROMPT + RESULT
- Allowed final product diffs
- Steps: protect dirty tree → read RESULT as untrusted → full diff review → re-run acceptance → accept/reject

### Why this beats pure CLI for product work

- Grok keeps a full interactive agent loop (subagents, long builds, multi-step recovery).
- No Codex shell `timeout_ms` killing a 5–10 minute Docker build mid-flight.
- No PowerShell argument-splitting bugs around `grok.exe`.
- Works on a **dirty product tree** with exclusive ownership (no mandatory worktree).
- Private-source policy: Codex may be blocked from **pushing** repo bytes into external headless calls; human-started Grok already has local disk access.
- Results survive closing the Grok UI once files are written.

### Optional independent worktree (Mode A or B)

Not required. Use when: main tree too dirty for Mode B, true long parallel forks, or high-risk experiments you may discard.

Sol-owned merge flow:

1. `git worktree add … -b gw/job-<id> <base>`
2. Grok works only there; RESULT under product `.grok_subagent/<task>/`
3. Sol verifies inside worktree → **cherry-pick / merge** into main line
4. Re-run acceptance on main line → remove worktree

Never `reset --hard` the shared main tree to clean up.

---

## Mode B — Headless CLI wrapper (very small only)

**Do not use for normal product work.** Prefer Mode A unless the job is a smoke or one-liner-scale card.

Script: `scripts/invoke-grok-executor.ps1`  
Skill entry: `$grok-build-executor`

Properties:

- Isolated `GROK_HOME=~/.grok-executor` (SuperGrok OAuth separate from interactive `~/.grok`)
- Fixed model `grok-4.5`
- `dontAsk` + path/command allowlists
- Task cards only under `~/.grok-executor/task-cards/`
- JSON envelope on stdout; `stopReason` must be `EndTurn`
- Working directory must be a **clean** git tree — **product repo if clean is enough**; separate worktree only if main is dirty

Eligible only for:

- Smoke tests of the executor itself
- One-liner or ≤ ~2 files on a clean tree
- Tiny read-only peeks (quality work still → Mode A)

Permission presets:

| Preset | Flags | Notes |
|---|---|---|
| evidence | `-ReadOnly -AllowedCommandPrefix git` | Default-tight is OK for peeks |
| micro-edit | `-WritablePath 'dir/**'` + git + test prefixes | Do not leave real edits on ReadOnly only |
| opinion | ReadOnly / pure `-p` | Second opinion; label as Grok’s words |

**Borrowed from community headless skills (kept Mode A default):**

- Long prompts in **files** (not shell strings)
- Host **timeout** ≥ wall time
- JSON `text` as summary only; orchestrator still re-verifies
- Optional `--resume` / `--json-schema` for **tiny** peeks only
- **Not** borrowed: headless-as-default, `--always-approve` / yolo, shared unisolated home for automation

If the work needs quality, multi-file ownership, long tools, or Grok subagents → **write `PROMPT.md`**, do not “fix” with more headless cards.  
See `references/task-sizing.md` and `references/headless-recipes.md`.

---

## Failure log: what we tried and what broke

### 1) Naive `grok -p "..."` / `--yolo`

- No path ownership, easy to dirty the main tree or over-edit.
- Hard to parse success; no standard RESULT artifact.
- **Lesson:** always bound scope; prefer job folders or the wrapper.

### 2) PowerShell `Start-Process` / bad quoting around `grok.exe`

- Arguments like `node --test` were split; wrapper saw a fake parameter `-test` and aborted in ~1s.
- Nested `powershell -Command { ... -args }` also fragile on Windows.
- **Lesson:** call the wrapper with a single well-quoted command line, or use **Mode A** and avoid shelling Grok from Codex for long jobs.

### 3) Headless mega task cards

- Full-stack architecture surveys repeatedly ended with `stopReason: Cancelled` and a short preamble despite `exitCode: 0`.
- Wrapper correctly marks `ok: false` when not `EndTurn`.
- After splitting into evidence-domain cards, many runs returned multi-KB `EndTurn` reports.
- **Lesson:** one headless run ≠ one research program. Split first.

### 4) `dontAsk` + missing tool allows

- Read-only default is **Read + Grep only**.
- Cards that require `git status` without `-AllowedCommandPrefix git` get silent denials → early abandon / Cancelled.
- Cards that require official docs without `-AllowWebSearch` cannot fulfill evidence rules.
- **Lesson:** tool needs in the card must match invoke flags.

### 5) Host shell timeouts

- Codex `timeout_ms` of 60–120s kills long headless runs; looks like random Cancelled.
- Successful research cards often needed 150–180s+ of tool use; Docker even longer.
- **Lesson:** research/build jobs either raise host timeout dramatically or use Mode A.

### 6) Project `.mcp.json` (e.g. Figma)

- Grok loads project-root `.mcp.json` even when Claude/Cursor MCP compat is disabled.
- `figma-developer-mcp` via `npx` caused repeated **30s init timeouts** on executor startup.
- **Lesson:** strip unused project MCP servers before headless batches; rotate any API keys that were ever committed.

### 7) Skill discovery in long Codex sessions

- `$grok-build-executor` sometimes missing from the in-session skill catalog (budget / listing), even when files exist under `~/.agents/skills/`.
- **Lesson:** explicit path to `SKILL.md` / scripts; keep skill description short; restart session if catalog is stale.

### 8) Platform / policy friction

- Orchestrator may be forbidden from **exporting private source** to external automation on the user’s behalf.
- Waiting forever for Grok when the human never pastes the PROMPT stalls the goal.
- **Lesson:** Mode A makes the human start Grok explicit; Sol should time-box “waiting for RESULT” and offer to implement itself if Grok never starts.

### 9) Duplicate writers

- Parallel Grok agents without exclusive file sets double-edit the same modules.
- Orchestrator prompts now require preflight: if `RESULT` exists or scoped files are mid-write, do not spawn a second writer.
- **Lesson:** ownership sets are part of the contract, not optional etiquette.

### 10) Trusting Grok’s “ok”

- Even after Mode A success, Sol must re-run tests; expanded suites still found regressions outside Grok’s slice.
- **Lesson:** slice green ≠ product green.

---

## Suggested public workflow (copy for X / README)

1. Sol ensures `.grok_subagent/` is gitignored; creates `.grok_subagent/<YYYYMMDD-HHMM-slug>/PROMPT.md` (+ optional child prompts / review files).
2. Human opens Grok Build, pastes/opens that PROMPT (or starts Grok 总控 on the orchestrator file).
3. Grok writes `RESULT.md` in the job folder (and code in the product tree within ownership).
4. Human tells Sol “Grok finished” or Sol detects RESULT mtime.
5. Sol runs `MAIN_AGENT_PROMPT` logic: untrusted RESULT → full product diff → re-test → accept/reject.
6. Only then commit/push/deploy **product code** under user authority — never commit `.grok_subagent/`.

CLI wrapper remains for small, clean, automated slices—not as the only integration path.

---

## Anti-patterns (short list)

- One CLI card for “fix everything / survey entire architecture”
- Codex blocking the main goal on Grok forever without a fallback
- No RESULT path (chat-only handoff)
- Overlapping writable files across parallel agents
- Committing secrets into `.mcp.json` or task cards
- `git reset --hard` to “clean up” after a Grok experiment on a shared dirty tree
- Forcing a new independent worktree for every Grok job when Mode A on the product tree would do
- Defaulting Mode A prompts to read-only / no git / no tests so Grok cannot finish
