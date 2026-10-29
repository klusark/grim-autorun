#!/usr/bin/env python3
"""Writes engines/grim/sintable.h: the sine table that the original exe interpolates in (FUN_0047bd20), from a dump of the memory of
the running original (crashdbg/memdump.exe GRIMFANDANGO.exe 4cf600 0x18010 dump.bin). The table is sin(i * pi / 8192) for i in 0..4095,
given to 6 decimals, with the word before and the word after it (both 0.0), which the original reads at the edges of the quadrants."""
import struct, sys
src = sys.argv[1] if len(sys.argv) > 1 else 'C:/msys64/tmp/w/sintab_live2.bin'
dst = sys.argv[2] if len(sys.argv) > 2 else 'C:/msys64/home/Joel/scummvm/engines/grim/sintable.h'
d = open(src, 'rb').read()
v = struct.unpack('<%df' % (len(d) // 4), d)
i0 = (0x4df600 - 0x4cf600) // 4
words = [v[i0 - 1]] + list(v[i0:i0 + 4096]) + [v[i0 + 4096]]
for w in words:
    # each value prints to 6 decimals and reads back as the same float
    assert struct.unpack('<f', struct.pack('<f', float('%.6f' % w)))[0] == w, w
out = ['/* ScummVM - Graphic Adventure Engine', ' *', ' * ScummVM is the legal property of its developers, whose names', ' * are too numerous to list here. Please refer to the COPYRIGHT', ' * file distributed with this source distribution.', ' *',
       ' * This program is free software: you can redistribute it and/or modify', ' * it under the terms of the GNU General Public License as published by', ' * the Free Software Foundation, either version 3 of the License, or', ' * (at your option) any later version.', ' *',
       ' * This program is distributed in the hope that it will be useful,', ' * but WITHOUT ANY WARRANTY; without even the implied warranty of', ' * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the', ' * GNU General Public License for more details.', ' *',
       ' * You should have received a copy of the GNU General Public License', ' * along with this program.  If not, see <http://www.gnu.org/licenses/>.', ' *', ' */', '',
       '// The sine table of the original engine: sin(i * pi / 8192) for i in 0..4095, to 6 decimals, made by tools/gen_sintab.py from the',
       '// memory of the running game. The first and the last entry are the words before and after the table, which the original reads at',
       '// the edges of the quadrants (both are 0).', '', 'static const float sinTable[4098] = {']
for k in range(0, len(words), 8):
    out.append('\t' + ', '.join(('%.6ff' % w) for w in words[k:k + 8]) + ',')
out.append('};')
open(dst, 'w', newline='\n').write('\n'.join(out) + '\n')
print('wrote', len(words), 'values to', dst)
