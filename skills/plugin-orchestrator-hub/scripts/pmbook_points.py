"""Count a component's story points from its PMBook(s) (plugin-orchestrator-hub).

The PMBook is the only source of sizes. This reads every item table (an ID column plus a Size or a
Status column) in the component's PMBooks (hub.json components[].statusPmbooks, else its pmbook) and
their closed tranches (<pmbook dir>/archive/*/project-management.md), at a git revision (the hub's main
branch), and sorts each row by its Status cell:

  done      Done, Fixed, Closed (any wording after them), and a Spike Log row with a Recommendation
            (one still `In progress`, or blank, is open)
  excluded  Withdrawn, Not needed, Folded, Moved, Split into, Duplicate, Superseded
  open      anything else (Planned, Open, In progress, Blocked, Deferred, Parked, ...)

A row whose ID cell has no letter or digit (a note row, `| — | ... |`) is not an item and is skipped.
A row with no number in its Size cell (or in a table with no Size column) is unsized: never counted,
always reported (an open one breaks the size-when-raised rule; a done one is sized at Finalization).
A table with a Size column but no Status column, other than the Spike Log, is reported, not counted.
A row with the tag `[engineering]` in any cell (test speed-ups, test kits, tooling: no change a business
user sees) is counted apart, as found-during-build work (engDone, engOpen, engItems), never as product.

usage (a check, nothing written):
    python -I pmbook_points.py <hub checkout> [<component name or statusName> ...]
"""
import json, os, re, subprocess, sys

# Print UTF-8 on Windows too (a cp1252 console turns an em dash into a replacement character).
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, ValueError):
        pass

DONE = re.compile(r'^(done|fixed|closed)\b')
EXCLUDED = re.compile(r'^(withdrawn|not needed|folded|moved|split into|duplicate|superseded)\b')
ENGINEERING = '[engineering]'  # row tag: engineering-only work, shown as "found during build"


def git_show(root, rev, path):
    r = subprocess.run(['git', '-C', root, 'show', f'{rev}:{path}'], capture_output=True)
    return r.stdout.decode('utf-8', 'replace') if r.returncode == 0 else None


def archive_paths(root, rev, pmbook):
    base = os.path.dirname(pmbook).replace('\\', '/')
    r = subprocess.run(['git', '-C', root, 'ls-tree', '-r', '--name-only', rev, f'{base}/archive'],
                       capture_output=True)
    names = r.stdout.decode('utf-8', 'replace').splitlines() if r.returncode == 0 else []
    return sorted(n for n in names if re.fullmatch(re.escape(base) + r'/archive/[^/]+/project-management\.md', n))


def clean(cell):
    return re.sub(r'[*`_]', '', cell).strip()


def size_of(cell):
    m = re.match(r'\s*(\d+(?:\.\d+)?)', clean(cell))
    return float(m.group(1)) if m else None


def rows(text):
    """Yield (section, header, cells) for every row of an item table: an ID column plus a Size or a
    Status column (an Open Items table, with neither, is not an item table)."""
    section, header, last = '', None, None
    lines = text.splitlines()
    is_sep = lambda s: s.startswith('|') and set(s.replace('|', '').strip()) <= set('-: ')
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith('#'):
            section, header, last = s.lstrip('#').strip(), None, None
            continue
        if not s.startswith('|'):
            header = None
            continue
        cells = [c.strip() for c in s.strip('|').split('|')]
        if header is None:
            nxt = lines[i + 1].strip() if i + 1 < len(lines) else ''
            if is_sep(nxt) or last is None:
                header = last = [clean(c).lower() for c in cells]
                continue
            # A table broken by a blank line: rows with no header of their own continue the last
            # table in this section (they were silently dropped before).
            header = last
        if is_sep(s):
            continue
        if 'id' in header and ('size' in header or 'status' in header):
            yield section, header, cells


def count(root, rev, pmbooks):
    out = {'done': 0.0, 'open': 0.0, 'items': 0, 'doneItems': 0,
           'engDone': 0.0, 'engOpen': 0.0, 'engItems': 0, 'engDoneItems': 0,
           'unsizedOpen': [], 'unsizedDone': [], 'uncounted': [], 'files': []}
    files = []
    for p in pmbooks:
        files += archive_paths(root, rev, p) + [p]
    seen = set()
    for f in files:
        text = git_show(root, rev, f)
        if text is None:
            out['uncounted'].append(f'{f}: not found at {rev}')
            continue
        out['files'].append(f)
        for section, header, cells in rows(text):
            row = dict(zip(header, cells))
            rid = clean(row.get('id', ''))
            # A note row ("| — | Feature IDs are never reused ...") has no letter or digit in its ID cell.
            if not re.search(r'[A-Za-z0-9]', rid) or (rid, f) in seen:
                continue
            seen.add((rid, f))
            if 'status' in header:
                st = clean(row.get('status', '')).lower()
            elif section.lower().startswith('spike log'):
                rec = clean(row.get('recommendation', '')).lower()
                st = 'open' if rec in ('', '-', '—') or rec.startswith('in progress') else 'done'
            else:
                out['uncounted'].append(f'{f} §{section}: {rid} (no Status column)')
                continue
            if EXCLUDED.match(st):
                continue
            size = size_of(row.get('size', ''))
            done = bool(DONE.match(st))
            if size is None:
                (out['unsizedDone'] if done else out['unsizedOpen']).append(f'{rid} ({f})')
                continue
            eng = any(ENGINEERING in c.lower() for c in cells)
            pts, n = (('engDone', 'engDoneItems') if eng else ('done', 'doneItems')) if done else \
                     (('engOpen', 'engItems') if eng else ('open', 'items'))
            out[pts] += size; out[n] += 1
    return out


def components(root):
    cfg = json.load(open(os.path.join(root, '.claude', 'hub.json'), encoding='utf-8'))
    excl = set(cfg.get('status', {}).get('excludeComponents', []))
    rev = cfg.get('hub', {}).get('mainBranch', 'main')
    out = []
    for c in cfg['components']:
        if not c.get('statusName') or c['name'] in excl or c['statusName'] in excl:
            continue
        out.append((c, c.get('statusPmbooks') or [c['pmbook']]))
    return cfg, rev, out


if __name__ == '__main__':
    root = sys.argv[1]
    want = {w.lower() for w in sys.argv[2:]}
    cfg, rev, comps = components(root)
    for c, books in comps:
        if want and c['name'].lower() not in want and c['statusName'].lower() not in want:
            continue
        r = count(root, rev, books)
        print(f"{c['statusName']}: done {r['done']:g} ({r['doneItems']} items), open {r['open']:g} "
              f"({r['items']} items), total {r['done'] + r['open']:g}")
        if r['engDone'] or r['engOpen']:
            print(f"  found during build: done {r['engDone']:g} ({r['engDoneItems']} items), "
                  f"open {r['engOpen']:g} ({r['engItems']} items)")
        for k in ('unsizedOpen', 'unsizedDone', 'uncounted'):
            if r[k]:
                print(f'  {k} ({len(r[k])}): ' + '; '.join(r[k][:12]) + (' ...' if len(r[k]) > 12 else ''))
