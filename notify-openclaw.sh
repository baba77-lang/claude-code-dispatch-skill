#!/bin/bash
set -euo pipefail

META_FILE=""
EVENTS_FILE=""
LAST_MESSAGE_FILE=""
OUTPUT_FILE=""
EXIT_CODE="1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --meta) META_FILE="$2"; shift 2 ;;
    --events) EVENTS_FILE="$2"; shift 2 ;;
    --last-message) LAST_MESSAGE_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --exit-code) EXIT_CODE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

RESULTS_DIR="$HOME/workspace/claw/agents/codex-cli-results"
LATEST_FILE="$RESULTS_DIR/latest.json"
mkdir -p "$RESULTS_DIR"

TASK_NAME="unknown"
WORKDIR="$(pwd)"
MODEL=""
SANDBOX=""
APPROVAL=""
STARTED_AT=""
if [[ -f "$META_FILE" ]]; then
  TASK_NAME=$(jq -r '.task_name // "unknown"' "$META_FILE")
  WORKDIR=$(jq -r '.workdir // ""' "$META_FILE")
  MODEL=$(jq -r '.model // ""' "$META_FILE")
  SANDBOX=$(jq -r '.sandbox // ""' "$META_FILE")
  APPROVAL=$(jq -r '.approval // ""' "$META_FILE")
  STARTED_AT=$(jq -r '.started_at // ""' "$META_FILE")
fi

THREAD_ID=""
if [[ -f "$EVENTS_FILE" ]]; then
  THREAD_ID=$(jq -r 'select(.type == "thread.started") | .thread_id' "$EVENTS_FILE" 2>/dev/null | tail -1)
fi

FINAL_MESSAGE=""
if [[ -f "$LAST_MESSAGE_FILE" ]]; then
  FINAL_MESSAGE=$(cat "$LAST_MESSAGE_FILE")
fi
if [[ -z "$FINAL_MESSAGE" && -f "$OUTPUT_FILE" ]]; then
  FINAL_MESSAGE=$(tail -c 4000 "$OUTPUT_FILE")
fi

STATUS="done"
if [[ "$EXIT_CODE" != "0" ]]; then
  STATUS="failed"
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

cat > "$LATEST_FILE" <<JSONEOF
{
  "thread_id": $(printf '%s' "$THREAD_ID" | jq -Rs .),
  "timestamp": "$TIMESTAMP",
  "started_at": $(printf '%s' "$STARTED_AT" | jq -Rs .),
  "cwd": $(printf '%s' "$WORKDIR" | jq -Rs .),
  "task_name": $(printf '%s' "$TASK_NAME" | jq -Rs .),
  "model": $(printf '%s' "$MODEL" | jq -Rs .),
  "sandbox": $(printf '%s' "$SANDBOX" | jq -Rs .),
  "approval": $(printf '%s' "$APPROVAL" | jq -Rs .),
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "events_file": $(printf '%s' "$EVENTS_FILE" | jq -Rs .),
  "last_message_file": $(printf '%s' "$LAST_MESSAGE_FILE" | jq -Rs .),
  "output_file": $(printf '%s' "$OUTPUT_FILE" | jq -Rs .),
  "output": $(printf '%s' "$FINAL_MESSAGE" | tail -c 3000 | jq -Rs .)
}
JSONEOF

WAKE_MSG="Codex CLI 完成: task=$TASK_NAME status=$STATUS cwd=$WORKDIR"
openclaw system event --text "$WAKE_MSG" --mode now 2>/dev/null || true

echo "$LATEST_FILE"
