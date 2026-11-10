#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# loop-detection.sh — PostToolUse hook (matcher: Edit|Write)
# Doom-loop guard: counts repeated edits to the same file within a session and
# nudges a rethink once the count crosses a threshold. Counts are per full path
# (slash direction and case normalised), never per file name, so two files both
# called SKILL.md are counted apart. Markdown under a docs/ folder is skipped:
# governed docs (PRD, Architecture, PMBook) are edited turn after turn by design.
# Ported from
# sangrokjung/claude-forge (hooks/loop-detection.sh), kept close to the
# original — it was already self-contained and dependency-light.
#
# Exit contract: PostToolUse cannot block. Always exit 0. To surface a message
# to Claude, emit {"hookSpecificOutput": {"hookEventName": "PostToolUse",
# "additionalContext": "..."}} as JSON on stdout — plain stdout text is NOT
# delivered to Claude's context on this event (verified against current
# Claude Code hook docs).

set -euo pipefail

INPUT=$(cat)

read -r TOOL_NAME PAYLOAD_SID FILE_PATH <<< "$("$PY" -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    tool = data.get('tool_name', '') or '-'
    sid = data.get('session_id', '') or '-'
    fp = data.get('tool_input', {}).get('file_path', '')
    print(f'{tool} {sid} {fp}')
except Exception:
    print('- - ')
" <<< "$INPUT" 2>/dev/null || echo '- - ')"

[[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]] && exit 0
[[ -z "$FILE_PATH" ]] && exit 0

SESSION_ID="$PAYLOAD_SID"
if [[ -z "$SESSION_ID" || "$SESSION_ID" == "-" ]]; then
    SESSION_ID="${CLAUDE_SESSION_ID:-}"
fi
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="$(date +%Y%m%d)"
fi
SESSION_ID="${SESSION_ID//[^A-Za-z0-9_-]/_}"
TRACK_FILE="/tmp/claude-loop-detect-${SESSION_ID}.jsonl"

# One key per file: forward slashes, lower case (Windows paths arrive as both
# C:\x and c:/x).
KEY="${FILE_PATH//\\//}"
KEY="${KEY,,}"

# Governed docs: Markdown anywhere under a docs/ folder is edited on purpose,
# turn after turn. Not a loop.
if [[ "$KEY" == *.md && ( "$KEY" == docs/* || "$KEY" == */docs/* ) ]]; then
    exit 0
fi

COUNT=0
if [[ -f "$TRACK_FILE" ]]; then
    COUNT=$(grep -cF "\"$KEY\"" "$TRACK_FILE" 2>/dev/null || true)
    COUNT=${COUNT:-0}
fi

echo "{\"file\":\"$KEY\",\"ts\":\"$(date -u +%FT%TZ)\",\"tool\":\"$TOOL_NAME\"}" >> "$TRACK_FILE"
COUNT=$((COUNT + 1))

MSG=""
if [[ $COUNT -ge 10 ]]; then
    MSG="[Loop Detection] '$FILE_PATH' has been edited ${COUNT} times this session - possible doom loop. Suggested: (1) check git diff for what actually changed (2) look for the root cause in a different file (3) reconsider the approach entirely."
elif [[ $COUNT -ge 5 ]]; then
    MSG="[Loop Detection] '$FILE_PATH' has been edited ${COUNT} times. You're repeatedly editing the same file - consider a different approach."
fi

if [[ -n "$MSG" ]]; then
    MSG="$MSG" "$PY" -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': os.environ['MSG']}}, ensure_ascii=False))
"
fi

exit 0
