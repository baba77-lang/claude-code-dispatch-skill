# Codex CLI Dispatch Skill for OpenClaw

> Note: this repository currently keeps the legacy GitHub repo name `claude-code-dispatch-skill`, but the skill itself now targets **Codex CLI**.

Zero-polling coding dispatch for OpenClaw using **Codex CLI**.

## What it does

- launches `codex exec` in the background
- captures structured JSONL events with `--json`
- captures the final assistant message with `--output-last-message`
- runs a notifier callback on process exit
- writes `latest.json`
- wakes OpenClaw immediately with `openclaw system event`

## Why this pattern

A true first-class hook API for Codex CLI may not be documented/stable yet. But `codex exec` already exposes enough primitives to build a hook-like completion flow:

- machine-readable event stream
- deterministic exit code
- final message file

So the wrapper callback pattern gives nearly the same operational result as hooks, without polling.

## Files

- `SKILL.md`
- `references/architecture.md`
- `scripts/dispatch-codex-cli.sh`
- `scripts/notify-openclaw.sh`

## Smoke test used locally

```bash
~/workspace/claw/codex-cli-dispatch/scripts/dispatch-codex-cli.sh \
  -p 'Reply with exactly: skill-test-ok' \
  -n 'smoke-test' \
  -w /tmp/codex-skill-test \
  --skip-git-repo-check
```

Expected result file:

```bash
cat ~/workspace/claw/agents/codex-cli-results/latest.json | jq .
```

## Packaging

```bash
python3 ~/.nvm/versions/node/v24.14.0/lib/node_modules/openclaw/skills/skill-creator/scripts/package_skill.py \
  ~/workspace/claw/codex-cli-dispatch \
  ~/workspace/claw/dist-skills
```
