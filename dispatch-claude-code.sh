#!/bin/bash
# dispatch-claude-code.sh — 一鍵派發任務到 Claude Code
# 發射後不管，完成自動通知 OpenClaw AGI
#
# 用法：
#   dispatch-claude-code.sh \
#     -p "實現一個 Python 爬蟲" \
#     -n "my-scraper" \
#     -w "/path/to/project" \
#     [--agent-teams] \
#     [--permission-mode bypassPermissions]

set -euo pipefail

# === 預設值 ===
PROMPT=""
TASK_NAME="unnamed-task"
WORKDIR="$(pwd)"
AGENT_TEAMS=false
PERMISSION_MODE="dangerously-skip-permissions"
ALLOWED_TOOLS=""
MODEL=""

# === 解析參數 ===
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--prompt) PROMPT="$2"; shift 2 ;;
    -n|--name) TASK_NAME="$2"; shift 2 ;;
    -w|--workdir) WORKDIR="$2"; shift 2 ;;
    --agent-teams) AGENT_TEAMS=true; shift ;;
    --permission-mode) PERMISSION_MODE="$2"; shift 2 ;;
    --allowed-tools) ALLOWED_TOOLS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$PROMPT" ]; then
  echo "Error: --prompt is required"
  echo "Usage: dispatch-claude-code.sh -p 'Your task' -n 'task-name' -w '/path/to/project'"
  exit 1
fi

# === 確保工作目錄存在 ===
mkdir -p "$WORKDIR"

# === 寫入任務 metadata ===
cat > "$WORKDIR/.claude-task-meta.json" << JSONEOF
{
  "task_name": "$TASK_NAME",
  "prompt": $(echo "$PROMPT" | jq -Rs .),
  "workdir": "$WORKDIR",
  "agent_teams": $AGENT_TEAMS,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
}
JSONEOF

# === 組裝 Claude Code 命令 ===
CMD="claude"
CMD="$CMD --$PERMISSION_MODE"
CMD="$CMD -p"

if [ "$AGENT_TEAMS" = true ]; then
  CMD="$CMD --agent-teams"
fi

if [ -n "$ALLOWED_TOOLS" ]; then
  CMD="$CMD --allowed-tools $ALLOWED_TOOLS"
fi

if [ -n "$MODEL" ]; then
  CMD="$CMD --model $MODEL"
fi

# === 啟動（背景執行，stdout 寫入 task-output.txt） ===
echo "🚀 Dispatching task: $TASK_NAME"
echo "📁 Workdir: $WORKDIR"
echo "🤖 Agent Teams: $AGENT_TEAMS"
echo "📝 Prompt: ${PROMPT:0:100}..."
echo ""

cd "$WORKDIR"

# 使用 nohup 背景執行，output 寫檔
nohup bash -c "$CMD '$PROMPT' > '$WORKDIR/.claude-task-output.txt' 2>&1" &
CLAUDE_PID=$!

echo "✅ Claude Code launched (PID: $CLAUDE_PID)"
echo "📄 Output: $WORKDIR/.claude-task-output.txt"
echo "📊 Results: ~/workspace/claw/agents/claude-code-results/latest.json"
echo ""
echo "Hook will auto-notify OpenClaw when done. You can walk away now. 🎯"
