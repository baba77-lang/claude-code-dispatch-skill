# Codex CLI Dispatch Architecture

## Goal

Replace polling-heavy coding workflows with a zero-polling background pattern using Codex CLI.

## Why this pattern

`codex exec` already gives three primitives that matter:

1. `--json` → structured JSONL events
2. `--output-last-message <file>` → final assistant answer in a stable file
3. regular process exit code → deterministic completion signal

That means a wrapper script can behave like a hook system even if Codex CLI does not expose first-class completion hooks.

## Runtime flow

```text
OpenClaw
  └─ dispatch-codex-cli.sh
      ├─ write .codex-task-meta.json
      ├─ launch codex exec in background
      ├─ save JSONL events + final message
      └─ wait for process exit
           └─ notify-openclaw.sh
                ├─ read task metadata
                ├─ summarize final output
                ├─ write latest.json
                └─ openclaw system event --mode now
```

## Output files

Inside the target workdir:

- `.codex-task-meta.json` — task metadata
- `.codex-task-prompt.txt` — exact prompt sent to Codex
- `.codex-task-events.jsonl` — raw Codex event stream
- `.codex-task-last-message.txt` — clean final assistant response
- `.codex-task-output.txt` — merged stdout/stderr capture for debugging

Global result file:

- `~/workspace/claw/agents/codex-cli-results/latest.json`

## Recommended defaults

- Sandbox: `workspace-write`
- Approval: `never` for isolated external sandbox setups, otherwise tune per environment
- Web search: enable only when freshness matters

## Failure handling

- If Codex exits non-zero, still write `latest.json` with `status: failed`.
- If `openclaw system event` fails, keep `latest.json` so the main agent can recover later.
- Keep artifacts in the repo until post-run cleanup is intentionally added.
