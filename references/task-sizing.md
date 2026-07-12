# Task sizing and split playbook

Forward-tested against real Grok 4.5 headless runs: **monolithic research cards frequently end with `stopReason: Cancelled` and a few-dozen-character preamble; split evidence cards of comparable total scope often return `EndTurn` with multi-kilobyte reports.**

Use this file when the user asks for architecture survey, multi-module root-cause analysis, framework migration assessment, or any work that cannot be verified with one short acceptance command.

## Hard limits of one executor run

| Limit | Default | Practical meaning |
|---|---|---|
| Model | `grok-4.5` only | No alternate "long research" model switch |
| `--max-turns` | **40** (override with `-MaxTurns`) | Full-repo surveys often exhaust or abandon before `EndTurn` |
| Permission mode | `dontAsk` | Missing allow → **silent deny**, not a prompt |
| Read-only tools | `Read` + `Grep` only unless `-AllowedCommandPrefix` | No `git` / shell unless you allow prefixes |
| Web | off unless `-AllowWebSearch` | Task cards that demand official docs must opt in |
| Concurrency | one process (mutex) | Queue cards; do not fan out parallel Grok executors yet |
| Task card size | ≤ 64 KiB | Size is rarely the bottleneck; **work volume** is |
| Resume | new session each invoke | Cancelled runs do **not** auto-continue; re-issue a smaller card |

Success in the wrapper means:

```text
ok == true  ∧  stopReason == "EndTurn"  ∧  no scopeViolations  ∧  diffCheckOk
```

`exitCode == 0` with `stopReason: Cancelled` is still **failure**. Do not treat partial `text` as a finished report.

## When a request is too large for one card

Split **before** the first invoke if any of these hold:

1. More than ~8–12 primary directories or subsystems must be traced.
2. Deliverable needs multi-chapter report (architecture + root causes + target design + migration + roadmap).
3. Both deep local code evidence **and** external official-doc synthesis are required.
4. Acceptance cannot be stated as one cheap command or a short evidence checklist.
5. Estimated wall time ≫ 3 minutes of agentic tool use (orchestrator shell `timeout_ms` must be raised accordingly).

If unsure, prefer **two cards** over one.

## Split strategy (orchestrator owns the DAG)

1. **Freeze baseline** once: commit SHA + clean worktree path shared by all cards.
2. **Partition by evidence domain**, not by prose outline. Each card owns non-overlapping questions and path lists.
3. **One primary artifact per card**: e.g. topology memo, root-cause matrix for one bug family, target seam design, external framework fit assessment.
4. **Serial by default** (mutex). Only after concurrency is forward-tested may independent read-only cards run in parallel.
5. **Synthesize outside Grok**: the orchestrator merges card `text` fields, re-checks citations against the repo, and writes the user-facing conclusion.
6. **On `Cancelled`**: do not blind-retry the same card. Narrow paths, raise `-MaxTurns`, add missing prefixes / web, or split again.

## Suggested card shapes

### Implementation (edit mode)

- Single feature slice or single bug with red→green command.
- `-WritablePath` relative globs only; one or few prefixes for tests.
- `-MaxTurns 40` is often enough; use 60 if multi-file but still bounded.

### Read-only code topology

- Entry points, ownership boundaries, call chains for **one** runtime path.
- `-ReadOnly -AllowedCommandPrefix git -MaxTurns 60..80`
- Acceptance: `changedFiles=[]` and a structured memo with file/symbol citations.

### Read-only root-cause family

- One bug family (e.g. stream duplication **or** cancel/deadline **or** council fan-out)—not all at once.
- Same invoke flags as topology; optional `-AllowWebSearch` only if external protocol docs are named in the card.
- Acceptance: matrix of symptom → direct cause → systemic cause → severity, each with local evidence.

### Target design / seams

- Interfaces and ownership only; no implementation patches.
- May reference prior card outputs by quoting frozen excerpts in the new card (do not rely on Grok memory).

### External framework assessment

- Compare current code to **named** official docs.
- **Requires** `-AllowWebSearch` and an allowlisted source list in the card.
- Explicit non-goals: no migration commits.

## Invoke presets

### Small edit

```powershell
# -WritablePath / -AllowedCommandPrefix as needed
# -MaxTurns 40 (default)
# orchestrator shell timeout_ms >= 180000
```

### Research / architecture evidence

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  "$HOME\.agents\skills\grok-build-executor\scripts\invoke-grok-executor.ps1" `
  -TaskCardPath "$HOME\.grok-executor\task-cards\<card>.md" `
  -WorkingDirectory "<clean-worktree>" `
  -ReadOnly `
  -AllowedCommandPrefix "git" `
  -MaxTurns 80 `
  -RequireCleanIsolation
# add -AllowWebSearch only if the card names external evidence gaps
# orchestrator shell timeout_ms >= 300000 (prefer 600000)
```

## Card authoring checklist

- [ ] Single goal sentence
- [ ] Explicit path allowlist (read or write)
- [ ] Explicit non-goals
- [ ] Frozen baseline SHA
- [ ] Acceptance that is mechanical (`changedFiles=[]`, named commands, required section headings)
- [ ] Tool needs match flags (`git` → prefix; official URLs → web)
- [ ] Expected runtime under ~3–5 minutes of tool use; else split
- [ ] No parent transcript paste; only necessary excerpts

## Failure signatures

| Observation | Likely cause | Next action |
|---|---|---|
| `stopReason: Cancelled`, `text` is a short preamble | Card too large / tools denied / host timeout | Split; align allows; raise MaxTurns + host timeout |
| `Cancelled` after ~60–120s, almost no progress | Host shell timeout or early abandon | Set orchestrator `timeout_ms` ≥ 300000; narrow card |
| Repeated denials in stderr / empty progress | Missing `AllowedCommandPrefix` or web | Fix flags; do not widen to yolo |
| `ok: true` but thin `text` | Weak acceptance criteria | Tighten Done-when sections; re-run focused card |
| Mutex error | Another Grok run active | Wait; never disable mutex casually |

## Anti-patterns

- One card: "map the whole agent stack + all bugs + target architecture + migration plan"
- Read-only card that requires `git status` without allowing `git`
- Demanding official-doc citations without `-AllowWebSearch`
- Retrying the identical cancelled card more than once without narrowing
- Treating Grok `text` as merge-ready truth without orchestrator verification
