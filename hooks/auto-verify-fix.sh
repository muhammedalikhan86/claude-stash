#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# auto-verify-fix.sh — PostToolUse hook (matcher: Edit|Write)
# Lightweight type/syntax check right after a code edit (tsc --noEmit for TS
# projects, py_compile for Python) so a broken edit surfaces immediately
# instead of waiting for a later Reviewer/Integration pass to catch it.
# Ported from sangrokjung/claude-forge (hooks/auto-verify-fix.sh), unchanged —
# it was already self-contained, dependency-light, and fail-quiet by design.
#
# Exit contract: PostToolUse cannot block. Always exit 0. Errors are surfaced
# via {"hookSpecificOutput": {"hookEventName": "PostToolUse",
# "additionalContext": "..."}} JSON on stdout, never via exit code or plain
# stdout (verified against current Claude Code hook docs — plain stdout is
# not delivered to Claude's context on this event).

INPUT=$(cat)

echo "$INPUT" | "$PY" -c "
import sys, json, os, subprocess, hashlib, re, time, tempfile

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

tool = d.get('tool_name', '')
if tool not in ('Edit', 'Write'):
    sys.exit(0)

inp = d.get('tool_input', {})
file_path = inp.get('file_path', '')
if not file_path or not os.path.isfile(file_path):
    sys.exit(0)

ext = os.path.splitext(file_path)[1].lower()
if ext not in ('.ts', '.tsx', '.js', '.jsx', '.py'):
    sys.exit(0)

search_dir = os.path.dirname(os.path.abspath(file_path))
project_root = search_dir
for _ in range(10):
    if os.path.exists(os.path.join(project_root, 'tsconfig.json')) or \
       os.path.exists(os.path.join(project_root, 'package.json')):
        break
    parent = os.path.dirname(project_root)
    if parent == project_root:
        project_root = search_dir
        break
    project_root = parent

is_python = (ext == '.py')
has_tsconfig = os.path.exists(os.path.join(project_root, 'tsconfig.json'))

if is_python:
    try:
        r = subprocess.run(
            [sys.executable, '-m', 'py_compile', file_path],
            capture_output=True, text=True, timeout=8
        )
    except:
        sys.exit(0)
elif has_tsconfig:
    try:
        r = subprocess.run(
            ['bash', '-c', 'npx tsc --noEmit --pretty \"' + file_path + '\" 2>&1 | head -30'],
            capture_output=True, text=True, timeout=8,
            cwd=project_root
        )
    except:
        sys.exit(0)
else:
    sys.exit(0)

output = (r.stdout + r.stderr).strip()
if r.returncode == 0 or not output:
    sys.exit(0)

sid = (d.get('session_id')
       or os.environ.get('CLAUDE_SESSION_ID')
       or os.environ.get('SESSION_ID')
       or 'unknown')
sid = re.sub(r'[^A-Za-z0-9_-]', '_', str(sid))
path_hash = hashlib.md5(file_path.encode()).hexdigest()
marker = os.path.join(tempfile.gettempdir(), f'auto-verify-fix-{sid}-{path_hash}')

MARKER_TTL_SEC = 6 * 3600

count = 0
if os.path.exists(marker):
    try:
        if (time.time() - os.path.getmtime(marker)) <= MARKER_TTL_SEC:
            count = int(open(marker).read().strip())
    except Exception:
        count = 0
count += 1
try:
    open(marker, 'w').write(str(count))
except:
    pass

basename = os.path.basename(file_path)
if count > 3:
    sys.exit(0)

FIXABLE = [
    r'Cannot find name',
    r'is declared but',
    r'React Hook.*cannot be called',
    r'Module.*not found',
    r'Cannot find module',
    r'has no exported member',
]

messages = []
seen = set()
for line in output.split('\n')[:30]:
    line = line.strip()
    if not line or line in seen:
        continue
    has_err = 'error' in line.lower() or 'SyntaxError' in line
    if not has_err:
        continue
    seen.add(line)
    if any(re.search(p, line) for p in FIXABLE):
        messages.append(f'[auto-fix] {line} -> fix this file.')
    else:
        messages.append(f'[verify-warn] {line} -> needs manual check.')

if not messages:
    sys.exit(0)

ctx = (
    f'[verify hook - auto-verify-fix] Verification errors found in the file you just edited ({basename}):\n'
    + '\n'.join(messages[:10])
    + '\nNon-blocking signal - review and fix the errors above.'
)
out = {'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': ctx}}
print(json.dumps(out, ensure_ascii=False))
" 2>/dev/null

exit 0
