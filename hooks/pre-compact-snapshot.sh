#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# pre-compact-snapshot.sh — PreCompact hook
# Backs up per-project state files before /compact wipes them from context,
# and writes a small self-contained pointer (derived from `git status
# --short`, not a human-authored note) that post-compact-restore.sh reads
# back in on the other side of compaction.
#
# Adapted from sangrokjung/claude-forge (hooks/pre-compact-snapshot.sh).
# Simplified from the original: that version paired with a separate "relay"
# skill that writes a hand-authored next-task pointer elsewhere in the
# pipeline; nothing in this setup writes that pointer, so re-using it as-is
# would make the restore half permanently a no-op. This version derives its
# own pointer from `git status --short` instead — always available, needs no
# other skill to cooperate.
#
# Exit contract: PreCompact exit 2 blocks compaction. This hook only ever
# snapshots, never has reason to block, so it always exits 0 (fails silently
# on any error, per the original design).

set -o pipefail

INPUT=$(cat)

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
if [ -z "$CWD" ]; then
  exit 0
fi

SNAPSHOT_DIR="$HOME/.claude/compact-snapshots"
mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || exit 0

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SAVED_FILES=""

# Back up hand-authored state files, if this project keeps any.
for FILE in plan.md todo.md decisions.md handoff.md; do
  SRC="$CWD/.claude/$FILE"
  if [ -f "$SRC" ]; then
    BASE="${FILE%.md}"
    cp "$SRC" "$SNAPSHOT_DIR/${BASE}-${TIMESTAMP}.md" 2>/dev/null
    if [ $? -eq 0 ]; then
      SAVED_FILES="${SAVED_FILES:+$SAVED_FILES, }$FILE"
    fi
  fi
done

# Self-contained pointer for post-compact-restore.sh: a snapshot of the
# working tree's uncommitted state, keyed by a hash of cwd. Only written if
# cwd is a git repo with something uncommitted — an empty/absent pointer
# means the restore hook has nothing to say, which is the correct outcome.
HASH=$("$PY" -c "import hashlib,sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest())" "$CWD" 2>/dev/null)
if [ -n "$HASH" ]; then
  POINTER="$SNAPSHOT_DIR/.pointer-${HASH}"
  CONSUMED="$SNAPSHOT_DIR/.pointer-${HASH}.consumed"
  rm -f "$CONSUMED" 2>/dev/null

  if STATUS=$(cd "$CWD" 2>/dev/null && git status --short 2>/dev/null) && [ -n "$STATUS" ]; then
    {
      echo "created=$(date -u +%FT%TZ)"
      echo "cwd=$CWD"
      echo "---"
      echo "$STATUS" | head -30
    } > "$POINTER" 2>/dev/null
  else
    # Nothing uncommitted — clear any stale pointer so restore doesn't fire on old state.
    rm -f "$POINTER" 2>/dev/null
  fi
fi

# Retention: drop snapshot files older than 7 days.
find "$SNAPSHOT_DIR" -name "*.md" -mtime +7 -delete 2>/dev/null

if [ -n "$SAVED_FILES" ]; then
  echo "[pre-compact] Snapshot saved: $SAVED_FILES" >&2
else
  echo "[pre-compact] No state files to back up" >&2
fi

exit 0
