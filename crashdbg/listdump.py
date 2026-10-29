# Walks the actor list that the crashing function 0x48ba90 walks: listdump.py
import subprocess, sys
def rd(addr, n):
    out = subprocess.run(['./rdmem.exe', '%x' % addr, str(n)], capture_output=True, text=True).stdout.split()
    return [int(x, 16) for x in out]
node = rd(0x8ca150, 1)[0]
i = 0
while node and i < 80:
    a = rd(node, 0x98)
    if len(a) < 0x97:
        print('node', hex(node), 'unreadable'); break
    p95 = a[0x95]; fl = a[0x96]
    ok = rd(p95 + 0xa4, 1) if p95 else []
    print(i, hex(node), 'next', hex(a[0]), 'flags', hex(fl), 'p95', hex(p95), 'p95+a4', [hex(x) for x in ok], 'name?', bytes(b for w in a[1:9] for b in w.to_bytes(4,'little')).split(b'\0')[0][:20])
    node = a[0]; i += 1
