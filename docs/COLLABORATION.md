# Codex × Grok collaboration playbook

Field notes from running **GPT‑5.6 Sol (Codex)** as planner/acceptor and **Grok 4.5 (Grok Build)** as executor on real product work. Suitable for publishing on GitHub / X (no secrets, no private source).

## Two modes (pick by job size)

| Mode | How it runs | Best for | Weak at |
|---|---|---|---|
| **A. Document handoff + interactive Grok** | Codex writes job files → human/Grok opens **PROMPT** in Grok Build UI → Grok writes **RESULT** → Codex re-verifies | Multi-file fixes, parallel subagents, long builds, dirty-tree work with exclusive ownership | Fully unattended CI without a human pasting the prompt |
| **B. Headless CLI wrapper** (`invoke-grok-executor.ps1`) | Codex shells into isolated `GROK_HOME` + allowlisted `grok -p` | Small, clean worktrees; smoke tests; narrow read-only evidence cards | Mega research cards; long Docker builds; anything needing Grok’s full interactive subagent UI |

**Recommended default for real product slices:** Mode A.  
**Keep Mode B** for automated micro-executions and isolation-hardened runs.

Both modes share the same governance:

1. Sol plans and owns merge/complete.
2. Grok stays inside explicit file ownership.
3. Grok’s narrative (`RESULT` / JSON `text`) is a **lead**, never acceptance.
4. Sol personally inspects diff and re-runs acceptance commands.

---

## Mode A — Document handoff (current preferred)

### Layout

```text
grok-agent-jobs/
  README.md
  <project>/
    <job-id>/
      PROMPT.md              # what Grok (or Grok coordinator) executes
      RESULT.md              # what Grok writes back
      MAIN_AGENT_PROMPT.md   # optional: what Sol does after RESULT lands
      PROMPT-01.md …         # optional: exclusive sub-slices
      RESULT-01.md …
```

Example root used in practice:

```text
D:\Projects\grok-agent-jobs\<project>\<YYYYMMDD-HHMM-slug>\
```

Product code stays in the real repo(s). **Job artifacts never go into the product git tree.**

### Roles

| Actor | Does |
|---|---|
| **Codex / Sol** | Creates job folder, writes `PROMPT*.md`, defines ownership + acceptance, later reads `RESULT*.md`, reviews full diff, re-runs tests, commits only after evidence |
| **Human** | Pastes `PROMPT.md` into Grok Build (or starts Grok on that file); can close Grok windows once results are on disk |
| **Grok Build (interactive)** | Executes prompt; may spawn **non-overlapping** subagents; writes `RESULT.md`; does not commit/push/deploy unless prompt allows (default: forbid) |

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

- Working directories / branches
- Writable file list (exclusive)
- Forbidden ops (reset/clean/commit/push/deploy/secrets)
- Implementation or analysis requirements
- Exact acceptance commands
- Exact path for `RESULT.md`
- Final terminal reply: compact pointer JSON only (optional)

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
- Private-source policy: Codex may be blocked from **pushing** repo bytes into external headless calls; human-started Grok already has local disk access.
- Results survive closing the Grok UI once files are written.

---

## Mode B — Headless CLI wrapper (still useful)

Script: `scripts/invoke-grok-executor.ps1`  
Skill entry: `$grok-build-executor`

Properties:

- Isolated `GROK_HOME=~/.grok-executor` (SuperGrok OAuth separate from interactive `~/.grok`)
- Fixed model `grok-4.5`
- `dontAsk` + path/command allowlists
- Task cards only under `~/.grok-executor/task-cards/`
- JSON envelope on stdout; `stopReason` must be `EndTurn`

Use for:

- Micro edits on a **clean** disposable worktree
- Read-only evidence cards (after sizing/split)
- Smoke tests of the executor itself

See `references/task-sizing.md` for split rules (mega-cards often return `Cancelled`).

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

1. Sol creates `grok-agent-jobs/<project>/<job>/PROMPT.md` (+ optional child prompts).
2. Human opens Grok Build, pastes/opens that PROMPT (or starts Grok 总控 on the orchestrator file).
3. Grok writes `RESULT.md` (and code in the product tree within ownership).
4. Human tells Sol “Grok finished” or Sol detects RESULT mtime.
5. Sol runs `MAIN_AGENT_PROMPT` logic: untrusted RESULT → full diff → re-test → accept/reject.
6. Only then commit/push/deploy under user authority.

CLI wrapper remains for small, clean, automated slices—not as the only integration path.

---

## Anti-patterns (short list)

- One CLI card for “fix everything / survey entire architecture”
- Codex blocking the main goal on Grok forever without a fallback
- No RESULT path (chat-only handoff)
- Overlapping writable files across parallel agents
- Committing secrets into `.mcp.json` or task cards
- `git reset --hard` to “clean up” after a Grok experiment on a shared dirty tree
