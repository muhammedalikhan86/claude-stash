#!/usr/bin/env bash
# Ensures an isolated PyMuPDF4LLM environment exists and is reasonably
# current, then converts the given PDF (or serves it from cache) and
# prints a single JSON result line to stdout. All setup/progress chatter
# goes to stderr so stdout stays parseable.
#
# Usage:
#   ensure_env.sh <pdf_path> [--force]   convert (or serve cached) <pdf_path>
#   ensure_env.sh --update-only          force a dependency update check, no conversion
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$SKILL_DIR/.venv"
MARKER="$SKILL_DIR/.last_update_check"
UPDATE_INTERVAL_DAYS=7

find_venv_python() {
  if [ -x "$VENV_DIR/Scripts/python.exe" ]; then
    echo "$VENV_DIR/Scripts/python.exe"
  elif [ -x "$VENV_DIR/bin/python" ]; then
    echo "$VENV_DIR/bin/python"
  fi
}

PY="$(find_venv_python || true)"

if [ -z "$PY" ]; then
  echo "[pdf-to-markdown] No environment found at $VENV_DIR — creating one..." >&2
  if command -v uv >/dev/null 2>&1; then
    uv venv --python 3.11 "$VENV_DIR" >&2
  elif command -v python3 >/dev/null 2>&1; then
    python3 -m venv "$VENV_DIR" >&2
  elif command -v python >/dev/null 2>&1; then
    python -m venv "$VENV_DIR" >&2
  fi
  PY="$(find_venv_python || true)"
fi

if [ -z "$PY" ]; then
  {
    echo "[pdf-to-markdown] ERROR: could not create a Python environment automatically."
    echo "Manual setup:"
    echo "  1. Install Python 3.11+ (https://python.org) or uv (https://astral.sh/uv)"
    echo "  2. Create the venv:   uv venv --python 3.11 \"$VENV_DIR\""
    echo "                        (or: python -m venv \"$VENV_DIR\")"
    echo "  3. Install the tool:  uv pip install --python \"$VENV_DIR\" pymupdf4llm"
    echo "                        (or: \"$VENV_DIR/Scripts/python\" -m pip install pymupdf4llm)"
    echo "  4. Re-run this skill once step 3 succeeds."
  } >&2
  echo '{"status":"error","message":"no python environment available"}'
  exit 1
fi

install_or_update() {
  local mode="$1"  # "install" or "update"
  if [ "$mode" = "install" ]; then
    echo "[pdf-to-markdown] Installing pymupdf4llm (deps: pymupdf, pymupdf-layout)..." >&2
  else
    echo "[pdf-to-markdown] Checking for a newer pymupdf4llm..." >&2
  fi
  if command -v uv >/dev/null 2>&1; then
    uv pip install -U --python "$PY" pymupdf4llm >&2
  else
    "$PY" -m pip install --quiet --upgrade pymupdf4llm >&2
  fi
  date -u +%Y-%m-%dT%H:%M:%SZ > "$MARKER"
}

if ! "$PY" -c "import pymupdf4llm" >/dev/null 2>&1; then
  if ! install_or_update install; then
    {
      echo "[pdf-to-markdown] ERROR: automatic install failed."
      echo "Try manually:  uv pip install --python \"$VENV_DIR\" pymupdf4llm"
      echo "          or:  \"$PY\" -m pip install pymupdf4llm"
    } >&2
    echo '{"status":"error","message":"pymupdf4llm install failed"}'
    exit 1
  fi
else
  NOW=$(date -u +%s)
  LAST=0
  if [ -f "$MARKER" ]; then
    LAST=$(date -u -d "$(cat "$MARKER")" +%s 2>/dev/null || echo 0)
  fi
  AGE_DAYS=$(( (NOW - LAST) / 86400 ))
  if [ "$AGE_DAYS" -ge "$UPDATE_INTERVAL_DAYS" ]; then
    install_or_update update || echo "[pdf-to-markdown] Update check failed, continuing with existing install." >&2
  fi
fi

if [ "${1:-}" = "--update-only" ]; then
  echo '{"status":"updated","message":"dependency check complete"}'
  exit 0
fi

exec "$PY" "$SKILL_DIR/scripts/convert_pdf.py" "$@"
