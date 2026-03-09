# Claude Code Dispatch — Zero-Polling Hook Pattern for OpenClaw

🚀 Fire-and-forget Claude Code tasks with automatic result delivery via hooks.

## Problem

Traditional approach: OpenClaw polls Claude Code every few seconds → **massive token waste**.

## Solution

Dispatch once → Claude Code runs independently → Hook auto-notifies on completion → **Zero polling tokens**.

```
OpenClaw dispatches task
  │
  ├─ Writes task-meta.json
  ├─ Launches Claude Code (nohup background)
  │
  └─ OpenClaw is FREE (no polling!)
      │
      ⏳ (minutes later...)
      │
      Claude Code finishes → Stop Hook triggers
        ├─ Writes latest.json (full results)
        ├─ Sends openclaw wake event (instant)
        └─ Deduplicates (30s lock)
```

## Quick Start

### 1. Install Hook

```bash
# Copy hook script
cp notify-agi.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/notify-agi.sh

# Update Claude Code settings
# Add to ~/.claude/settings.json:
{
  "hooks": {
    "Stop": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/notify-agi.sh", "timeout": 30}]}],
    "SessionEnd": [{"hooks": [{"type": "command", "command": "~/.claude/hooks/notify-agi.sh", "timeout": 30}]}]
  }
}
```

### 2. Dispatch a Task

```bash
./dispatch-claude-code.sh \
  -p "Build a REST API with FastAPI" \
  -n "my-api" \
  -w ~/projects/my-api

# With Agent Teams (parallel sub-agents)
./dispatch-claude-code.sh \
  -p "Build a game with physics engine" \
  -n "physics-game" \
  -w ~/projects/game \
  --agent-teams
```

### 3. Results

Results auto-saved to `~/workspace/claw/agents/claude-code-results/latest.json`:

```json
{
  "session_id": "abc123",
  "timestamp": "2026-03-10T01:00:00+00:00",
  "task_name": "my-api",
  "status": "done",
  "output": "..."
}
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | OpenClaw skill definition |
| `notify-agi.sh` | Stop/SessionEnd hook (→ `~/.claude/hooks/`) |
| `dispatch-claude-code.sh` | Task dispatcher script |

## Dual Channel Design

| latest.json only | wake event only | Both ✅ |
|-------------------|-----------------|---------|
| Data saved, AGI doesn't know | AGI wakes, no details | Instant wake + full data |

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [OpenClaw](https://github.com/openclaw/openclaw)
- `jq` (for JSON processing)

## Credits

Inspired by [win4r/claude-code-hooks](https://github.com/win4r/claude-code-hooks) and [aivi.fyi tutorial](https://www.aivi.fyi/aiagents/OpenClaw-Agent-Teams).

## License

MIT
