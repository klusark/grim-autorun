"""The data of zz_ims*.lua (iMUSE: sound formats, maps, the sound cache, music states, voices). Sounds of other formats
than formats.wav writes (8 bit, stereo, other rates, extra chunks, formats iMUSE refuses), iMUS sound effects with maps of
their own (loops, markers, SYNC blocks, hooks, the other endianness, stereo, 8 and 12 bits, broken maps), many small
sounds for the cache and the tracks, voices in MCMP of one stored block or many, and music files under the names of the
state table that the other music tests do not use (they cannot carry the prefix: iMUSE opens "<name>.IMC")."""
import math
import struct

import formats as F
import assets


def _tone(n, rate, freq, channels=1, amplitude=6000):
    return [int(amplitude * math.sin(2 * math.pi * freq * i / rate)) for i in range(n) for _ in range(channels)]


def _pcm(samples, bits, big=False):
    """Samples as `bits`-bit PCM: 8 bit unsigned, 12 bit packed (two samples in three bytes, as iMUSE's 12-bit sounds),
    16 bit signed little or big endian."""
    if bits == 8:
        return bytes((s >> 8) + 128 & 255 for s in samples)
    if bits == 12:
        out = bytearray()
        for i in range(0, len(samples) - 1, 2):
            a = (samples[i] >> 4) + 2048 & 0xFFF
            b = (samples[i + 1] >> 4) + 2048 & 0xFFF
            out += bytes([a >> 4, (a & 15) << 4 | b >> 8, b & 255])
        return bytes(out)
    return struct.pack((">" if big else "<") + "%dh" % len(samples), *samples)


def wav(seconds, rate=22050, bits=16, channels=1, freq=440.0, tag=1, before_data=b"", data=True, wave=b"WAVEfmt "):
    """A RIFF WAVE of any word size, channel count and rate; `tag` the format (1 PCM), `before_data` chunks before the
    data chunk, without `data` no data chunk, `wave` the 8 bytes after the RIFF size."""
    frames = _pcm(_tone(int(seconds * rate), rate, freq, channels), bits)
    align = channels * bits // 8
    fmt = struct.pack("<HHIIHH", tag, channels, rate, rate * align, align, bits)
    body = wave + struct.pack("<I", len(fmt)) + fmt + before_data
    if data:
        body += b"data" + struct.pack("<I", len(frames)) + frames
    return b"RIFF" + struct.pack("<I", len(body)) + body


def _blk(tag, *fields):
    body = b"".join(struct.pack(">I", f & 0xFFFFFFFF) for f in fields)
    return tag + struct.pack(">I", len(body)) + body


def _text(offset, s, pad=0):
    body = struct.pack(">I", offset) + s.encode("latin-1") + b"\0" + bytes(pad)
    return b"TEXT" + struct.pack(">I", len(body)) + body


def imus(pcm, events, rate=22050, bits=16, channels=1, endian=0, frmt_at=None, map_tag=b"MAP "):
    """An iMUS file of the PCM `pcm` (bytes) with a map of our own: FRMT (the data's offset, endianness, word size, rate,
    channels), then `events(d0, n)`, the other blocks (d0 the offset of the data in the file, n its length).
    `frmt_at`: another offset in FRMT (a map that the data does not follow); `map_tag`: another tag than 'MAP '."""
    def build(d0):
        m = _blk(b"FRMT", d0 if frmt_at is None else frmt_at, endian, bits, rate, channels) + b"".join(events(d0, len(pcm)))
        return map_tag + struct.pack(">I", len(m)) + m
    head = 16 + len(build(0))
    body = build(head) + b"DATA" + struct.pack(">I", len(pcm)) + pcm
    return b"iMUS" + struct.pack(">I", len(body)) + body


def _loop(d0, n):
    """One region and a jump back to its start (hook 0: taken unless the hook is 128), STOP."""
    return [_blk(b"REGN", d0, n), _blk(b"JUMP", d0 + n, d0, 0, 0), _blk(b"STOP", d0 + n)]


