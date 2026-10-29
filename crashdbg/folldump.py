import subprocess, sys
def rd(addr, n):
    out = subprocess.run(['./rdmem.exe', '%x' % addr, str(n)], capture_output=True, text=True).stdout.split()
    return [int(x, 16) for x in out]
head = rd(0x8d086c, 1)[0]
d = rd(head, 0x60 // 4)
print(sys.argv[1], ' '.join('%x' % x for x in d))
base = rd(0x8ca758, 1)[0]
a = rd(base + 5 * 0xa8, 0xa8 // 4)
e = rd(a[0xa4 // 4], 0x1d0 // 4)
print(sys.argv[1], 'extra 0x1b0..', ' '.join('%x' % x for x in e[0x1b0 // 4:0x1d0 // 4]))
print(sys.argv[1], 'extra 0..0x60', ' '.join('%x' % x for x in e[0:0x60 // 4]))
