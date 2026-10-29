# Prints the age in ms of the last iMuse heartbeat of the running original and the guard counter: "<age> <counter>" (nothing if no game).
import ctypes, ctypes.wintypes as w, struct, subprocess, sys
exec(open('C:/Users/Joel/grim_tools/autorun/tools/audio_snap.py').read().split("print('time'")[0])
last=i32(D(0x100172bc)); now=ctypes.windll.winmm.timeGetTime()
age=(now-last)&0xffffffff
if age>0x7fffffff: age=0  # (the heartbeat ran after the clock was read)
print(age, u32(D(0x100172c0)))
