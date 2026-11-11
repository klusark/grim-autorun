"""The movies of zz_smv.lua (SMUSH, as formats.snm makes them, but put together chunk by chunk): sound in stereo, in the
track form of the Wave chunk, IMA4, more sound than the ring holds, ANNO chunks between the frames, chunks a frame has that
the player does not know, an unknown chunk between the frames, a file cut short, frames without sound and sound without
frames (the player's catching up: late frames are skipped), the Blocky16 buffer swap 2 and BOMP data with raw runs."""
import gzip
import struct

import formats as F

W, H = 160, 120
RATE = 22050
FRAME_US = 66667
SAMPLES = RATE * FRAME_US // 1000000         # (1470 a frame)
WHITE = F.rgb565(255, 255, 255)
GREY = F.rgb565(60, 60, 60)


def _chunk(tag, body):
    return tag + struct.pack(">I", len(body)) + body + (b"\0" if len(body) & 1 else b"")


def bl16(w, h, seq, mode=0, colour=WHITE, swap=0, fill=WHITE, data=None, table=None, size36=None):
    """A Bl16 chunk: the 560-byte frame header (the size at +8 and +12, the sequence number at +16, the mode at +18, the
    buffer swap at +19, the colour the delta buffers start with at +32, the size of mode 5's data at +36, the colour table
    at +40), then the data (mode 0: the whole frame of `colour`)."""
    head = bytearray(560)
    struct.pack_into("<HH", head, 8, w, 0)
    struct.pack_into("<HH", head, 12, h, 0)
    struct.pack_into("<H", head, 16, seq)
    head[18], head[19] = mode, swap
    struct.pack_into("<H", head, 32, fill)
    if size36 is not None:
        struct.pack_into("<I", head, 36, size36)
    for k, v in (table or {}).items():
        struct.pack_into("<H", head, 40 + 2 * k, v)
    if data is None:
        data = struct.pack("<H", colour) * (w * h) if mode == 0 else b""
    return _chunk(b"Bl16", bytes(head) + data)


