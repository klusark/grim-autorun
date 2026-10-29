#!/usr/bin/env python
"""Takes the frames of the ORIGINAL game for the frame comparison (tools/framediff.py): every "FRAMEMARK <name>" line that the autorun
(ar_frame in ar_lib.lua) writes to the game's log makes this program copy the client area of the game window to <outdir>/<name>.png.
ScummVM writes its frames by itself (DumpFrame, with dump_frames_dir in the config).

    python framecap.py <outdir> [log] [seconds]      (Windows python: it needs ctypes and Pillow)

The window has to be visible (the game runs in a window, -w), it is copied from the screen. Stops after the number of seconds (default 7200),
or when the log has a "FRAMEMARK END" line."""
import ctypes, ctypes.wintypes as wt, os, sys, time
from PIL import Image

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDPIAware()

outdir = sys.argv[1]
log = sys.argv[2] if len(sys.argv) > 2 else r'C:\GOG Games\GRIMDATA\grimdebug.log'
limit = float(sys.argv[3]) if len(sys.argv) > 3 else 7200
os.makedirs(outdir, exist_ok=True)


def find_window():
    found = []
    pid = wt.DWORD()

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(h, _):
        if user32.IsWindowVisible(h):
            n = user32.GetWindowTextLengthW(h)
            buf = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(h, buf, n + 1)
            if 'grim fandango' in buf.value.lower():
                rc = wt.RECT()
                user32.GetClientRect(h, ctypes.byref(rc))
                if rc.right - rc.left > 0 and rc.bottom - rc.top > 0:
                    found.append((rc.right * rc.bottom, h))
        return True
    user32.EnumWindows(cb, 0)
    # (the game has more than one window: the biggest one with something in it)
    return max(found)[1] if found else None


class BIH(ctypes.Structure):
    _fields_ = [('biSize', wt.DWORD), ('biWidth', wt.LONG), ('biHeight', wt.LONG), ('biPlanes', wt.WORD), ('biBitCount', wt.WORD),
                ('biCompression', wt.DWORD), ('biSizeImage', wt.DWORD), ('biXPelsPerMeter', wt.LONG), ('biYPelsPerMeter', wt.LONG),
                ('biClrUsed', wt.DWORD), ('biClrImportant', wt.DWORD)]


def grab(h):
    rc = wt.RECT()
    user32.GetClientRect(h, ctypes.byref(rc))
    w, hgt = rc.right - rc.left, rc.bottom - rc.top
    pt = wt.POINT(0, 0)
    user32.ClientToScreen(h, ctypes.byref(pt))
    sdc = user32.GetDC(0)
    mdc = gdi32.CreateCompatibleDC(sdc)
    bmp = gdi32.CreateCompatibleBitmap(sdc, w, hgt)
    gdi32.SelectObject(mdc, bmp)
    gdi32.BitBlt(mdc, 0, 0, w, hgt, sdc, pt.x, pt.y, 0x00CC0020)  # SRCCOPY
    bih = BIH(ctypes.sizeof(BIH), w, -hgt, 1, 32, 0, 0, 0, 0, 0, 0)
    buf = ctypes.create_string_buffer(w * hgt * 4)
    gdi32.GetDIBits(mdc, bmp, 0, hgt, buf, ctypes.byref(bih), 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mdc)
    user32.ReleaseDC(0, sdc)
    return Image.frombuffer('RGBA', (w, hgt), buf, 'raw', 'BGRA', 0, 1).convert('RGB')


start = time.time()
pos = 0
seen = 0
while time.time() - start < limit:
    try:
        size = os.path.getsize(log)
    except OSError:
        time.sleep(0.2)
        continue
    if size < pos:
        pos = 0
    if size > pos:
        with open(log, 'rb') as f:
            f.seek(pos)
            data = f.read()
        # (only whole lines)
        cut = data.rfind(b'\n')
        if cut >= 0:
            pos += cut + 1
            for line in data[:cut].decode('latin-1').splitlines():
                i = line.find('FRAMEMARK ')
                if i < 0:
                    continue
                name = line[i + 10:].strip()
                if name == 'END':
                    print('end after', seen, 'frames')
                    sys.exit(0)
                h = find_window()
                if h:
                    grab(h).save(os.path.join(outdir, name + '.png'))
                    seen += 1
    time.sleep(0.02)
print('timeout after', seen, 'frames')
