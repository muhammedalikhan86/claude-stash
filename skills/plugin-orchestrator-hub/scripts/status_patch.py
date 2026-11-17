"""Patch a status page's status.json in place (plugin-orchestrator-hub). Numbers only: every other
field (the stakeholder wording) is kept as it is.

usage, from the PMBooks (the normal way; the PMBook is the only source of sizes):
    python -I status_patch.py --hub <hub checkout> <YYYY-MM-DD> "<log line>" [<cross-check spec> ...] [--rebase] [--dry-run] [--status <file>]

  Each component's done points, open points and open items are counted from its PMBooks on the hub's
  main branch (pmbook_points.py) and written as they are. The change in done points since the last
  patch feeds the velocity series and rates. A cross-check spec (the delta the hub expected, same
  shape as below) changes nothing; a disagreement with the PMBook is printed as CROSS-CHECK. --rebase
  writes the PMBook counts without moving the series or rates (the first PMBook patch, or a recount
  the user asked for). --dry-run prints the counts and writes nothing. --status patches that file
  instead of hub.json's status page (a copy, to try it).

usage, legacy deltas (a page with no PMBooks behind it):
    python -I status_patch.py <status.json> <YYYY-MM-DD> "<log line>" "<component>:<done>:<remaining>:<total>:<items>" ...

<component> is the component's name on the page (hub.json components[].statusName).
Every run stamps updatedAt (local time, with offset) and appends a log entry {at, change, pointsDone|pointsRaised}.
Rates: rateWhole += done / wholePeriodWorkingDays. rateLast10 and velocity.pointsPerWorkingDay are left as
the page's owner set them; new points never move them.
Forecast: ceil(remaining / rate) working days (Mon-Fri) counted from the next working day after the date.
The file shape it expects is in references/status-page.md.
"""
import json, os, sys, math, datetime as dt

argv = sys.argv[1:]
rebase = '--rebase' in argv
dry = '--dry-run' in argv
argv = [a for a in argv if a not in ('--rebase', '--dry-run')]
status_override = None
if '--status' in argv:  # a status.json other than hub.json's (a copy, to try a patch)
    i = argv.index('--status'); status_override = argv[i + 1]; del argv[i:i + 2]


def parse_spec(arg):
    name, done, rem, tot, items = arg.rsplit(':', 4)
    return name, float(done), float(rem), float(tot), int(items)


deltas = []  # (name, done, rem, tot, items) to apply
if argv and argv[0] == '--hub':
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pmbook_points as pm
    root, day, note = argv[1], argv[2], argv[3]
    cfg, rev, comps_cfg = pm.components(root)
    st = cfg.get('status', {})
    path = status_override or os.path.join(root, st['repo'], st.get('file', 'status.json'))
    d = json.load(open(path, encoding='utf-8'))
    page = {c['name']: c for c in d['components']}
    expected = {n: (dn, rm, tt, it) for n, dn, rm, tt, it in map(parse_spec, argv[4:])}
    for c, books in comps_cfg:
        name = c['statusName']
        if name not in page:
            sys.exit(f'{name!r} (hub.json statusName) is not on the page; the page has: {", ".join(page)}')
        r = pm.count(root, rev, books)
        old = page[name]
        dd = r['done'] - old['pointsDone']
        dr = r['open'] - old['pointsRemaining']
        dt_ = (r['done'] + r['open']) - old['pointsTotal']
        di = r['items'] - old['itemsRemaining']
        print(f"{name}: done {r['done']:g} ({dd:+g}), open {r['open']:g} ({dr:+g}), "
              f"items {r['items']} ({di:+d})")
        for k in ('unsizedOpen', 'unsizedDone', 'uncounted'):
            if r[k]:
                print(f'  {k} ({len(r[k])}): ' + '; '.join(r[k][:8]) + (' ...' if len(r[k]) > 8 else ''))
        exp = expected.pop(name, None)
        if exp is not None and exp != (dd, dr, dt_, di):
            print(f'  CROSS-CHECK: expected {exp[0]:g}:{exp[1]:g}:{exp[2]:g}:{exp[3]}, the PMBook says '
                  f'{dd:g}:{dr:g}:{dt_:g}:{di}. The PMBook wins.')
        deltas.append((name, dd, dr, dt_, di))
    for n in expected:
        print(f'CROSS-CHECK: {n!r} is not a counted component')
    if dry:
        sys.exit(0)