def wave(samples=SAMPLES, kind="mono", track=None):
    """A Wave chunk of silence: the sample count (big endian) and a VIMA block. kind "mono": step index 0, value 0, codes 0;
    "stereo": the first byte with bit 7 set (its complement is the step index), then the second channel's index and value;
    "ima4": the IMA4 form (the 'IMA4' tag after the VIMA header, a 16-bit start value and a step index, then 4-bit codes).
    track: the other form, a count of -1, the track number, then the count."""
    if kind == "mono":
        data = bytes(3) + bytes(samples // 2 + 8)
    elif kind == "stereo":
        data = b"\xff\0\0" + b"\0\0\0" + bytes(samples + 8)
    elif kind == "ima4":
        data = bytes(3) + b"IMA4" + bytes(3) + bytes(samples // 2 + 8)
    else:
        raise ValueError(kind)
    head = struct.pack(">i", samples) if track is None else struct.pack(">iii", -1, track, samples)
    return _chunk(b"Wave", head + data)


def vima_ops(ops, samples, pos=0, word=0):
    """A mono VIMA block made of codes: ("esc", v) an escape and the 16-bit sample v; ("big", neg) the largest change up
    (down with neg) the step index allows; then codes 0 up to `samples` samples. Most significant bit first."""
    out, acc, nacc = bytearray(), 0, 0

    def put(v, n):
        nonlocal acc, nacc
        acc = (acc << n) | v
        nacc += n
        while nacc >= 8:
            nacc -= 8
            out.append((acc >> nacc) & 0xFF)
        acc &= (1 << nacc) - 1

    head = bytes([pos]) + struct.pack(">h", word)
    for op in ops:
        nbits = F._VIMA_BITS[pos]
        high = 1 << (nbits - 1)
        low = high - 1
        if op[0] == "esc":
            put(low, nbits)
            put(op[1] & 0xFFFF, 16)
            mag = low
        else:
            mag = low - 1
            put((high if op[1] else 0) | mag, nbits)
        pos = max(0, min(88, pos + F._VIMA_MOVES[nbits][mag]))
    if nacc:
        put(0, 8 - nacc)
    return head + bytes(out) + bytes(samples)


def frame(*subs):
    return _chunk(b"FRME", b"".join(subs))


def movie(w, h, chunks, frames=None, channels=1, total=None, cut=None):
    """The SANM: SHDR (the frame count, the size, the time of a frame, the largest chunk), FLHD (Bl16 and the Wave header:
    the rate, the channels, the total size of the sound), then the chunks (frames and others), gzipped. cut: the movie ends
    that many bytes early."""
    if frames is None:
        frames = sum(1 for c in chunks if c[:4] == b"FRME")
    if total is None:
        total = 2 * channels * SAMPLES * frames
    biggest = max(len(c) for c in chunks)
    shdr = bytearray(struct.pack("<BBHHHHHHII", 1, 1, frames, 0, 0, w, h, 0, FRAME_US, biggest))
    shdr += bytes(1024) + struct.pack("<H", 0)
    flhd = (_chunk(b"Bl16", struct.pack("<HHHH", 0, w, h, 2)) + b"Wave" + struct.pack(">I", 8)
            + struct.pack("<II", RATE, channels) + struct.pack("<I", total))
    body = _chunk(b"SHDR", bytes(shdr)) + _chunk(b"FLHD", flhd) + b"".join(chunks)
    data = b"SANM" + struct.pack(">I", len(body)) + body
    if cut:
        data = data[:-cut]
    return gzip.compress(data, mtime=0)


def _white(n, **wave_args):
    return [frame(bl16(W, H, i), wave(**wave_args)) for i in range(n)]


def _swap_movie(mode):
    """640 x 480: two grey frames, raw; frame X (mode 2, swap 1: it becomes delta buffer 1) white at block (10, 10); frame
    Y (mode 2, swap 2: buffer 1 becomes buffer 0, Y buffer 1) white at block (30, 20); then 45 frames of mode 4 (a copy of
    buffer 0: X) or 3 (of buffer 1: Y)."""
    w, h = 640, 480
    u = lambda v: struct.pack("<H", v)       # noqa: E731
    x = F.blocky2(w, h, {(10, 10): b"\xfe" + u(WHITE)})
    y = F.blocky2(w, h, {(30, 20): b"\xfe" + u(WHITE)})
    out = [frame(bl16(w, h, 0, colour=GREY, fill=GREY), wave()), frame(bl16(w, h, 1, colour=GREY, fill=GREY), wave()),
           frame(bl16(w, h, 2, 2, swap=1, fill=GREY, data=x), wave()),
           frame(bl16(w, h, 3, 2, swap=2, fill=GREY, data=y), wave())]
    out += [frame(bl16(w, h, 4 + i, mode, fill=GREY), wave()) for i in range(45)]
    return movie(w, h, out)


def _stripes(w, h):
    """Indexes 0 and 1 (grey and white) of a 640 x 480 frame: in the top half every third pixel of a row white (BOMP has
    to store those as they are), the bottom half grey (runs)."""
    return bytes(1 if y < h // 2 and x % 3 == 0 else 0 for y in range(h) for x in range(w))


def _bomp_movie(mode):
    """640 x 480: two grey frames, then 45 frames of mode 8 (the colour table's indexes, BOMP coded) or 5 (the 16-bit
    pixels, BOMP coded) of _stripes."""
    w, h = 640, 480
    idx = _stripes(w, h)
    out = [frame(bl16(w, h, 0, colour=GREY, fill=GREY), wave()), frame(bl16(w, h, 1, colour=GREY, fill=GREY), wave())]
    if mode == 8:
        b = bl16(w, h, 2, 8, fill=GREY, data=F.bomp(idx), table={0: GREY, 1: WHITE})
    else:
        pixels = b"".join(struct.pack("<H", WHITE if i else GREY) for i in idx)
        b = bl16(w, h, 2, 5, fill=GREY, data=F.bomp(pixels), size36=len(pixels))
    # (the same frame each time: sequence numbers go on)
    for i in range(45):
        out.append(frame(b[:8 + 16] + struct.pack("<H", 2 + i) + b[8 + 18:], wave()))
    return movie(w, h, out)


def _late_movie():
    """160 x 120: 10 grey frames without sound (the player is ahead of the sound: it slows down), 30 frames with sound and
    no picture (behind it: it speeds up, then skips), 60 frames of mode 3 (white: delta buffer 1, which starts white; frames
    that copy a buffer without swapping are the ones skipped when late), then 15 white frames, raw."""
    out = [frame(bl16(W, H, i, colour=GREY)) for i in range(10)]
    out += [frame(wave()) for _ in range(30)]
    out += [frame(bl16(W, H, 10 + i, 3), wave()) for i in range(60)]
    out += [frame(bl16(W, H, 70 + i), wave()) for i in range(15)]
    return movie(W, H, out)


def files():
    out = {}
    # sound: stereo; the track form (track 7, then 8 from frame 22); IMA4; 3 s each
    out["smv_stereo.snm"] = movie(W, H, _white(45, kind="stereo"), channels=2)
    out["smv_track.snm"] = movie(W, H, [frame(bl16(W, H, i), wave(track=7 if i < 22 else 8)) for i in range(45)])
    out["smv_ima4.snm"] = movie(W, H, _white(45, kind="ima4"))
    # VIMA with escapes (a sample stored as it is: 0x7f00, then -0x7f00) and the largest changes after each, up and then
    # down, past the 16-bit range (the decoder clips)
    ops = [("esc", 0x7F00)] + [("big", False)] * 8 + [("esc", -0x7F00)] + [("big", True)] * 8
    vw = _chunk(b"Wave", struct.pack(">i", SAMPLES) + vima_ops(ops, SAMPLES))
    out["smv_vima.snm"] = movie(W, H, [frame(bl16(W, H, i), vw) for i in range(45)])
    # 90 frames (6 s) with a second of sound each: more than the sound's ring of 500000 bytes holds
    out["smv_flood.snm"] = movie(W, H, _white(90, samples=RATE), total=2 * RATE * 90)
    # a first frame with 11 s of sound (490000 bytes: nearly the whole ring before the sound starts), then 44 frames of
    # their own sound
    out["smv_big.snm"] = movie(W, H, [frame(bl16(W, H, 0), wave(245000))] + _white(45)[1:], total=2 * (245000 + 44 * SAMPLES))
    # the header's total size of the sound only 5 frames' worth: the sound stops after them, the frames still have theirs
    out["smv_short.snm"] = movie(W, H, _white(45), total=2 * SAMPLES * 5)
    # an ANNO chunk before every fifth frame (45 frames)
    frames = _white(45)
    out["smv_anno.snm"] = movie(W, H, [c for i, f in enumerate(frames)
                                        for c in ([_chunk(b"ANNO", b"smv annotation %d\0" % i)] if i % 5 == 0 else []) + [f]])
    # frames with chunks the player does not know (TRES, a text resource of other SMUSH games, and ZZZZ), and IACT / FOBJ /
    # PSAD (the chunks of the older SMUSH games)
    tres = _chunk(b"TRES", struct.pack("<9H", 10, 10, 0, 0, 0, 0, 0, 0, 1) + b"smv text\0")
    out["smv_extra.snm"] = movie(W, H, [frame(tres, bl16(W, H, i), _chunk(b"ZZZZ", b"\1\2\3"), wave()) for i in range(45)])
    fobj = _chunk(b"FOBJ", struct.pack("<HHHHHHH", 1, 0, 0, 8, 8, 0, 0) + bytes(64))
    iact = _chunk(b"IACT", struct.pack("<HHHH", 8, 46, 0, 0) + bytes(16))
    psad = _chunk(b"PSAD", struct.pack(">III", 0, 0, 0) + bytes(16))
    out["smv_old.snm"] = movie(W, H, [frame(fobj, iact, psad, bl16(W, H, i), wave()) for i in range(45)])
    # an unknown chunk between frames 15 and 16 of 90 (6 s)
    frames = _white(90)
    out["smv_badtop.snm"] = movie(W, H, frames[:15] + [_chunk(b"ZZZZ", b"smv\0")] + frames[15:])
    # 90 frames, the file cut in the middle of frame 20 (the frames after it gone)
    frames = _white(21)
    out["smv_cut.snm"] = movie(W, H, frames, frames=90, cut=len(frames[-1]) // 2)
    # SHDR's frame count 90, the file 20 frames (1.3 s); and SHDR's count 15 (1 s), the file 90 frames (6 s)
    out["smv_fewer.snm"] = movie(W, H, _white(20), frames=90)
    out["smv_more.snm"] = movie(W, H, _white(90), frames=15)
    # no sound in any frame (the header says there is)
    out["smv_nowave.snm"] = movie(W, H, [frame(bl16(W, H, i)) for i in range(45)])
    out["smv_late.snm"] = _late_movie()
    out["smv_swap4.snm"] = _swap_movie(4)
    out["smv_swap3.snm"] = _swap_movie(3)
    out["smv_bomp8.snm"] = _bomp_movie(8)
    out["smv_bomp5.snm"] = _bomp_movie(5)
    return out
