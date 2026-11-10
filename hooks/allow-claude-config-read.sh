#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# allow-claude-config-read.sh — PreToolUse hook (matcher: Read|Glob|Grep)
# Auto-approves READ-ONLY tool calls (Read, Glob, Grep) whose target path is inside
# ~/.claude/agents or ~/.claude/skills, or that is ~/.claude/settings.json. Nothing else is touched: no writes, no Bash,
# no other folder. Added because the permission prompt for ~/.claude/agents was not
# silenced by allow rules or additionalDirectories (the orchestrator's sub-agents read
# their own definitions there and every read stopped the run until a human clicked).
#
# Any path that is missing, unparseable, outside those two folders, or that escapes them
# through `..` falls through with no output (exit 0), so the normal permission flow runs.

INPUT=$(cat)

echo "$INPUT" | "$PY" -c "
import sys, json, os, re

def norm(p):
    p = os.path.normpath(p.replace('\\\\', '/')).replace('\\\\', '/').lower()
    m = re.match(r'^/([a-z])/(.*)$', p)          # /c/Users/... -> c:/users/...
    if m:
        p = m.group(1) + ':/' + m.group(2)
    return p

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if data.get('tool_name') not in ('Read', 'Glob', 'Grep'):
    sys.exit(0)

ti = data.get('tool_input') or {}
target = ti.get('file_path') or ti.get('path') or ''
if not isinstance(target, str) or not target.strip():
    sys.exit(0)                                   # Glob/Grep with no path = the cwd, not ours

base = norm(os.path.join(os.path.expanduser('~'), '.claude'))
t = norm(target)
if t == base + '/settings.json':
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'allow',
        'permissionDecisionReason': 'Read-only access to ~/.claude/settings.json (allow-claude-config-read hook)'}}))
    sys.exit(0)
for sub in ('agents', 'skills'):
    root = base + '/' + sub
    if t == root or t.startswith(root + '/'):
        print(json.dumps({'hookSpecificOutput': {
            'hookEventName': 'PreToolUse',
            'permissionDecision': 'allow',
            'permissionDecisionReason': 'Read-only access to ~/.claude/' + sub + ' (allow-claude-config-read hook)'}}))
        break
" 2>/dev/null

exit 0
