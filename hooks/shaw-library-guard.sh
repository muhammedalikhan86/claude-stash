#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# shaw-library-guard.sh — PreToolUse hook (matcher: Bash|PowerShell|Monitor)
# Stops anything that would put a Shaw.* library change on the server before
# Muhammed has reviewed it (rule: ~/.claude/memory/shaw-library-changes-need-review.md):
#   1. a Release build/pack of anything under Libraries\ShawLibraries
#      (its PushNuGet target pushes the package to the internal feed),
#   2. running the PushNuGet target directly,
#   3. any `nuget push` / `dotnet nuget push`,
#   4. any TFVC check-in (`tf checkin` / `tf ci` / `tf vc checkin`).
# Shelving (`tf shelve`) and Debug builds stay allowed: a shelveset is the review unit.
#
# Hooks run in every permission mode, bypass included, and in subagents and
# every session that loads these user settings.
# Exit codes: 0 = allow, 2 = block (stderr goes back to Claude).

INPUT=$(cat)
export _SLG_INPUT="$INPUT"
"$PY" << 'SLG_SCRIPT'
import json, os, re, sys

try:
    data = json.loads(os.environ.get("_SLG_INPUT", ""))
except Exception:
    sys.exit(0)

cmd = str((data.get("tool_input") or {}).get("command") or "")
cwd = str(data.get("cwd") or "")
if not cmd:
    sys.exit(0)

text = cmd.replace("\\", "/")
low = text.lower()
in_libs = "shawlibraries" in low or "shawlibraries" in cwd.replace("\\", "/").lower() \
    or re.search(r"\bshaw\.[a-z0-9.]+\.(csproj|sln|slnx)\b", low)

def block(why):
    print(f"BLOCKED by shaw-library-guard: {why}", file=sys.stderr)
    print("Shaw library changes go branch/shelveset -> Muhammed's review -> merge. "
          "Hand Muhammed the review and the command; he runs it.", file=sys.stderr)
    sys.exit(2)

if re.search(r"\bnuget(\.exe)?[\"']?\s+push\b", low) or re.search(r"\bdotnet\s+nuget\s+push\b", low):
    block("nuget push publishes a package to the feed.")

if "pushnuget" in low:
    block("the PushNuGet target publishes a package to the feed.")

if re.search(r"\btf(\.exe)?[\"']?\s+(vc\s+)?(checkin|ci)\b", low):
    block("tf checkin puts the change on the TFS server.")

release = re.search(r"(-c|--configuration)[\s=:]+[\"']?release\b", low) \
    or re.search(r"[-/](p|property):\s*[\"']?configuration\s*=\s*[\"']?release\b", low)
builds = re.search(r"\b(dotnet|msbuild(\.exe)?|devenv(\.exe|\.com)?)\b", low)
if in_libs and release and builds:
    block("a Release build of a Shaw library pushes it to the NuGet feed.")

sys.exit(0)
SLG_SCRIPT
