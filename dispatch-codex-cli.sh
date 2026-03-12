#!/bin/bash
set -euo pipefail

PROMPT=""
TASK_NAME="unnamed-task"
WORKDIR="$(pwd)"
MODEL=""
SANDBOX="workspace-write"
APPROVAL="never"
ENABLE_SEARCH=false
SKIP_GIT_REPO_CHECK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--prompt) PROMPT="$2"; shift 2 ;;
    -n|--name) TASK_NAME="$2"; shift 2 ;;
    -w|--workdir) WORKDIR="$2"; shift 2 ;;
    -m|--model) MODEL="$2"; shift 2 ;;
    -s|--sandbox) SANDBOX="$2"; shift 2 ;;
    -a|--approval) APPROVAL="$2"; shift 2 ;;
    --search) ENABLE_SEARCH=true; shift ;;
    --skip-git-repo-check) SKIP_GIT_REPO_CHECK=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  echo "Error: --prompt is required"
  exit 1
fi

mkdir -p "$WORKDIR"
mkdir -p "$HOME/workspace/claw/agents/codex-cli-results"

PROMPT_FILE="$WORKDIR/.codex-task-prompt.txt"
META_FILE="$WORKDIR/.codex-task-meta.json"
EVENTS_FILE="$WORKDIR/.codex-task-events.jsonl"
LAST_MESSAGE_FILE="$WORKDIR/.codex-task-last-message.txt"
OUTPUT_FILE="$WORKDIR/.codex-task-output.txt"
RUNNER_FILE="$WORKDIR/.codex-task-runner.sh"
NOTIFIER="$HOME/workspace/claw/codex-cli-dispatch/scripts/notify-openclaw.sh"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

printf '%s' "$PROMPT" > "$PROMPT_FILE"

cat > "$META_FILE" <<JSONEOF
{
  "task_name": $(printf '%s' "$TASK_NAME" | jq -Rs .),
  "prompt_file": $(printf '%s' "$PROMPT_FILE" | jq -Rs .),
  "workdir": $(printf '%s' "$WORKDIR" | jq -Rs .),
  "model": $(printf '%s' "$MODEL" | jq -Rs .),
  "sandbox": $(printf '%s' "$SANDBOX" | jq -Rs .),
  "approval": $(printf '%s' "$APPROVAL" | jq -Rs .),
  "search": $ENABLE_SEARCH,
  "skip_git_repo_check": $SKIP_GIT_REPO_CHECK,
  "started_at": "$STARTED_AT"
}
JSONEOF

CODEx_CMD=(codex -a "$APPROVAL" exec --json --output-last-message "$LAST_MESSAGE_FILE" --sandbox "$SANDBOX" --cd "$WORKDIR")

if [[ -n "$MODEL" ]]; then
  CODEx_CMD+=(--model "$MODEL")
fi
if [[ "$ENABLE_SEARCH" == true ]]; then
  CODEx_CMD+=(--search)
fi
if [[ "$SKIP_GIT_REPO_CHECK" == true ]]; then
  CODEx_CMD+=(--skip-git-repo-check)
fi

cat > "$RUNNER_FILE" <<'BASH'
#!/bin/bash
set -euo pipefail
WORKDIR="$1"
PROMPT_FILE="$2"
EVENTS_FILE="$3"
LAST_MESSAGE_FILE="$4"
OUTPUT_FILE="$5"
META_FILE="$6"
NOTIFIER="$7"
shift 7
cd "$WORKDIR"
set +e
"$@" "$(cat "$PROMPT_FILE")" > >(tee "$OUTPUT_FILE") 2> >(tee -a "$OUTPUT_FILE" >&2) | tee "$EVENTS_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e
"$NOTIFIER" --meta "$META_FILE" --events "$EVENTS_FILE" --last-message "$LAST_MESSAGE_FILE" --output "$OUTPUT_FILE" --exit-code "$EXIT_CODE"
exit 0
BASH
chmod +x "$RUNNER_FILE"

nohup "$RUNNER_FILE" \
  "$WORKDIR" \
  "$PROMPT_FILE" \
  "$EVENTS_FILE" \
  "$LAST_MESSAGE_FILE" \
  "$OUTPUT_FILE" \
  "$META_FILE" \
  "$NOTIFIER" \
  "${CODEx_CMD[@]}" \
  >/dev/null 2>&1 &
PID=$!

printf '🚀 Codex CLI dispatched: %s\n' "$TASK_NAME"
printf '📁 Workdir: %s\n' "$WORKDIR"
printf '🧠 Sandbox: %s | Approval: %s\n' "$SANDBOX" "$APPROVAL"
printf '🆔 PID: %s\n' "$PID"
printf '📄 Events: %s\n' "$EVENTS_FILE"
printf '📝 Last message: %s\n' "$LAST_MESSAGE_FILE"
printf '📊 Result: %s\n' "$HOME/workspace/claw/agents/codex-cli-results/latest.json"
printf '✅ Zero-polling callback armed.\n'
