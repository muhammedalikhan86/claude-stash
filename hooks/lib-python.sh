#!/bin/bash
# lib-python.sh — shared interpreter resolution for the hooks in this directory.
# Sourced (not executed) by each hook; sets $PY to a Python that actually runs.
#
# Why this exists: on Windows, `python3` is usually the Microsoft Store
# app-execution-alias stub — it IS on PATH, so `command -v python3` succeeds,
# but running it prints an install advertisement and exits 49 without executing
# anything. Every hook here is fail-quiet by design, so a hook that trusts
# `command -v` becomes a silent no-op instead of an obvious error. Each
# candidate is therefore probed by actually executing it.
#
# The resolved name is cached, because probing costs up to two process spawns
# and these hooks run on every Edit/Write.

# Windows decodes the -c argument and the environment with the ANSI
# codepage unless UTF-8 mode is forced, which mangles non-ASCII output.
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

_py_cache="${TMPDIR:-/tmp}/.claude-hook-python"

PY=""
if [ -s "$_py_cache" ]; then
  _py_cached="$(cat "$_py_cache" 2>/dev/null)"
  if [ -n "$_py_cached" ] && command -v "$_py_cached" >/dev/null 2>&1; then
    PY="$_py_cached"
  fi
fi

if [ -z "$PY" ]; then
  for _cand in python3 python py; do
    if command -v "$_cand" >/dev/null 2>&1 && "$_cand" -c "import sys" >/dev/null 2>&1; then
      PY="$_cand"
      printf '%s' "$PY" > "$_py_cache" 2>/dev/null || true
      break
    fi
  done
fi

if [ -z "$PY" ]; then
  echo "[claude-hook] no working Python interpreter on PATH — hook skipped" >&2
  exit 0
fi
