#!/usr/bin/env python3
"""One command for the navigation tests.   test_all.py [offline] [scummvm] [original] [flaky]   (default: offline scummvm flaky)
  offline   tier A in the Lua 3.1 of the game (20 s; FULL=1 adds the 364 walks of a run: 3 min)
  scummvm   the in-game suite on ScummVM (about a minute)
  flaky     the ScummVM suite twice more, in a shuffled order (two seeds): a case whose result changes is flaky or depends on another
  original  the in-game suite on the original (25 minutes) -- the recorded log of the last run is used when this is not given
Writes logs/navtest_summary.md and one line to logs/navtest_history.tsv."""
import os, re, subprocess, sys, time, shutil, datetime

AR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGS = os.path.join(AR, 'logs')
BASH = ['sh', '-c']
what = set(sys.argv[1:]) or {'offline', 'scummvm', 'flaky'}

def sh(cmd, timeout=3000):
    env = dict(os.environ)
    return subprocess.run(BASH + ['cd /c/Users/Joel/grim_tools/autorun && ' + cmd], env=env, capture_output=True, text=True, timeout=timeout).stdout

def parse(path, tag=''):
    r = {}
    if not os.path.exists(path):
        return r
    for line in open(path, errors='replace'):
        m = re.search(r'NAVTEST (unit|walk|move|coll|turn|slide|leak|rules) (\S+) (PASS|FAIL|KNOWN) ?(.*)', line)
        if m and 'AUTORUN' not in line.split('NAVTEST')[0]:
            r[(m.group(1), m.group(2) + ('@' + tag if m.group(1) == 'leak' else ''))] = (m.group(3), m.group(4)[:140])
    return r

def counts(r):
    c = {}
    for (tier, _), (res, _) in r.items():
        p, t = c.get(tier, (0, 0))
        c[tier] = (p + (res in ('PASS', 'KNOWN')), t + 1)
    return c

# the processes that run side by side on ScummVM: (name, test file, tiers of test_nav.lua)
GROUPS = [('unit', 'test_nav.lua', 'unit'), ('walk', 'test_nav.lua', 'walk'), ('move', 'test_nav.lua', 'move'), ('coll', 'test_nav.lua', 'coll'),
          ('misc', 'test_nav.lua', 'turn slide'), ('rules', 'test_rules.lua', None)]

def scummvm(tag, extra_lua=''):
    procs = []
    for name, tfile, tiers in GROUPS:
        lua = extra_lua
        if tiers:
            lua = 'AR_NT_TIERS = { %s }\n' % ', '.join('%s = 1' % t for t in tiers.split()) + lua
        runfile = 'nt_run_%s.lua' % name
        open(os.path.join(AR, runfile), 'w').write(lua)
        extra = 'nav_cases.lua ar_fixture.lua ar_nt_lib.lua nav_known.lua nav_coll_expect.lua nav_slide_expect.lua rules_expect.lua rules_known.lua ' + runfile
        if os.environ.get('RUNCASES') and os.path.exists(os.path.join(AR, 'nav_cases_run.lua')):
            extra = 'nav_cases_run.lua ' + extra
        cmd = 'cd /c/Users/Joel/grim_tools/autorun && TESTSETS=1 SIMMS=${SIMMS:-17} LOGTAG=_%s EXTRA="%s" timeout 1500 sh run_chapter.sh %s 1500 > logs/tn_%s.out 2>&1' % (name, extra, tfile, name)
        procs.append((name, tfile, subprocess.Popen(BASH + [cmd], env=dict(os.environ))))
    res = {}
    for name, tfile, p in procs:
        p.wait()
        src = os.path.join(LOGS, os.path.splitext(tfile)[0] + '_%s.log' % name)
        dst = os.path.join(LOGS, 'tn_%s_%s.log' % (tag, name))
        if os.path.exists(src):
            shutil.copy(src, dst)
        res.update(parse(dst, name))
    return res

out = ['# Navigation tests, %s\n' % datetime.datetime.now().strftime('%Y-%m-%d %H:%M')]
hist = [datetime.datetime.now().strftime('%Y-%m-%d %H:%M')]
if 'offline' in what:
    t = sh('sh tools/lua31/run.sh')
    m = re.findall(r'NAVTEST SUMMARY unit (\d+)/(\d+)', t)
    fails = [l for l in t.splitlines() if ' FAIL ' in l]
    out.append('## Tier A (offline): %s\n' % (m and '%s/%s' % m[-1] or 'no summary'))
    out += ['    ' + f[:200] for f in fails]
    hist.append('A=%s' % (m and '%s/%s' % m[-1] or '?'))
base = {}
if 'scummvm' in what or 'flaky' in what:
    base = scummvm('base')
    c = counts(base)
    out.append('## ScummVM, listed order: ' + ', '.join('%s %d/%d' % (k, v[0], v[1]) for k, v in sorted(c.items())) + '\n')
    for k, v in sorted(base.items()):
        if v[0] == 'FAIL':
            out.append('    FAIL %s %s: %s' % (k[0], k[1], v[1]))
    known = sum(1 for v in base.values() if v[0] == 'KNOWN')
    out.append('(%d of them known differences from the original, nav_known.lua)\n' % known)
    hist.append('S=' + ' '.join('%s%d/%d' % (k, v[0], v[1]) for k, v in sorted(c.items())) + ' known=%d' % known)
if 'flaky' in what:
    runs = [base]
    for seed in (12345, 777):
        runs.append(scummvm('shuffle%d' % seed, 'AR_NT_SHUFFLE = %d\n' % seed))
    flaky = []
    for k in sorted(base):
        res = set(r[k][0] for r in runs if k in r)
        if len(res) > 1:
            flaky.append(k)
    out.append('\n## Flaky or order dependent (listed order and two shuffles): %d\n' % len(flaky))
    out += ['    %s %s: %s' % (k[0], k[1], ' / '.join(r[k][0] if k in r else 'missing' for r in runs)) for k in flaky]
    hist.append('flaky=%d' % len(flaky))
orig_log = os.path.join(LOGS, 'orig_tn_full.log')
if 'original' in what:
    print(sh('sh test_nav_original.sh', 7200))
    print(sh('sh orig_test.sh $PWD/test_rules.lua 2400 $PWD/logs/orig_rules.log', 3000))

if os.path.exists(orig_log) and base:
    o = parse(orig_log)
    o.update(parse(os.path.join(LOGS, 'orig_rules.log')))
    co = counts(o)
    out.append('\n## Original (%s): ' % time.strftime('%Y-%m-%d %H:%M', time.localtime(os.path.getmtime(orig_log))) + ', '.join('%s %d/%d' % (k, v[0], v[1]) for k, v in sorted(co.items())) + '\n')
    diff = [k for k in sorted(set(base) & set(o)) if base[k][0] != o[k][0] and 'KNOWN' not in (base[k][0], o[k][0])]
    out.append('Differences from ScummVM: %d of %d\n' % (len(diff), len(set(base) & set(o))))
    for k in diff:
        out.append('    %s %s: ScummVM %s / original %s  %s' % (k[0], k[1], base[k][0], o[k][0], (o[k][1] if o[k][0] == 'FAIL' else base[k][1])[:100]))
    hist.append('O=' + ' '.join('%s%d/%d' % (k, v[0], v[1]) for k, v in sorted(co.items())) + ' diff=%d' % len(diff))
open(os.path.join(LOGS, 'navtest_summary.md'), 'w').write('\n'.join(out) + '\n')
open(os.path.join(LOGS, 'navtest_history.tsv'), 'a').write('\t'.join(hist) + '\n')
print('\n'.join(out))
