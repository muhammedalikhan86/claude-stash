#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# session-clear-restore.sh — SessionStart hook (matcher: clear)
# Second half of the /summarise checkpoint. /summarise writes
# docs/sessions/latest.md and arms docs/sessions/.pending-reload; the user then
# types /clear (Claude cannot clear its own context). This hook fires in the
# fresh session and injects latest.md, and nothing else: topic files under
# docs/sessions/knowledge/ stay on disk until asked for.
#
# Consume-once: the flag is deleted after use, so a plain /clear with no fresh
# checkpoint gives a clean session as before. A flag older than 2 hours is
# stale and is dropped without loading.
#
# Exit contract: SessionStart never blocks. Always exit 0. Plain stdout on
# exit 0 is added to the new session's context.

INPUT="$(cat 2>/dev/null || true)"

# Parse cwd as real JSON (a Windows cwd arrives JSON-escaped) and hand it back
# with forward slashes so bash file tests work on it.
CWD=$(printf '%s' "$INPUT" | "$PY" -c "
import json, sys
try:
    print((json.load(sys.stdin).get('cwd', '') or '').replace('\\\\', '/'))
except Exception:
    print('')
" 2>/dev/null)
[ -z "$CWD" ] && exit 0

SESS="$CWD/docs/sessions"
FLAG="$SESS/.pending-reload"
LATEST="$SESS/latest.md"
MAX_CHARS=12000

[ -f "$FLAG" ] || exit 0

# Stale flag: the checkpoint is from an older stretch of work. Drop it.
if [ -n "$(find "$FLAG" -mmin +120 2>/dev/null)" ]; then
  rm -f "$FLAG" 2>/dev/null
  exit 0
fi

SUMMARY="$(head -1 "$FLAG" 2>/dev/null | tr -d '\r')"
rm -f "$FLAG" 2>/dev/null

if [ ! -s "$LATEST" ]; then
  printf '[Session restore] /summarise armed a reload, but docs/sessions/latest.md is missing or empty (cwd: %s).\n' "$CWD"
  printf 'Recovery: the summary file it wrote is %s. In your first reply, tell the user and offer to read that file, or to run /reload.\n' "${SUMMARY:-unknown}"
  exit 0
fi

printf '[Session restore] Context was cleared after a /summarise checkpoint. Loaded: docs/sessions/latest.md (CLAUDE.md loads as usual).\n'
printf 'Treat this as the authoritative continuity. Load a topic file in docs/sessions/knowledge/ only when the user asks or the next task needs it. Never reload transcripts or compacted history.\n'
printf 'Start your first reply with a 3-line "Context restored" note: Loaded, Current objective, Recommended next action.\n\n'
printf -- '----- docs/sessions/latest.md -----\n'
head -c "$MAX_CHARS" "$LATEST"
if [ "$(wc -c < "$LATEST")" -gt "$MAX_CHARS" ]; then
  printf '\n[...truncated at %s characters; read docs/sessions/latest.md for the rest. Tell the user latest.md has grown too big and the next /summarise should trim it.]\n' "$MAX_CHARS"
fi
printf '\n----- end -----\n'

exit 0
