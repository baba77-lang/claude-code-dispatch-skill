---
name: codex-cli-dispatch
description: Dispatch coding tasks to Codex CLI in non-interactive mode with zero-polling completion callbacks. Use when building features, refactoring repos, fixing bugs, reviewing code, or running longer coding tasks through Codex CLI instead of Claude Code. Especially useful when the assistant should launch Codex in the background, avoid polling, persist task metadata/results, and notify OpenClaw when Codex finishes. Not for tiny one-line edits that can be done directly with the edit tool.
---

# Codex CLI Dispatch

Use Codex CLI as the default coding engine for non-trivial development work. Dispatch once, let Codex run in the background, and rely on a completion callback to write results and wake OpenClaw.

## Quick start

Run the dispatcher script:

```bash
~/workspace/claw/codex-cli-dispatch/scripts/dispatch-codex-cli.sh \
  -p 'Build a REST API with FastAPI and SQLite' \
  -n 'todo-api' \
  -w ~/workspace/claw/my-project
```

Then do **not** poll in a loop. Wait for the callback wake event.

## Workflow

1. Write task metadata into the target repo.
2. Launch `codex exec` with JSONL event output.
3. Persist the final assistant message and full event log.
4. On process exit, run `notify-openclaw.sh`.
5. The notifier writes `~/workspace/claw/agents/codex-cli-results/latest.json` and sends an OpenClaw wake event.

## Default command pattern

Use `codex exec` with these defaults unless the task needs something else:

- `--json` for machine-readable event logs
- `--output-last-message` for clean final response capture
- `--sandbox workspace-write` for normal repo work
- `--skip-git-repo-check` only when intentionally working outside a git repo

## Parameters

| Flag | Required | Meaning |
| --- | --- | --- |
| `-p`, `--prompt` | Yes | Task for Codex |
| `-n`, `--name` | No | Human-readable task name |
| `-w`, `--workdir` | No | Repo or workspace path |
| `-m`, `--model` | No | Codex model override |
| `-s`, `--sandbox` | No | Sandbox mode (`read-only`, `workspace-write`, `danger-full-access`) |
| `-a`, `--approval` | No | Approval mode (`untrusted`, `on-request`, `never`) |
| `--search` | No | Enable live web search |
| `--skip-git-repo-check` | No | Allow non-git workdirs |
|

## Read results

Primary result file:

```bash
cat ~/workspace/claw/agents/codex-cli-results/latest.json | jq .
```

Useful repo-local artifacts:

- `.codex-task-meta.json`
- `.codex-task-prompt.txt`
- `.codex-task-events.jsonl`
- `.codex-task-last-message.txt`
- `.codex-task-output.txt`

## After completion

1. Read `latest.json`.
2. Check `git log --oneline -3`.
3. Check `git status`.
4. Run build/tests if relevant.
5. Commit and push if the task was meant to land.
6. Report back to the user.

## Callback model vs hooks

Codex CLI currently exposes a strong non-interactive interface (`codex exec --json` and `--output-last-message`). If a first-class hook API is unavailable or unstable, use the wrapper callback pattern in this skill:

- background Codex process
- shell `wait`
- notifier script on exit

That gives nearly the same operational result as hooks: zero polling, structured logs, and instant wake-up.

## Files

- Dispatcher: `scripts/dispatch-codex-cli.sh`
- Notifier: `scripts/notify-openclaw.sh`
- Reference notes: `references/architecture.md`

## Rule

For non-trivial coding tasks, prefer Codex CLI dispatch over ad-hoc polling loops.
