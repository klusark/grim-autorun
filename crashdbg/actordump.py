# Dumps the engine structures of the actors that have a costume in the running original game: actordump.py <label>
import subprocess, sys
def rd(addr, n):
    out = subprocess.run(['./rdmem.exe', '%x' % addr, str(n)], capture_output=True, text=True).stdout.split()
    return [int(x, 16) for x in out]
base = rd(0x8ca758, 1)[0]
for i in range(0, 40):
    a = rd(base + i * 0xa8, 0xa8 // 4)
    if len(a) < 42 or not a[0xa0 // 4]:
        continue
    cos = a[0xa0 // 4]
    extra = a[0xa4 // 4]
    c = rd(cos, 0x90 // 4)
    e = rd(extra, 0x440 // 4)
    print(sys.argv[1], 'actor', i)
    print('  actor  ', ' '.join('%x' % x for x in a))
    print('  cos    ', ' '.join('%x' % x for x in c))
    print('  extra  ', ' '.join('%x' % x for x in e))
