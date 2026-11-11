"""Checks what the repository really contains, without trusting the status columns people fill in by hand.

Run from the repo root:  python scripts/audit_progress.py
For every screen row of docs/design-traceability.md section 1 and 2 it checks that the widget class and its ViewModel exist in lib/,
that the route is registered, and that a test mentions the widget. It then counts commits per owner and per task, looks for
placeholders in the README and the docs, for the evidence folders and for the ARTEMIS cases that were really run.
"""
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.stdout.reconfigure(encoding='utf-8')


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8', errors='replace') as f:
        return f.read()


def walk(folder, ext):
    out = []
    for base, _, files in os.walk(os.path.join(ROOT, folder)):
        out += [os.path.join(base, f) for f in files if f.endswith(ext)]
    return out


def blob(files):
    return '\n'.join(open(p, encoding='utf-8', errors='replace').read() for p in files)


LIB = blob(walk('lib', '.dart'))
TEST = blob(walk('test', '.dart')) + blob(walk('integration_test', '.dart'))
ROUTES = read('lib/routing/routes.dart')

# ---------------------------------------------------------------- screens
rows = []
for line in read('docs/design-traceability.md').splitlines():
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if len(cells) >= 8 and re.fullmatch(r'[SK]\d\d', cells[0]):
        rows.append(cells)

print(f'== Screens ({len(rows)} rows, one per Figma code S/K without a state suffix)')
problems = defaultdict(list)
for code, name, route, widget, viewmodel, source, owner, status in [r[:8] for r in rows]:
    widget_name = re.match(r'[A-Za-z0-9_]+', widget)
    vm_name = re.match(r'[A-Za-z0-9_]+', viewmodel)
    checks = []
    if widget_name and widget_name.group(0)[0].isupper():
        w = widget_name.group(0)
        if f'class {w}' not in LIB:
            checks.append(f'widget {w} missing')
        if w not in TEST:
            checks.append(f'no test mentions {w}')
    if vm_name and vm_name.group(0)[0].isupper() and vm_name.group(0) not in ('Firebase',):
        v = vm_name.group(0)
        if f'class {v}' not in LIB:
            checks.append(f'ViewModel {v} missing')
        elif v not in TEST:
            checks.append(f'no test mentions {v}')
    if route.startswith('/') and not re.search(re.escape(route.split(':')[0].rstrip('/')) or '/', ROUTES + LIB):
        checks.append(f'route {route} not found')
    if checks:
        problems[owner].append(f'{code}: ' + '; '.join(checks))
if not problems:
    print('  every screen has its widget, ViewModel, route and a test that mentions it')
for owner in sorted(problems):
    print(f'  {owner}:')
    for p in problems[owner]:
        print('    -', p)

# ---------------------------------------------------------------- commits per person and per task
log = subprocess.run(['git', 'log', '--format=%an|%s'], cwd=ROOT, capture_output=True, text=True, encoding='utf-8').stdout.splitlines()
authors = Counter()
tasks = defaultdict(Counter)
for line in log:
    author, _, subject = line.partition('|')
    authors[author] += 1
    for t in re.findall(r'\[([A-Z]+-?\d+)\]', subject):
        tasks[t][author] += 1
print('\n== Commits per author (all branches merged to main)')
for a, n in authors.most_common():
    print(f'  {a:22s} {n}')
print('\n== Tasks with a commit that names them: ' + str(len(tasks)))
wanted = ['T01', 'T02', 'T22', 'T30', 'T31', 'T32', 'T33', 'T40', 'T41', 'T42', 'T43', 'T44', 'T45', 'T46', 'T50', 'T51',
          'T52', 'T53', 'T60', 'T61', 'T62', 'T63', 'T70', 'T71', 'T72', 'T80', 'T81', 'T82', 'T83']
missing = [t for t in wanted if t not in tasks]
print('  never named in a commit subject:', ', '.join(missing) or 'none')

# ---------------------------------------------------------------- placeholders
print('\n== Placeholders left in the documents')
for path in ['README.md', 'ASSIGNMENTS.md', 'TASKS.md'] + [f'docs/{f}' for f in sorted(os.listdir(os.path.join(ROOT, 'docs')))]:
    text = read(path)
    found = re.findall(r'\[(?:fill in[^\]]*|name, student ID|@…|N|date)\]|`\[[^`]*\]`', text)
    if found:
        print(f'  {path}: {len(found)} (for example {found[0][:50]})')

# ---------------------------------------------------------------- evidence
print('\n== Evidence folders (number of files)')
for sub in ['auth', 'crashlytics', 'remote-config', 'storage', 'fcm', 'analytics', 'artemis', 'code-review', 'p1', 'p2', 'p4', 'p5', 'figma']:
    folder = os.path.join(ROOT, 'evidence', sub)
    n = sum(len(f) for _, _, f in os.walk(folder)) if os.path.isdir(folder) else None
    print(f'  evidence/{sub:14s}', 'missing' if n is None else n)

# ---------------------------------------------------------------- tests
plan = read('docs/test-plan.md')
results = re.findall(r'^\| (TC-\d+) .*\| ([^|]*) \|\s*$', plan, re.M)
ran = [tc for tc, r in results if r.strip() and r.strip().lower() != 'not run']
print(f'\n== ARTEMIS: {len(results)} cases in the test plan, {len(ran)} with a result other than "Not run"')
print(f'   pytest functions in e2e_test/: {len(re.findall(r"async def test_", blob(walk("e2e_test", ".py"))))}')
print(f'   pass-rate table filled: {"yes" if os.path.exists(os.path.join(ROOT, "evidence/artemis/pass-rate.md")) else "no"}')

# ---------------------------------------------------------------- deliverables
print('\n== Deliverables')
for path in ['report', 'slides']:
    pdfs = [f for f in os.listdir(os.path.join(ROOT, path)) if f.endswith('.pdf')]
    print(f'  {path}/: {", ".join(pdfs) or "no PDF"}')
print('  README video link:', 'filled' if re.search(r'Demo video:\*\* https?://', read('README.md')) else 'not filled')
