"""Patch a status page's status.json in place with story-point deltas (plugin-orchestrator-hub).

usage: python -I status_patch.py <status.json> <YYYY-MM-DD> "<log line>" "<component>:<done>:<remaining>:<total>:<items>" ...

<component> is the component's name on the page (hub.json components[].statusName).
Every run stamps updatedAt (local time, with offset) and appends a log entry {at, change, pointsDone|pointsRaised}.
Rates: rateWhole += done / wholePeriodWorkingDays. rateLast10 and velocity.pointsPerWorkingDay are left as
the page's owner set them; new points never move them.
Forecast: ceil(remaining / rate) working days (Mon-Fri) counted from the next working day after the date.
The file shape it expects is in references/status-page.md.
"""
import json, sys, math, datetime as dt

path, day, note = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path, encoding='utf-8'))
v, f = d['velocity'], d['forecast']
nw = v['wholePeriodWorkingDays']
comps = {c['name']: c for c in d['components']}
added = 0.0
scope = 0.0
for arg in sys.argv[4:]:
    name, done, rem, tot, items = arg.rsplit(':', 4)
    if name not in comps:
        sys.exit(f'unknown component {name!r}; the page has: {", ".join(comps)}')
    c = comps[name]; done, rem, tot, items = float(done), float(rem), float(tot), int(items)
    c['pointsDone'] += done; c['pointsRemaining'] += rem; c['pointsTotal'] += tot; c['itemsRemaining'] += items
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
entry = {'at': now, 'change': note}
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
