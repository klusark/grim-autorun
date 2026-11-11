"""The movies of emi_smv.lua: Bink movies (formats.bik) with the SMUSH header of EMI's movies in front, the subtitles of
the movie, as the game's Movies/*.m4b have it: 'SMUSH', then text with every byte xor 0xd2, lines ended by CR LF: an empty
line, the offset of the Bink data in the file (a multiple of 512), BEGINDATA, a line per subtitle (the first frame, the
last frame, the text id, tab separated; the game pads the lines to the offset with a tab and x's) and ENDOFDATA."""
import formats as F


def smush_bik(subtitles, bik):
    """subtitles: [(first frame, last frame, text id)], at least one (the padding is on the last one)."""
    def text(pos, pad):
        lines = ["%d\t%d\t%s" % s for s in subtitles]
        if pad:
            lines[-1] += "\t" + "x" * (pad - 1)
        return "\r\n%d\r\nBEGINDATA\r\n" % pos + "".join(l + "\r\n" for l in lines) + "ENDOFDATA\r\n"

    pos = 512
    while 5 + len(text(pos, 0)) + 2 > pos:
        pos += 512
    pad = pos - 5 - len(text(pos, 0))
    t = text(pos, pad)
    assert 5 + len(t) == pos
    return b"SMUSH" + bytes(b ^ 0xd2 for b in t.encode("ascii")) + bik


def loose_files():
    white = F.bik(160, 120, [(255, 255, 255)] * 45)
    return {
        # 45 white frames (3 s): a subtitle on frames 0-15, one on 20-40
        "Movies/smv_sub.m4b": smush_bik([(0, 15, "/smvt01/"), (20, 40, "/smvt02/")], white),
        # one subtitle after the movie's last frame (100-120): never shown
        "Movies/smv_latesub.m4b": smush_bik([(100, 120, "/smvt03/")], white),
    }
