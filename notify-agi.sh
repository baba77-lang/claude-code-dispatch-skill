#!/bin/bash
# Claude Code Hook — 任務完成自動通知 OpenClaw
# 觸發時機：Stop + SessionEnd（雙重保險）
# 功能：寫結果到 latest.json + 發 wake event 通知 AGI

set -euo pipefail

# === 防重複觸發（30 秒內去重） ===
LOCK_FILE="/tmp/.claude-hook-lock"
if [ -f "$LOCK_FILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -lt 30 ]; then
    exit 0
  fi
fi
touch "$LOCK_FILE"

# === 讀取 stdin JSON（Claude Code 傳入的 hook context） ===
HOOK_INPUT=""
if [ ! -t 0 ]; then
  HOOK_INPUT=$(cat)
fi

# === 環境變數 ===
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
CWD="${CLAUDE_CWD:-$(pwd)}"
EVENT="${CLAUDE_HOOK_EVENT:-Stop}"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S+00:00)

# === 讀取任務 metadata（如果有 dispatch 設定的話） ===
TASK_META_FILE="$CWD/.claude-task-meta.json"
TASK_NAME="unknown"
TELEGRAM_GROUP=""
if [ -f "$TASK_META_FILE" ]; then
  TASK_NAME=$(jq -r '.task_name // "unknown"' "$TASK_META_FILE" 2>/dev/null || echo "unknown")
  TELEGRAM_GROUP=$(jq -r '.telegram_group // ""' "$TASK_META_FILE" 2>/dev/null || echo "")
fi

# === 擷取 Claude Code 輸出（從 stdin 或 task-output.txt） ===
OUTPUT=""
TASK_OUTPUT_FILE="$CWD/.claude-task-output.txt"
if [ -n "$HOOK_INPUT" ]; then
  # 嘗試從 hook input JSON 擷取
  OUTPUT=$(echo "$HOOK_INPUT" | jq -r '.transcript // .stop_reason // .session_id // "completed"' 2>/dev/null || echo "completed")
fi
if [ -f "$TASK_OUTPUT_FILE" ]; then
  OUTPUT=$(cat "$TASK_OUTPUT_FILE" | tail -c 3000)
fi

# === 寫入結果 JSON ===
RESULTS_DIR="$HOME/workspace/claw/agents/claude-code-results"
mkdir -p "$RESULTS_DIR"
LATEST_FILE="$RESULTS_DIR/latest.json"

cat > "$LATEST_FILE" << JSONEOF
{
  "session_id": "$SESSION_ID",
  "timestamp": "$TIMESTAMP",
  "cwd": "$CWD",
  "event": "$EVENT",
  "task_name": "$TASK_NAME",
  "telegram_group": "$TELEGRAM_GROUP",
  "status": "done",
  "output": $(echo "$OUTPUT" | head -c 2000 | jq -Rs . 2>/dev/null || echo '"completed"')
}
JSONEOF

# === 發送 OpenClaw wake event（立即喚醒 AGI） ===
WAKE_MSG="Claude Code 完成: task=$TASK_NAME cwd=$CWD"
openclaw system event --text "$WAKE_MSG" --mode now 2>/dev/null || true

# === 清理 task meta ===
rm -f "$TASK_META_FILE" "$TASK_OUTPUT_FILE" 2>/dev/null || true

exit 0
