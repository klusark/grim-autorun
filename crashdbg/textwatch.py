# Prints the text objects of the running original game (the list the draw code walks) once a second
import subprocess, time, sys
def rd(addr, n):
    out = subprocess.run(['./rdmem.exe', '%x' % addr, str(n)], capture_output=True, text=True).stdout.split()
    return [int(x, 16) for x in out]
def text_at(p):
    if not p: return ''
    w = rd(p, 16)
    b = b''.join(x.to_bytes(4, 'little') for x in w)
    return b.split(b'\0')[0].decode('latin1')[:60]
last = None
while True:
    head = rd(0x8ca150, 1)
    if not head:
        break
    node = head[0]; rows = []; n = 0
    while node and n < 40:
        d = rd(node, 0x25c // 4)
        if len(d) < 0x25c // 4: break
        font = d[0x210 // 4]
        rows.append('%x font=%x text=%r flags=%x ttl=%d' % (node, font, text_at(node + 8) , d[0x258 // 4], d[0x250 // 4] if 0x250 // 4 < len(d) else 0))
        node = d[0]; n += 1
    s = ' | '.join(rows)
    if s != last:
        print(time.strftime('%H:%M:%S'), len(rows), s, flush=True)
        last = s
    time.sleep(1)
