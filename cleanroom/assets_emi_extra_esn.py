"""EMI sound data of emi_esn*.lua (prefix esn): sounds in other formats, longer and stereo voices, and music states of
ScummVM's second music table.

files() (the archive):
- esn_bad.aif: not an AIFF (LoadSound of a file that does not decode);
- esn_st.aif: stereo, 16 bits, 11025 Hz, 1 s; esn_b8.aif: mono, 8 bits, 44100 Hz, 0.5 s;
- esnv01.wVC: a voice of 1.7 s in stereo at 11025 Hz, its samples stored (codec NULL); esnv02.wVC: 3 s mono at 22050 Hz in
  VIMA blocks; esnv03.wVC: 12 s mono at 8000 Hz in VIMA blocks (longer than the 8 s that ScummVM's VimaTrack queues).

loose_files() (beside it): Textures/FullMonkeyMap1.imt, which ScummVM reads before FullMonkeyMap.imt (the CD 1 table;
engines/grim/emi/sound/emisound.cpp initMusicTable) with states 111 to 114, which FullMonkeyMap.imt does not have:
- 111: A\\esn_two.m4b (3 s, no loop), sync group 1 as the odd states of assets_emi.music (cr_one): a change from state 1
  starts it where cr_one was;
- 112: A\\esn_short.m4b (0.5 s, a loop from 0.4 s back to 0.1 s), sync group 1: started where cr_one was, past its end;
- 113: A\\esn_over.m4b (1 s, a .jmm jump at 5 s back to 0.2 s, past the end of the data), sync group 3;
- 114: A\\esn_missing.m4b, a file that is not there.
"""
import math
import struct

import formats as F


def _ext80(rate):
    e = rate.bit_length() - 1
    return struct.pack(">HQ", 16383 + e, rate << (63 - e))


def aiff(seconds, rate=22050, channels=1, bits=16, freq=440.0, amplitude=8000):
    """An AIFF of PCM with `channels` channels of `bits` bits (8 or 16; formats.aiff writes mono 16-bit only)."""
    n = int(seconds * rate)
    out = bytearray()
    for i in range(n):
        v = math.sin(2 * math.pi * freq * i / rate)
        if bits == 8:
            out += struct.pack(">b", int(v * 100)) * channels
        else:
            out += struct.pack(">h", int(v * amplitude)) * channels
    frames = bytes(out)
    comm = b"COMM" + struct.pack(">IHIH", 18, channels, n, bits) + _ext80(rate)
    ssnd = b"SSND" + struct.pack(">III", 8 + len(frames), 0, 0) + frames
    body = b"AIFF" + comm + ssnd
    return b"FORM" + struct.pack(">I", len(body)) + body


def files():
    out = {}
    out["esn_bad.aif"] = b"esn: this is not an AIFF file at all" + bytes(64)
    out["esn_st.aif"] = aiff(1.0, rate=11025, channels=2)
    out["esn_b8.aif"] = aiff(0.5, rate=44100, bits=8)
    out["esnv01.wVC"] = F.mcmp(*F.wav_split(F.wav(1.7, rate=11025, freq=300.0, channels=2)), vima_blocks=False)
    out["esnv02.wVC"] = F.mcmp(*F.wav_split(F.wav(3.0, freq=250.0)))
    out["esnv03.wVC"] = F.mcmp(*F.wav_split(F.wav(12.0, rate=8000, freq=220.0)))
    return out


def loose_files():
    out = {"Textures/FullMonkeyMap1.imt": F.imt([(111, 1, "state", "A\\esn_two.m4b"),
                                                 (112, 1, "state", "A\\esn_short.m4b"),
                                                 (113, 3, "state", "A\\esn_over.m4b"),
                                                 (114, 3, "state", "A\\esn_missing.m4b")])}
    for d in ("spago", "mego"):
        out["Textures/%s/A/esn_two.m4b" % d] = F.emi_music(3.0)
        out["Textures/%s/A/esn_two.jmm" % d] = F.jmm(0.0)
        out["Textures/%s/A/esn_short.m4b" % d] = F.emi_music(0.5)
        out["Textures/%s/A/esn_short.jmm" % d] = F.jmm(0.0, 400.0, 100.0)
        out["Textures/%s/A/esn_over.m4b" % d] = F.emi_music(1.0)
        out["Textures/%s/A/esn_over.jmm" % d] = F.jmm(0.0, 5000.0, 200.0)
    return out