else:
    path, day, note = argv[0], argv[1], argv[2]
    d = json.load(open(path, encoding='utf-8'))
    deltas = [parse_spec(a) for a in argv[3:]]

v, f = d['velocity'], d['forecast']
nw = v['wholePeriodWorkingDays']
comps = {c['name']: c for c in d['components']}
added = 0.0
scope = 0.0
for name, done, rem, tot, items in deltas:
    if name not in comps:
        sys.exit(f'unknown component {name!r}; the page has: {", ".join(comps)}')
    c = comps[name]
    c['pointsDone'] += done; c['pointsRemaining'] += rem; c['pointsTotal'] += tot; c['itemsRemaining'] += items
    if rebase:
        continue
    pc = f['perComponent'][name]
    pc['rateWhole'] = round(pc['rateWhole'] + done / nw, 2)
    added += done; scope += tot

s = v['series']
if s[-1]['date'] != day:
    s.append({'date': day, 'pointsDone': s[-1]['pointsDone'], 'pointsDoneThatDay': 0.0})
s[-1]['pointsDone'] += added; s[-1]['pointsDoneThatDay'] += added
d['asOf'] = day
now = dt.datetime.now().astimezone().replace(microsecond=0).isoformat()
d['updatedAt'] = now
entry = {'at': now, 'change': note + (' (recount from the PMBooks)' if rebase else '')}
if added: entry['pointsDone'] = added
if scope: entry['pointsRaised'] = scope
if not added and not scope: entry['pointsDone'] = 0.0
d.setdefault('log', []).append(entry)
v['pointsPerWorkingDayWholePeriod'] = round(v['pointsPerWorkingDayWholePeriod'] + added / nw, 2)

def add_wd(start, n):
    x = start
    while x.weekday() >= 5: x += dt.timedelta(1)
    k = 1
    while k < n:
        x += dt.timedelta(1)
        if x.weekday() < 5: k += 1
    return x

nxt = dt.date.fromisoformat(day) + dt.timedelta(1)
def when(rem, rate):
    if rate <= 0: return None
    return add_wd(nxt, max(1, math.ceil(rem / rate))).isoformat()

for name, pc in f['perComponent'].items():
    if name not in comps: continue
    rem = comps[name]['pointsRemaining']; a, b = pc['rateLast10'], pc['rateWhole']
    pc['optimistic'], pc['likely'], pc['pessimistic'] = when(rem, a), when(rem, (a + b) / 2), when(rem, b)
o = f['overall']
o['rateLast10'], o['rateWhole'] = v['pointsPerWorkingDay'], v['pointsPerWorkingDayWholePeriod']
o['pointsRemaining'] = sum(c['pointsRemaining'] for c in d['components'])
o['itemsRemaining'] = sum(c['itemsRemaining'] for c in d['components'])
for k in ('optimistic', 'likely', 'pessimistic'):
    known = [pc[k] for pc in f['perComponent'].values() if pc[k]]
    o[k] = max(known) if known else None
for m in d.get('milestones', []):
    if m['kind'] == 'forecast':
        for name in comps:
            if m['name'].startswith(name + ' build complete'): m['date'] = f['perComponent'][name]['likely']
        if m['name'] == 'Build complete (likely)': m['date'] = o['likely']
for p in d.get('phases', []):
    if p['name'] == 'Build': p['end'] = o['likely']
json.dump(d, open(path, 'w', encoding='utf-8', newline='\n'), indent=1, ensure_ascii=False)
open(path, 'a', encoding='utf-8', newline='\n').write('\n')
print('series', s[-1], 'overall', {k: o[k] for k in ('optimistic', 'likely', 'pessimistic', 'pointsRemaining', 'itemsRemaining')})
for name, pc in f['perComponent'].items(): print(name, pc['optimistic'], pc['likely'], pc['pessimistic'])
