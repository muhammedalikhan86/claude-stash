"""Count a component's story points from its PMBook(s) (plugin-orchestrator-hub).

The PMBook is the only source of sizes. This reads every item table (an ID column plus a Size or a
Status column) in the component's PMBooks (hub.json components[].statusPmbooks, else its pmbook) and
their closed tranches (<pmbook dir>/archive/*/project-management.md), at a git revision (the hub's main
branch), and sorts each row by its Status cell:

  done      Done, Fixed, Closed (any wording after them), and a Spike Log row with a Recommendation
            (one still `In progress`, or blank, is open)
  excluded  Withdrawn, Not needed, Folded, Moved, Split into, Duplicate, Superseded
  open      anything else (Planned, Open, In progress, Blocked, Deferred, Parked, ...)

A row with no number in its Size cell (or in a table with no Size column) is unsized: never counted,
always reported (an open one breaks the size-when-raised rule; a done one is sized at Finalization).
A table with a Size column but no Status column, other than the Spike Log, is reported, not counted.

usage (a check, nothing written):
    python -I pmbook_points.py <hub checkout> [<component name or statusName> ...]
"""
import json, os, re, subprocess, sys

DONE = re.compile(r'^(done|fixed|closed)\b')
EXCLUDED = re.compile(r'^(withdrawn|not needed|folded|moved|split into|duplicate|superseded)\b')


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
    section, header = '', None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith('#'):
            section, header = s.lstrip('#').strip(), None
            continue
        if not s.startswith('|'):
            header = None
            continue
        cells = [c.strip() for c in s.strip('|').split('|')]
        if header is None:
            header = [clean(c).lower() for c in cells]
            continue
        if set(s.replace('|', '').strip()) <= set('-: '):
            continue
        if 'id' in header and ('size' in header or 'status' in header):
            yield section, header, cells


def count(root, rev, pmbooks):
    out = {'done': 0.0, 'open': 0.0, 'items': 0, 'doneItems': 0,
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
            if not rid or (rid, f) in seen:
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
            if done:
                out['done'] += size; out['doneItems'] += 1
            else:
                out['open'] += size; out['items'] += 1
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
        for k in ('unsizedOpen', 'unsizedDone', 'uncounted'):
            if r[k]:
                print(f'  {k} ({len(r[k])}): ' + '; '.join(r[k][:12]) + (' ...' if len(r[k]) > 12 else ''))
