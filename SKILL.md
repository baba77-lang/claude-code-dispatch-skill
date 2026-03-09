---
name: claude-code-dispatch
description: 'Dispatch long-running coding tasks to Claude Code CLI with zero-polling hook callbacks. Use when: (1) coding tasks that take more than 1 minute and would waste tokens with polling, (2) building features, apps, or refactoring with Claude Code headless mode, (3) parallel Agent Teams development tasks, (4) any task where you want fire-and-forget with automatic result notification via hooks. NOT for: quick one-liner fixes (use edit tool), tasks needing real-time interaction, or reading code (use read tool). Requires Claude Code CLI installed with hooks configured in ~/.claude/settings.json.'
---

# Claude Code Dispatch (Zero-Polling Hook Pattern)

Dispatch tasks to Claude Code headless mode. Claude Code runs independently in background; Stop/SessionEnd hooks auto-write results and wake OpenClaw when done. Zero polling = zero wasted tokens.

## Architecture

```
dispatch-claude-code.sh -p "task" -n "name" -w /path
  ├─ Writes .claude-task-meta.json (task tracking)
  ├─ Launches: claude --dangerously-skip-permissions -p "task" (nohup background)
  └─ Returns immediately — OpenClaw is free

  ⏳ Claude Code runs autonomously...

  Claude Code finishes → Stop Hook fires
    ├─ notify-agi.sh:
    │   ├─ Writes ~/workspace/claw/agents/claude-code-results/latest.json
    │   ├─ openclaw system event --text "Done: ..." --mode now
    │   └─ 30s lock file dedup
    └─ OpenClaw wakes → reads latest.json → reports to user
```

## Dispatch a Task

```bash
exec background:true command:"~/workspace/claw/agents/scripts/dispatch-claude-code.sh \
  -p 'Build a REST API with FastAPI + SQLite' \
  -n 'todo-api' \
  -w ~/workspace/claw/my-project"
```

Then **do not poll**. Wait for the hook wake event.

### Parameters

| Flag | Short | Required | Description |
|------|-------|----------|-------------|
| `--prompt` | `-p` | Yes | Task description |
| `--name` | `-n` | No | Task name for tracking (default: unnamed-task) |
| `--workdir` | `-w` | No | Working directory (default: cwd) |
| `--agent-teams` | | No | Enable Agent Teams parallel sub-agents |
| `--model` | | No | Override Claude model |

### With Agent Teams

```bash
exec background:true command:"~/workspace/claw/agents/scripts/dispatch-claude-code.sh \
  -p 'Build a game with physics engine' \
  -n 'physics-game' \
  -w ~/workspace/claw/game \
  --agent-teams"
```

## Reading Results

When wake event arrives, read:

```bash
cat ~/workspace/claw/agents/claude-code-results/latest.json | jq .
```

Result format:
```json
{
  "session_id": "...",
  "timestamp": "2026-03-10T01:00:00+00:00",
  "cwd": "/path/to/project",
  "task_name": "my-task",
  "status": "done",
  "output": "..."
}
```

Also check task output directly:
```bash
cat /path/to/project/.claude-task-output.txt | tail -50
```

## After Completion Checklist

1. Read `latest.json` for status
2. Check `git log --oneline -3` in workdir for commits
3. Check `git status` for uncommitted changes
4. Run build verification if needed
5. Report results to user

## Files

| File | Location |
|------|----------|
| dispatch script | `~/workspace/claw/agents/scripts/dispatch-claude-code.sh` |
| hook script | `~/.claude/hooks/notify-agi.sh` |
| hook config | `~/.claude/settings.json` |
| results | `~/workspace/claw/agents/claude-code-results/latest.json` |

## Fault Tolerance

- Wake event fails → latest.json still persists → AGI reads on next heartbeat
- Hook fires twice → 30s lock file deduplicates
- Claude Code crashes → SessionEnd hook still fires

## Key Rule

**Never poll Claude Code process status.** The entire point is zero-polling. Dispatch and wait for hook notification.
