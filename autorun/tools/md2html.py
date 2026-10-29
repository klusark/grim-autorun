#!/usr/bin/env python3
"""A small markdown to html converter (headings, paragraphs, lists, tables, code blocks, inline code/bold/emphasis); no modules needed.
   md2html.py in.md out.html [title]"""
import re, sys, html

src, dst = sys.argv[1], sys.argv[2]
title = sys.argv[3] if len(sys.argv) > 3 else src
s = open(src, encoding='utf-8').read()


def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'(?<![\w`*])\*([^*\n]+?)\*(?![\w`*])', r'<em>\1</em>', t)
    return t


lines = s.split('\n')
out = []
i = 0
while i < len(lines):
    ln = lines[i]
    if ln.strip() == '':
        i += 1
        continue
    if re.match(r'^-{10,}$', ln.strip()):
        out.append('<hr>')
        i += 1
        continue
    if ln.startswith('```'):
        j = i + 1
        buf = []
        while j < len(lines) and not lines[j].startswith('```'):
            buf.append(lines[j])
            j += 1
        out.append('<pre>' + html.escape('\n'.join(buf), quote=False) + '</pre>')
        i = j + 1
        continue
    m = re.match(r'^(#+) (.*)', ln)
    if m:
        lvl = len(m.group(1))
        out.append('<h%d>%s</h%d>' % (lvl, inline(m.group(2)), lvl))
        i += 1
        continue
    if ln.startswith('|'):
        rows = []
        while i < len(lines) and lines[i].startswith('|'):
            rows.append(lines[i])
            i += 1
        rows = [r for r in rows if not re.match(r'^\|[\s\-|]+\|?$', r)]
        tr = []
        for k, r in enumerate(rows):
            cells = [c.strip() for c in r.strip().strip('|').split(' | ')] if ' | ' in r else [c.strip() for c in r.strip().strip('|').split('|')]
            tag = 'th' if k == 0 else 'td'
            tr.append('<tr>' + ''.join('<%s>%s</%s>' % (tag, inline(c), tag) for c in cells) + '</tr>')
        out.append('<div class="t"><table>' + ''.join(tr) + '</table></div>')
        continue
    if re.match(r'^(\* |- |\d+\. )', ln):
        ol = bool(re.match(r'^\d+\. ', ln))
        pat = r'^(\d+\. )' if ol else r'^(\* |- )'
        items = []
        while i < len(lines) and lines[i].strip() != '' and not lines[i].startswith('#') and not lines[i].startswith('|'):
            if re.match(r'^(\* |- |\d+\. )', lines[i]):
                items.append(re.sub(r'^(\* |- |\d+\. )', '', lines[i]))
            else:
                items[-1] += ' ' + lines[i].strip()
            i += 1
        tag = 'ol' if ol else 'ul'
        out.append('<%s>' % tag + ''.join('<li>%s</li>' % inline(x) for x in items) + '</%s>' % tag)
        continue
    buf = []
    while i < len(lines) and lines[i].strip() != '' and not lines[i].startswith(('#', '|', '```')) and not re.match(r'^(\* |- |\d+\. )', lines[i]):
        buf.append(lines[i].strip())
        i += 1
    out.append('<p>' + inline(' '.join(buf)) + '</p>')

css = '''body{font:15px/1.55 -apple-system,Segoe UI,Helvetica,Arial,sans-serif;max-width:62em;margin:2em auto;padding:0 16px;color:#222;background:#fff}
h1{font-size:1.8em;border-bottom:2px solid #ccc;padding-bottom:.3em}h2{font-size:1.4em;margin-top:2em;border-bottom:1px solid #ddd}h3{font-size:1.15em;margin-top:1.6em}
code{background:#f3f3f3;padding:.1em .3em;border-radius:3px;font-size:.9em;overflow-wrap:anywhere}pre{background:#f3f3f3;padding:.8em;overflow-x:auto;border-radius:4px;font-size:.88em}
.t{overflow-x:auto}table{border-collapse:collapse;margin:1em 0;font-size:.9em}th,td{border:1px solid #ccc;padding:.35em .6em;vertical-align:top;text-align:left}th{background:#eee}
hr{border:0;border-top:1px solid #ccc;margin:2em 0}li{margin:.25em 0}
@media(prefers-color-scheme:dark){body{background:#1b1b1b;color:#ddd}code,pre{background:#2a2a2a}th{background:#333}th,td,h1,h2,hr{border-color:#444}}'''
doc = ('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
       '<title>' + html.escape(title) + '</title><style>' + css + '</style></head><body>' + '\n'.join(out) + '</body></html>')
open(dst, 'w', encoding='utf-8').write(doc)
print('wrote', dst, len(doc), 'bytes')
