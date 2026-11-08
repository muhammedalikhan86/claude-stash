#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# post-compact-restore.sh — SessionStart hook (matcher: compact)
# Reads back the pointer pre-compact-snapshot.sh wrote right before /compact
# ran, and re-injects it into context once (consume-once, TTL-expiring), so
# "what was uncommitted when compaction happened" doesn't just vanish with
# the rest of the pre-compact context.
#
# Adapted from sangrokjung/claude-forge (hooks/post-compact-restore.sh):
# simplified to drop the dependency on their separate `relay` skill/library
# (relay-lib.sh) — this reads the plain pointer file pre-compact-snapshot.sh
# in this setup writes directly, no other skill required.
#
# Why SessionStart(matcher: compact) and not the PostCompact event: current
# Claude Code docs do list PostCompact as a valid hook event, but its input/
# output schema isn't documented anywhere I could verify. SessionStart with
# matcher "compact" is fully documented (session_id/cwd/reason on stdin,
# plain-text stdout on exit 0 delivered straight into context) — deliberately
# using the proven path over the undocumented one.
#
# Exit contract: SessionStart never blocks. Always exit 0. On exit 0, plain
# stdout text (no JSON needed) is delivered into Claude's context — verified
# against current Claude Code hook docs.

set -o pipefail 2>/dev/null || true

INPUT="$(cat 2>/dev/null || true)"

# Parse cwd as real JSON rather than scraping it. A Windows cwd arrives
# JSON-escaped ("C:\Users\..."), and grep+sed never unescapes it - which both
# reports a wrong path to Claude and makes the cwd hash depend on the escaping.
CWD=$(printf '%s' "$INPUT" | "$PY" -c "
import json, sys
try:
    print(json.load(sys.stdin).get('cwd', '') or '')
except Exception:
    print('')
" 2>/dev/null)
[ -z "$CWD" ] && exit 0

SNAPSHOT_DIR="$HOME/.claude/compact-snapshots"
HASH="$("$PY" -c "import hashlib,sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest())" "$CWD" 2>/dev/null)"
[ -z "$HASH" ] && exit 0

POINTER="$SNAPSHOT_DIR/.pointer-${HASH}"
CONSUMED="$SNAPSHOT_DIR/.pointer-${HASH}.consumed"

[ -f "$POINTER" ] || exit 0
[ -f "$CONSUMED" ] && exit 0

# TTL: a pointer older than 6 hours is stale — the working tree has likely
# moved on since, so restoring it would mislead rather than help.
TTL_SEC=$((6 * 3600))
CREATED_LINE="$(head -1 "$POINTER" 2>/dev/null)"
CREATED="${CREATED_LINE#created=}"
NOW_EPOCH="$(date -u +%s)"
CREATED_EPOCH="$(date -u -d "$CREATED" +%s 2>/dev/null || echo 0)"
if [ "$CREATED_EPOCH" -eq 0 ] || [ $((NOW_EPOCH - CREATED_EPOCH)) -gt "$TTL_SEC" ]; then
  rm -f "$POINTER" 2>/dev/null
  exit 0
fi

STATUS_BLOCK="$(sed -n '/^---$/,$p' "$POINTER" | tail -n +2)"
[ -z "$STATUS_BLOCK" ] && exit 0

printf '[Post-compact restore] Working tree had uncommitted changes before compaction (cwd: %s):\n%s\nFull snapshot backups, if any, are in %s.\n' \
  "$CWD" "$STATUS_BLOCK" "$SNAPSHOT_DIR"

: > "$CONSUMED" 2>/dev/null || true

# Clean up other pointers older than 12h (excluding consumed markers, which
# are tiny and harmless to keep).
find "$SNAPSHOT_DIR" -maxdepth 1 -name '.pointer-*' ! -name '*.consumed' -mmin +720 -delete 2>/dev/null || true

exit 0
