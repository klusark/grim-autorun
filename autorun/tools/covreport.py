#!/usr/bin/env python
"""A coverage report of engines/grim from the .gcda files of a gcov build (build-cov), without gcovr (its parser stops on the counters that went
negative when several runs wrote the same file): runs gcov on every .gcda, merges the lines of all the objects, and writes
<outdir>/index.html (one line per file, the worst first), <outdir>/<file>.html (the source with the lines that never ran in red), summary.txt.

    python covreport.py [outdir] [build dir] [repo dir] [--all] [--title TEXT]

--all: every file of engines/grim and graphics/tinygl (when EMI and every renderer ran too), with a total for each part
(grim, emi, tinygl, lua, remastered). --title: what ran, for the page.

Excluded: the Lua interpreter (engines/grim/lua), the Monkey Island 4 engine (emi) with its two video codecs, the remastered code and the TinyGL renderer: Grim does not use them (gfx_opengl.cpp, the renderer without shaders, is counted, and the full game does not use it).
(Windows python.)"""
import gzip, html, json, os, subprocess, sys

args = sys.argv[1:]
ALL = '--all' in args
if ALL:
    args.remove('--all')
TITLE = 'from the full game (skipping and without), the navigation tests.'
if '--title' in args:
    i = args.index('--title')
    TITLE = args[i + 1]
    del args[i:i + 2]
out = args[0] if len(args) > 0 else r'C:\Users\Joel\grim_tools\autorun\coverage'
build = args[1] if len(args) > 1 else r'C:\msys64\home\Joel\scummvm\build-cov'
repo = args[2] if len(args) > 2 else r'C:\msys64\home\Joel\scummvm'
gcov = r'C:\msys64\ucrt64\bin\gcov.exe'
EXCLUDE = () if ALL else ('engines/grim/lua/', 'engines/grim/emi/', 'engines/grim/remastered/', 'engines/grim/gfx_tinygl', 'engines/grim/movie/codecs/blocky8', 'engines/grim/movie/codecs/codec48')
ROOTS = ('engines/grim/', 'graphics/tinygl/') if ALL else ('engines/grim/',)
WHAT = 'engines/grim and graphics/tinygl' if ALL else 'engines/grim'
PARTS = ('grim', 'emi', 'tinygl', 'lua', 'remastered')


def part(rel):
    """The part of the code a file belongs to (--all)."""
    for name, prefixes in (('lua', ('engines/grim/lua/',)), ('emi', ('engines/grim/emi/',)),
                           ('remastered', ('engines/grim/remastered/',)),
                           ('tinygl', ('engines/grim/gfx_tinygl', 'graphics/tinygl/'))):
        if rel.startswith(prefixes):
            return name
    return 'grim'


os.makedirs(out, exist_ok=True)

lines = {}  # file -> {line: executed}
gcdas = [w for r in ROOTS for w in os.walk(os.path.join(build, *r.strip('/').split('/')))]
for root, _, files in gcdas:
    for f in files:
        if not f.endswith('.gcda'):
            continue
        r = subprocess.run([gcov, '--json-format', '--stdout', os.path.join(root, f)], cwd=build, capture_output=True)
        if r.returncode != 0 or not r.stdout:
            continue
        for chunk in r.stdout.splitlines():
            try:
                d = json.loads(chunk)
            except ValueError:
                continue
            for fe in d.get('files', []):
                path = os.path.normpath(os.path.join(build, fe['file'])).replace('\\', '/')
                rel = path[len(repo.replace('\\', '/')) + 1:] if path.lower().startswith(repo.replace('\\', '/').lower()) else path
                if not rel.startswith(ROOTS) or (EXCLUDE and rel.startswith(EXCLUDE)):
                    continue
                m = lines.setdefault(rel, {})
                for ln in fe.get('lines', []):
                    n = ln['line_number']
                    m[n] = m.get(n, False) or ln['count'] != 0

rows = []
for rel, m in lines.items():
    tot = len(m)
    cov = sum(1 for v in m.values() if v)
    rows.append((tot - cov, rel, tot, cov))
rows.sort(reverse=True)
T = sum(r[2] for r in rows)
C = sum(r[3] for r in rows)
parts = {}
for miss, rel, tot, cov in rows:
    t = parts.setdefault(part(rel), [0, 0])
    t[0] += tot
    t[1] += cov
with open(os.path.join(out, 'summary.txt'), 'w') as f:
    f.write('%s%s: %d of %d lines run, %.1f%%\n' % (WHAT, '' if ALL else ' (without lua, emi, remastered, tinygl)', C, T, 100.0 * C / max(T, 1)))
    if ALL:
        for name in PARTS:
            if name in parts:
                f.write('  %-10s %6d of %6d lines, %5.1f%%\n' % (name, parts[name][1], parts[name][0], 100.0 * parts[name][1] / max(parts[name][0], 1)))
    f.write('\n')
    for miss, rel, tot, cov in rows:
        f.write('%-48s %5d lines, %5d never run, %5.1f%% covered\n' % (rel, tot, miss, 100.0 * cov / max(tot, 1)))
css = ('body{font:14px sans-serif;margin:1em}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:2px 8px;text-align:right}'
       'td:first-child{text-align:left}pre{font:12px/1.35 Consolas,monospace}.u{background:#fcc}.c{background:#efe}.n{color:#666}')
with open(os.path.join(out, 'index.html'), 'w') as f:
    f.write('<!doctype html><meta charset="utf-8"><title>Coverage of %s</title><style>%s</style>' % (WHAT, css))
    f.write('<h1>%s: %.1f%% of the lines run</h1><p>%d of %d lines, %s%s</p>' % (
        WHAT, 100.0 * C / max(T, 1), C, T, html.escape(TITLE), '' if ALL else ' Not counted: lua, emi, remastered, tinygl.'))
    if ALL:
        f.write('<table><tr><th>part<th>lines<th>run<th>covered</tr>')
        for name in PARTS:
            if name in parts:
                f.write('<tr><td>%s<td>%d<td>%d<td>%.1f%%</tr>' % (name, parts[name][0], parts[name][1], 100.0 * parts[name][1] / max(parts[name][0], 1)))
        f.write('</table><p></p>')
    f.write('<table><tr><th>file<th>lines<th>never run<th>covered</tr>')
    for miss, rel, tot, cov in rows:
        name = rel.replace('/', '_') + '.html'
        f.write('<tr><td><a href="%s">%s</a><td>%d<td>%d<td>%.1f%%</tr>' % (name, rel, tot, miss, 100.0 * cov / max(tot, 1)))
    f.write('</table>')
for miss, rel, tot, cov in rows:
    try:
        src = open(os.path.join(repo, rel), encoding='utf-8', errors='replace').read().split('\n')
    except OSError:
        continue
    m = lines[rel]
    with open(os.path.join(out, rel.replace('/', '_') + '.html'), 'w', encoding='utf-8') as f:
        f.write('<!doctype html><meta charset="utf-8"><title>%s</title><style>%s</style><h2>%s: %d never run of %d</h2><pre>' % (rel, css, rel, miss, tot))
        for i, t in enumerate(src, 1):
            cls = 'n' if i not in m else ('c' if m[i] else 'u')
            f.write('<span class="%s">%5d  %s</span>\n' % (cls, i, html.escape(t)))
        f.write('</pre>')
print(open(os.path.join(out, 'summary.txt')).read().split('\n\n')[0])
for miss, rel, tot, cov in rows[:12]:
    print('%-48s %5d lines, %5d never run, %5.1f%%' % (rel, tot, miss, 100.0 * cov / max(tot, 1)))
