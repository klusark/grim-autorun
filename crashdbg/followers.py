# Lists the path followers of the running original game and says whether Manny's is among them
import subprocess
def rd(addr, n):
    out = subprocess.run(['./rdmem.exe', '%x' % addr, str(n)], capture_output=True, text=True).stdout.split()
    return [int(x, 16) for x in out]
head = rd(0x8d086c, 1)[0]
base = rd(0x8ca758, 1)[0]
mine = {}
for i in range(0, 900):
    a = rd(base + i * 0xa8, 0xa8 // 4)
    if len(a) >= 42 and a[0xa4 // 4]:
        f = rd(a[0xa4 // 4] + 0x1b4, 1)[0]
        if f:
            mine[f] = i
print('registry head %x' % head)
node = head; n = 0; seen = []
while node and n < 100:
    d = rd(node, 0x60 // 4)
    seen.append(node)
    print('  follower %x actor=%s next=%x(+0x58 prev) +0x54=%x +0x5c=%x' % (node, mine.get(node, '-'), d[0x58 // 4], d[0x54 // 4], d[0x5c // 4]))
    node = d[0x58 // 4]; n += 1
for f, i in sorted(mine.items(), key=lambda x: x[1]):
    print('actor %d follower %x in registry: %s' % (i, f, f in seen))
