# Security

## Secrets

- This repository must **never** contain `auth.json`, API keys, OAuth tokens, or cookies.
- Executor credentials live only on the user's machine under `~/.grok-executor/` (local).
- Coding agents configuring this skill must not print credential file contents.

## Threat model (brief)

| Risk | Mitigation in this skill |
|---|---|
| Grok edits outside intended paths | Relative `Edit(**/glob)` allow + post-run `changedFiles` check |
| Destructive shell | Deny list + command prefix allowlist |
| Nested agent fan-out | `--no-subagents`, mutex |
| Prompt injection via huge context | Task card size cap (64 KiB), no parent transcript dump |
| Accidental credential leak into git | Separate `GROK_HOME`; `.gitignore` templates; docs forbid commit |

## Reporting

If you find a vulnerability in the wrapper scripts or docs that could cause credential leakage or unsafe defaults, open a GitHub issue **without** attaching secrets, or contact the maintainer via GitHub.
