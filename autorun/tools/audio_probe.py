# Probes of the iMuse guard counter (DAT_100172c0) on the running ORIGINAL: for each Lua call the counter is read before and after
# (a call that leaves it higher leaks a count; the heartbeat does not run while it is nonzero). Usage: audio_probe.py
import ctypes, ctypes.wintypes as w, struct, subprocess, sys, time
exec(open('/c/Users/Joel/grim_tools/autorun/tools/audio_snap.py'.replace('/c/','C:/')).read().split("print('time'")[0])
AR='C:/Users/Joel/grim_tools/autorun'
def cnt(): return u32(D(0x100172c0))
def hb(): return i32(D(0x100172bc))
def orl(code):
    r=subprocess.run(['sh',AR+'/orl.sh',code],capture_output=True,text=True,cwd=AR)
    return [l for l in r.stdout.splitlines() if 'ORL' in l and 'ORL done' not in l]
def probe(label, code):
    b=cnt(); out=orl('PrintDebug("ORL "..tostring(('+code+')))' if not code.startswith('@') else code[1:])
    a=cnt()
    print(f"{label:58s} counter {b} -> {a} {'LEAK +'+str(a-b) if a>b else ('DROP' if a<b else 'same')}   {(out[0].split('ORL',1)[1].strip()[:70] if out else '(no answer)')}", flush=True)
    return a
print('start: counter',cnt(),'last heartbeat',hb(),'now',ctypes.windll.winmm.timeGetTime())
N='"anchlock.wav"'
# gets of every parameter
for p in (0x100,0x200,0x300,0x400,0x500,0x600,0x700,0x800,0x900,0xa00,0x1800,0x1900,0x1a00,0x0,0x1234):
    probe(f'ImGetParam(name, {p:#x})', f'ImGetParam({N},{p})')
for p in (0x100,0x400,0x600):
    probe(f'ImGetParam(handle-ish 1346, {p:#x})', f'ImGetParam(1346,{p})')
# sets, in range and out of range
for p,vals in ((0x400,(0,1,4,15,16,17,100,-1)),(0x500,(0,64,127,128,200)),(0x600,(0,127,128,500)),(0x700,(0,64,127,128)),(0x800,(0,100,9000,9300,-9300)),(0x900,(0,100,4095,4096,-1)),(0xa00,(0,5)),(0x1234,(0,1)),(0x100,(0,)),(0x200,(0,))):
    for v in vals:
        probe(f'ImSetParam(name, {p:#x}, {v})', f'ImSetParam({N},{p},{v})')
# the other sound calls
probe('ImGetNextSound(0)', 'ImGetNextSound and ImGetNextSound(0) or "no function"')
probe('ImFadeParam(name,0x600,0,500)', f'ImFadeParam({N},1536,0,500)')
probe('ImFadeParam(name,0x700,10,500)', f'ImFadeParam({N},1792,10,500)')
probe('ImStartSound("anchup.wav",64,1)', 'ImStartSound("anchup.wav",64,1)')
probe('ImStartSound("anchup.wav",64,40)  (group >= 16)', 'ImStartSound("anchup.wav",64,40)')
probe('ImStopSound("anchup.wav")', 'ImStopSound("anchup.wav")')
probe('ImStartSound("nonexistent_zz.wav",64,1)', 'ImStartSound("nonexistent_zz.wav",64,1)')
probe('ImSetState / ImSetSequence', '@if ImSetState then ImSetState(1) PrintDebug("ORL ImSetState done") end')
probe('ImPause then ImResume', '@if ImPause then ImPause() ImResume() PrintDebug("ORL pause/resume done") end')
probe('ImStopAllSounds()', '@ImStopAllSounds() PrintDebug("ORL stopall done")')
print('end: counter',cnt(),'last heartbeat',hb())
