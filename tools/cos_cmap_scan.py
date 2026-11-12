"""Lists every costume of the LABs with its main model and the colormaps under it (cosinfo.json), for finding costume stacks
that share a model but disagree on its colormap (bug #11818). Usage: python -I cos_cmap_scan.py "C:/GOG Games/GRIMDATA" """
import struct, glob, json, re, sys
cos = {}
for lab in sorted(glob.glob(sys.argv[1] + '/*.LAB')):
    d = open(lab, 'rb').read()
    if d[:4] != b'LABN': continue
    n, ss = struct.unpack('<II', d[8:16])
    st = d[16 + n*16:16 + n*16 + ss]
    for i in range(n):
        no, start, size, _ = struct.unpack('<IIII', d[16+i*16:32+i*16])
        name = st[no:st.index(b'\0', no)].decode().lower()
        if name.endswith('.cos'):
            cos[name] = d[start:start+size].decode('latin1')   # later LABs win, as the game's
out = {}
for name, txt in cos.items():
    tags, comps = {}, []
    sec = None
    for l in txt.splitlines():
        l = l.split('#')[0].strip()
        if l.startswith('section'): sec = l.split()[1]; continue
        if not l or l.startswith('num'): continue
        if sec == 'tags':
            m = re.match(r"(\d+)\s+'(....)'", l)
            if m: tags[int(m.group(1))] = m.group(2)
        elif sec == 'components':
            p = l.split(None, 4)
            if len(p) == 5: comps.append((int(p[0]), tags.get(int(p[1])), int(p[3]), p[4].strip()))
    main = next((c for c in comps if c[1] == 'MMDL' and c[2] == -1), None)
    cm = [c[3].lower() for c in comps if main and c[1] == 'cmap' and c[2] == main[0]]
    out[name] = {'main': main[3].lower() if main else None, 'cmap': cm}
json.dump(out, open('cosinfo.json', 'w'), indent=0)
print(len(out), 'costumes;', sum(1 for v in out.values() if v['cmap']), 'with a colormap on the main model;',
      sum(1 for v in out.values() if len(v['cmap']) > 1), 'with more than one')
