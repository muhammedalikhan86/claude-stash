#!/bin/bash
. "$(dirname "${BASH_SOURCE[0]}")/lib-python.sh"
# db-guard.sh — PreToolUse hook (matcher: mcp__.*)
# Blocks destructive SQL patterns before they reach any database MCP server:
# DROP TABLE/DATABASE/SCHEMA, TRUNCATE (DDL form), DELETE without WHERE,
# ALTER TABLE ... DROP COLUMN.
#
# Generalized from sangrokjung/claude-forge (hooks/db-guard.sh), which matched
# only Supabase's MCP tool names. This version is vendor-agnostic: wire it in
# settings.json against the broad matcher "mcp__.*" (as settings.template.json does) and let the script's
# own no-op-if-no-query-found check filter out every non-SQL tool call safely
# — so it doesn't need updating when you switch or add a DB MCP server.
#
# Exit codes: 0 = allow, 2 = block (PreToolUse: exit 2 blocks the call and
# sends stderr to Claude as feedback — verified against current Claude Code
# hook docs).

INPUT=$(cat)

QUERY=$(echo "$INPUT" | "$PY" -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print('')
    sys.exit(0)
ti = data.get('tool_input', {})
# Common field names across DB MCP servers: query, sql, statements, command.
# 'statements' or 'command' may be a list — join it so the regex checks below
# still see every statement.
val = ti.get('query') or ti.get('sql') or ti.get('statements') or ti.get('command') or ''
if isinstance(val, list):
    val = '\n'.join(str(v) for v in val)
print(val)
" 2>/dev/null)

if [[ -z "$QUERY" ]]; then
    # No SQL-shaped field found — not a DB write call (or an unrecognized
    # field name), allow rather than guess.
    exit 0
fi

export _DB_GUARD_QUERY="$QUERY"
"$PY" << 'DB_GUARD_SCRIPT'
import os
import sys
import re

query = os.environ.get("_DB_GUARD_QUERY", "")
if not query:
    sys.exit(0)

query_upper = query.upper()
safe_preview = query[:200]

if re.search(r'\bDROP\s+(TABLE|DATABASE|SCHEMA)\b', query_upper):
    print("BLOCKED: DROP statement detected", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

# TRUNCATE as a DDL statement (TRUNCATE TABLE foo / TRUNCATE foo / TRUNCATE foo, bar)
# vs. the GRANT/REVOKE privilege keyword TRUNCATE (e.g. "REVOKE ... TRUNCATE ... ON foo")
# — only the DDL form is blocked.
_truncate_ddl = re.search(r'\bTRUNCATE\s+(TABLE\s+|ONLY\s+|[A-Z_][A-Z0-9_]*\s*[(,;]|[A-Z_][A-Z0-9_]*\s*$)', query_upper)
if _truncate_ddl:
    print("BLOCKED: TRUNCATE statement detected", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

if re.search(r'\bDELETE\s+FROM\b', query_upper) and not re.search(r'\bWHERE\b', query_upper):
    print("BLOCKED: DELETE without WHERE clause", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

# DROP COLUMN is blocked; DROP CONSTRAINT/INDEX is allowed (e.g. removing a duplicate index).
if re.search(r'\bALTER\s+TABLE\b.*\bDROP\s+COLUMN\b', query_upper):
    print("BLOCKED: ALTER TABLE DROP COLUMN detected", file=sys.stderr)
    print(f"Query: {safe_preview}", file=sys.stderr)
    sys.exit(2)

sys.exit(0)
DB_GUARD_SCRIPT
