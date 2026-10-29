import subprocess, sys
def rd(addr, n):
    out = subprocess.run(['./rdmem.exe', '%x' % addr, str(n)], capture_output=True, text=True).stdout.split()
    return [int(x, 16) for x in out]
head = rd(0x8d086c, 1)[0]
sec = rd(head + 0x5c, 1)[0]
d = rd(sec, 0x40 // 4)
print(sys.argv[1], 'follower %x sector %x' % (head, sec), ' '.join('%x' % x for x in d))
s = ''.join(chr(b) for w in rd(sec + 0x10, 8) for b in w.to_bytes(4, 'little'))
print(sys.argv[1], repr(s))
setp = rd(0x8cabb4, 1)[0]
# is sec inside the current set's memory block? print set->sector list candidates
for off in range(0, 0x2000, 4):
    pass
print(sys.argv[1], 'set %x' % setp)
