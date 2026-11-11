#!/usr/bin/env python3
"""Writes orig/patch.m4b: the install's patch.m4b with extra members (the original reads its Lua only from its archives, and patch.m4b
is one of the fixed list). Usage: orig_patch_m4b.py <name>=<file> ...   (e.g. grimpatch.bin=generated/orig_all.lua)"""
import os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'cleanroom'))
import formats

SRC = os.environ.get('EMI_INSTALL', r'C:\GOG Games\Escape from Monkey Island')
DST = os.environ.get('ORIG_M4B') or os.path.join(os.path.dirname(os.path.abspath(__file__)), 'orig', 'patch.m4b')

def read_m4b(path):
    d = open(path, 'rb').read()
    n, strsz, stoff = struct.unpack('<III', d[8:20]); stoff -= 0x13d0f
    names = bytes(b ^ 0x96 if b else 0 for b in d[stoff:stoff + strsz])
    out = {}
    for i in range(n):
        no, start, size, _ = struct.unpack('<IIII', d[20 + i * 16:36 + i * 16])
        e = names.index(b'\0', no)
        out[names[no:e].decode('latin1')] = d[start:start + size]
    return out

members = read_m4b(os.path.join(SRC, 'patch.m4b'))
for arg in sys.argv[1:]:
    name, f = arg.split('=', 1)
    members[name] = open(f, 'rb').read()
data = formats.lab_emi(members)
# (orig/patch.m4b may be a hard link to the install's file: removed first, never written through)
if os.path.exists(DST):
    os.remove(DST)
open(DST, 'wb').write(data)
print(len(members), 'members,', len(data), 'bytes ->', DST)
