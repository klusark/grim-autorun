# Snapshot of the iMuse / DirectSound state of the running original (read from its memory, nothing is changed):
# python3 audio_snap.py  -> the track list, the ImHeartbeat guards, the timer service, the DirectSound feeder block counter,
# and the instruction pointer of every thread. Used by watch_audio.sh when the game stops logging.
import ctypes, ctypes.wintypes as w, struct, subprocess, time, sys
k=ctypes.WinDLL('kernel32',use_last_error=True); psapi=ctypes.WinDLL('psapi')
out=subprocess.run(['powershell','-NoProfile','(Get-Process GRIMFANDANGO -ErrorAction SilentlyContinue).Id'],capture_output=True,text=True).stdout.split()
if not out: print('no game'); sys.exit(1)
pid=int(out[0])
k.OpenProcess.restype=w.HANDLE
k.ReadProcessMemory.argtypes=[w.HANDLE,ctypes.c_void_p,ctypes.c_void_p,ctypes.c_size_t,ctypes.c_void_p]
psapi.EnumProcessModulesEx.argtypes=[w.HANDLE,ctypes.c_void_p,w.DWORD,ctypes.c_void_p,w.DWORD]
psapi.GetModuleFileNameExW.argtypes=[w.HANDLE,ctypes.c_void_p,ctypes.c_wchar_p,w.DWORD]
h=k.OpenProcess(0x1F0FFF,False,pid)
mods=(ctypes.c_void_p*1024)(); n=w.DWORD()
psapi.EnumProcessModulesEx(h,mods,ctypes.sizeof(mods),ctypes.byref(n),1)
ml=[]; base=None
for m in mods[:n.value//8]:
    if not m: continue
    nm=ctypes.create_unicode_buffer(260); psapi.GetModuleFileNameExW(h,m,nm,260); ml.append((m,nm.value))
    if nm.value.lower().endswith('imuse.dll'): base=m
ml.sort()
def where(a):
    best=None
    for m,nm in ml:
        if m<=a: best=(m,nm)
    return f"{best[1].split(chr(92))[-1]}+{a-best[0]:#x}" if best else hex(a)
def rd(a,l):
    b=ctypes.create_string_buffer(l); r=ctypes.c_size_t()
    if not k.ReadProcessMemory(h,ctypes.c_void_p(a),b,l,ctypes.byref(r)): return b''
    return b.raw[:r.value]
def u32(a):
    d=rd(a,4); return struct.unpack('<I',d)[0] if len(d)==4 else None
def i32(a):
    d=rd(a,4); return struct.unpack('<i',d)[0] if len(d)==4 else None
D=lambda off: base+off-0x10000000
def snap():
    o={}; t=u32(D(0x10032300))
    while t and len(o)<40:
        raw=rd(t,0x3c); f=struct.unpack('<15I',raw)
        o[t]=(raw,rd(f[2],0x900) if f[2] else b''); t=f[1]
    return o
print('time',time.strftime('%H:%M:%S'),'pid',pid)
print('ImPause DAT_1002df00',u32(D(0x1002df00)),' heartbeat-running DAT_1002df10',u32(D(0x1002df10)),' DAT_100172c0',u32(D(0x100172c0)),' last heartbeat DAT_100172bc',i32(D(0x100172bc)),' now timeGetTime',ctypes.windll.winmm.timeGetTime())
print('DS feeder last block DAT_004f3f94',[i32(0x4f3f94)],' blocks',u32(0x8db420),' timer run',u32(0x8da874),' timer paused',u32(0x8da878),' feeder busy',u32(0x8da880),u32(0x8da87c))
a=snap(); time.sleep(2); b=snap()
print('tracks',len(a),'pool',u32(D(0x1003350c)))
for t,(ra,sa) in a.items():
    f=struct.unpack('<15I',ra); moved='gone' if t not in b else ('MOVING' if b[t][0]!=ra or b[t][1]!=sa else 'frozen')
    print(' track',hex(t),'sound id',f[3],'prio',f[6],'vol',f[7],'pan',f[9],moved)
for sl in range(32):
    raw=rd(D(0x10031528)+sl*0x40,0x40)
    nm=raw[:0x20].split(b'\0')[0] if raw else b''
    if nm:
        f=struct.unpack('<16I',raw); print(' slot',sl+100,nm.decode(),'handle',f[8],'loaded',bool(f[10]))
# thread instruction pointers
k.OpenThread.restype=w.HANDLE; k.OpenThread.argtypes=[w.DWORD,w.BOOL,w.DWORD]
k.SuspendThread.argtypes=[w.HANDLE]; k.ResumeThread.argtypes=[w.HANDLE]; k.Wow64GetThreadContext.argtypes=[w.HANDLE,ctypes.c_void_p]
tids=[int(x) for x in subprocess.run(['powershell','-NoProfile','(Get-Process GRIMFANDANGO).Threads.Id'],capture_output=True,text=True).stdout.split()]
for tid in tids:
    th=k.OpenThread(0x1FFFFF,False,tid)
    if not th: continue
    k.SuspendThread(th); ctx=(ctypes.c_ubyte*716)(); struct.pack_into('<I',ctx,0,0x10007)
    if k.Wow64GetThreadContext(th,ctx):
        eip=struct.unpack_from('<I',ctx,0xB8)[0]; esp=struct.unpack_from('<I',ctx,0xC4)[0]
        st=struct.unpack('<%dI'%(len(rd(esp,0x400))//4),rd(esp,0x400)); refs=[]
        for v in st:
            if any(m<=v<m+0x1000000 for m,_ in ml):
                bb=rd(v-6,6)
                if len(bb)==6 and (bb[1]==0xE8 or bb[4]==0xFF or bb[2]==0xFF or bb[3]==0xFF):
                    wv=where(v)
                    if not wv.startswith(('ntdll','KERNELBASE','KERNEL32')): refs.append(wv)
        print(' thread',tid,'eip',where(eip),'|',' '.join(refs[:10]))
    k.ResumeThread(th)