def _marked(d0, n):
    """A SYNC block and a marker at the start, two regions with markers between them ("_end" and "exit", which iMUSE's
    triggers would look for), a loop jump with a fade of 100 ms, STOP."""
    h = (n // 4) * 2
    return [_blk(b"SYNC", d0, 0), _text(d0, "start"), _blk(b"REGN", d0, h), _text(d0 + h, "_end"), _text(d0 + h, "exit"),
            _blk(b"REGN", d0 + h, n - h), _blk(b"JUMP", d0 + n, d0, 0, 100), _blk(b"STOP", d0 + n)]


def _hook(d0, n):
    """A jump in the middle back to the start taken only with hook 5, then the loop jump at the end."""
    h = (n // 4) * 2
    return [_blk(b"REGN", d0, h), _blk(b"JUMP", d0 + h, d0, 5, 0), _blk(b"REGN", d0 + h, n - h),
            _blk(b"JUMP", d0 + n, d0, 0, 0), _blk(b"STOP", d0 + n)]


def _once(d0, n):
    return [_blk(b"REGN", d0, n), _blk(b"STOP", d0 + n)]


def _no_stop(d0, n):
    return [_blk(b"REGN", d0, n)]


def _unknown(d0, n):
    return [_blk(b"ZZZZ", d0, 1), _blk(b"REGN", d0, n), _blk(b"STOP", d0 + n)]


def _big(d0, n):
    return [_blk(b"REGN", d0, n), _blk(b"SYNC", d0, *([0] * 520)), _blk(b"STOP", d0 + n)]


def mcmp_one(head, pcm):
    """An MCMP file whose sound data is one stored block (codec 0, any size), after the stored header."""
    blocks = [(0, len(head), head), (0, len(pcm), pcm)]
    names = b"NULL\0VIMA\0"
    table = b"".join(struct.pack(">BII", c, n, len(d)) for c, n, d in blocks)
    return b"MCMP" + struct.pack(">H", len(blocks)) + table + struct.pack(">H", len(names)) + names + b"".join(d for _, _, d in blocks)


def _mono16(seconds, freq, rate=22050):
    return _pcm(_tone(int(seconds * rate) & ~1, rate, freq), 16)


# the sound effects of other formats (ims_formats): name, file
IMS_FORMATS = [
    ("ims_8m.wav", wav(1.0, bits=8)),
    ("ims_16s.wav", wav(1.0, channels=2, freq=500.0)),
    ("ims_8s.wav", wav(1.0, rate=11025, bits=8, channels=2)),
    ("ims_44k.wav", wav(1.0, rate=44100)),
    ("ims_11k.wav", wav(1.0, rate=11025)),
    ("ims_list.wav", wav(1.0, before_data=b"LIST" + struct.pack("<I", 12) + b"INFOISFT\0\0\0\0")),
    ("ims_float.wav", wav(0.5, bits=32, tag=3)),
    ("ims_nodata.wav", wav(0.5, data=False)),
    ("ims_notwave.wav", wav(0.5, wave=b"WAVEJUNK")),
    ("ims_tone.aif", F.aiff(0.5)),
    ("ims_44k.aif", F.aiff(0.5, rate=44100)),
    ("ims_11k.aif", F.aiff(0.5, rate=11025)),
    ("ims_aifc.aif", F.aiff(0.5).replace(b"AIFFCOMM", b"AIFCCOMM")),
    ("ims_nossnd.aif", F.aiff(0.5).replace(b"SSND", b"XSND")),
    ("ims_nofrmt.imu", imus(_mono16(0.5, 300.0), _once).replace(b"FRMT", b"FRMX", 1)),
    ("ims_loop.imu", imus(_mono16(1.0, 300.0), _loop)),
    ("ims_mark.imu", imus(_mono16(1.0, 350.0), _marked)),
    ("ims_le.imu", imus(_mono16(1.0, 400.0), _loop, endian=1)),
    ("ims_st.imu", imus(_pcm(_tone(22050, 22050, 450.0, 2), 16, big=True), _loop, channels=2)),
    ("ims_8.imu", imus(_pcm(_tone(22050, 22050, 500.0), 8), _loop, bits=8)),
    ("ims_12.imu", imus(_pcm(_tone(22050, 22050, 550.0), 12), _loop, bits=12)),
    ("ims_once.imu", imus(_mono16(0.5, 600.0), _once)),
    ("ims_mcmp.imu", F.mcmp(*F.imus_split(imus(_mono16(0.5, 600.0), _once)))),
    ("ims_mcmpw.wav", F.mcmp(*F.wav_split(F.wav(0.5)))),
]

# iMUS files with broken maps (ims_maps)
IMS_MAPS = [
    ("ims_badtag.imu", imus(_mono16(0.5, 300.0), _once, map_tag=b"PAM ")),
    ("ims_badoff.imu", imus(_mono16(0.5, 300.0), _once, frmt_at=7)),
    ("ims_big.imu", imus(_mono16(0.5, 300.0), _big)),
    ("ims_unknown.imu", imus(_mono16(0.5, 300.0), _unknown)),
    ("ims_nostop.imu", imus(_mono16(0.5, 300.0), _no_stop)),
]

# the sound with hook jumps (ims_hooks) and the costume that plays the loop (IMLS: play, stop looping, stop)
IMS_HOOK = imus(_mono16(1.0, 320.0), _hook)
IMS_COSTUME = ([("IMLS", -1, "ims_loop.imu"), ("IMLS", -1, "ims_hook.imu,100,30,90,1"), ("LUAV", -1, "IMS_LV")],
               [("play", 200, [(0, [(0, 0)]), (1, [(0, 0)]), (2, [(0, 1), (100, 2)])]),
                ("unloop", 200, [(0, [(0, 2)]), (1, [(0, 2)]), (2, [(0, 3)])]),
                ("stop", 200, [(0, [(0, 1)]), (1, [(0, 1)]), (2, [(0, 4)])])])

# many small sounds (ims_cache, ims_tracks): more than the 32 of the cache and the tracks
IMS_MANY = ["ims_m%02d.wav" % i for i in range(1, 41)]
# and forty more that only ims_cache loads (each load a new id)
IMS_CACHE = ["ims_c%02d.wav" % i for i in range(1, 41)]


def files():
    out = dict(IMS_FORMATS)
    out.update(IMS_MAPS)
    out["ims_hook.imu"] = IMS_HOOK
    out["ims_sfx.cos"] = F.costume(*IMS_COSTUME)
    for i, name in enumerate(IMS_MANY):
        out[name] = F.wav(0.2, freq=200.0 + 20 * i)
    for i, name in enumerate(IMS_CACHE):
        out[name] = F.wav(0.1, freq=300.0 + 20 * i)
    # voices: one stored block of the whole sound (with a lip sync file), stored blocks of 8 KB, 2 s
    head, pcm = F.wav_split(F.wav(1.5, freq=180.0))
    out["imsv01.wav"] = mcmp_one(head, pcm)
    out["imsv01.lip"] = F.lip([(0, 0x64), (30, 0x6F), (60, 0x66)], 90)
    head, pcm = F.wav_split(F.wav(2.0, freq=210.0))
    out["imsv02.wav"] = F.mcmp(head, pcm, vima_blocks=False)
    out["imsv02.lip"] = F.lip([(0, 0x6F), (50, 0x64)], 120)
    # music under the names of the state table (ims_states): two files of the same attribute (21, states 1040-1044), the
    # file of the hook-2 states 1323 and 1328, a stereo file with a marked loop that fades, an 8-bit one, one with its
    # sound in one stored MCMP block, a RIFF one (as the voices) for a state of transition 2
    out["1040 - Festival Wet.IMC"] = imus(_mono16(2.0, 262.0), _loop)
    out["1041 - Festival Dry.IMC"] = imus(_mono16(2.0, 294.0), _marked)
    out["1323 - Sewer Maze.IMC"] = imus(_mono16(2.0, 330.0), _hook)
    out["1010 - Ledge.IMC"] = imus(_pcm(_tone(22050, 22050, 349.0, 2), 16, big=True), _marked, channels=2)
    out["1011 - Roof.IMC"] = imus(_pcm(_tone(44100, 22050, 392.0), 8), _loop, bits=8)
    out["1020 - Tube Room.IMC"] = mcmp_one(*F.imus_split(imus(_mono16(2.0, 440.0), _loop)))
    out["1060 - Real World.IMC"] = F.mcmp(*F.wav_split(F.wav(2.0, freq=494.0)))
    out["1070 - Stump Room.IMC"] = imus(_mono16(2.0, 523.0), _loop)
    return out
