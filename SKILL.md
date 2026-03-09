---
name: claude-code-dispatch
description: 'Dispatch coding tasks to Claude Code with zero-polling hook callbacks. Use when: (1) long-running coding tasks that would waste tokens with polling, (2) parallel Agent Teams development, (3) any Claude Code task where you want fire-and-forget with auto-notification. NOT for: quick one-liner fixes (just use edit tool), tasks needing real-time interaction. Requires Claude Code CLI installed.'
metadata:
  {
    "openclaw": { "emoji": "🚀", "requires": { "anyBins": ["claude"] } },
  }
---

# Claude Code Dispatch (Zero-Polling Hook Pattern)

Fire-and-forget Claude Code tasks with automatic result delivery via hooks.

## Why This Exists

Traditional approach: OpenClaw polls Claude Code every few seconds → massive token waste.
This approach: Dispatch once → Claude Code runs independently → Hook auto-notifies on completion → Zero polling tokens.

## Architecture

```
OpenClaw dispatches task
  │
  ├─ Writes task-meta.json (task name, metadata)
  ├─ Launches Claude Code in background (nohup)
  │   └─ Claude Code runs autonomously
  │
  └─ OpenClaw is FREE to do other things
      │
      ⏳ (minutes later...)
      │
      Claude Code finishes → Stop Hook triggers
        ├─ notify-agi.sh executes:
        │   ├─ Writes latest.json (full results)
        │   ├─ Sends openclaw wake event (instant notification)
        │   └─ Deduplicates (30s lock)
        │
        └─ OpenClaw wakes up → reads latest.json → reports to user
```

## Files

| File | Location | Purpose |
|------|----------|---------|
| `notify-agi.sh` | `~/.claude/hooks/` | Stop/SessionEnd hook script |
| `settings.json` | `~/.claude/settings.json` | Claude Code hook config |
| `dispatch-claude-code.sh` | `~/workspace/claw/agents/scripts/` | One-shot task dispatcher |
| `latest.json` | `~/workspace/claw/agents/claude-code-results/` | Task result output |

## Usage

### Method 1: Dispatch Script (Recommended)

```bash
# Simple task
~/workspace/claw/agents/scripts/dispatch-claude-code.sh \
  -p "Build a REST API with FastAPI + SQLite for managing TODOs" \
  -n "todo-api" \
  -w ~/workspace/claw/my-project

# With Agent Teams (parallel sub-agents)
~/workspace/claw/agents/scripts/dispatch-claude-code.sh \
  -p "Build a game with physics engine using HTML/CSS/JS" \
  -n "physics-game" \
  -w ~/workspace/claw/game-project \
  --agent-teams
```

### Method 2: Direct Claude Code with Hook

```bash
# The hook is already registered in ~/.claude/settings.json
# Just run claude code normally — hooks fire automatically on completion
cd ~/workspace/claw/my-project
claude --dangerously-skip-permissions -p 'Your task here'
```

### Method 3: From OpenClaw (exec tool)

```bash
# Background dispatch — OpenClaw stays free
exec background:true command:"~/workspace/claw/agents/scripts/dispatch-claude-code.sh -p 'Build feature X' -n 'feature-x' -w ~/workspace/claw/project"

# Then just wait. Hook will wake you when done.
```

## Dispatch Script Parameters

| Parameter | Short | Description |
|-----------|-------|-------------|
| `--prompt` | `-p` | Task prompt (required) |
| `--name` | `-n` | Task name for tracking |
| `--workdir` | `-w` | Working directory |
| `--agent-teams` | | Enable Agent Teams (parallel sub-agents) |
| `--permission-mode` | | Permission mode (default: dangerously-skip-permissions) |
| `--allowed-tools` | | Comma-separated allowed tools |
| `--model` | | Override model |

## Result Format (latest.json)

```json
{
  "session_id": "abc123",
  "timestamp": "2026-03-10T01:00:00+00:00",
  "cwd": "/path/to/project",
  "event": "Stop",
  "task_name": "my-task",
  "status": "done",
  "output": "Claude Code's output summary..."
}
```

## Reading Results (from OpenClaw)

When the wake event arrives, read the result:

```bash
cat ~/workspace/claw/agents/claude-code-results/latest.json | jq .
```

## Hook Configuration (already set up)

`~/.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/notify-agi.sh", "timeout": 30}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/notify-agi.sh", "timeout": 30}]}]
  }
}
```

Both Stop and SessionEnd hooks fire — the script deduplicates with a 30-second lock file to prevent double notifications.

## Dual Channel Design

| Only latest.json | Only wake event | Both (our approach) |
|-------------------|-----------------|---------------------|
| Result saved, but AGI doesn't know | AGI wakes up, but no details | AGI wakes instantly + reads full result ✅ |
| Waits for heartbeat (~30 min) | Wake text has length limit | Real-time + complete |

## Fault Tolerance

- Wake event fails? latest.json is still there — AGI picks it up on next heartbeat
- Hook fires twice? Lock file deduplicates within 30 seconds
- Claude Code crashes? SessionEnd hook still fires

## Tips

1. **Don't poll** — the whole point is zero polling. Just dispatch and wait for the hook.
2. **Check latest.json** — if you need to manually check status
3. **Agent Teams** — use `--agent-teams` for complex tasks that benefit from parallel sub-agents
4. **Multiple tasks** — dispatch multiple tasks to different workdirs; each writes its own task-meta.json
