r"""Writes grim.ini from the registry values of the installed game: python -m patches.regtoini <grim.ini>

For the config patch (grim/config.py). Reads HKLM\SOFTWARE\LucasArts Entertainment Company LLC\Grim Fandango\v1.0 from the 32-bit
registry view. Strings that would read back as numbers are quoted, binary values become hex:, see patches/patch/config.c.
"""
import sys
import winreg

KEY = r"SOFTWARE\LucasArts Entertainment Company LLC\Grim Fandango\v1.0"


def is_number(s):
    try:
        float(s)
        return bool(s.strip()) and s == s.strip()
    except ValueError:
        return False


def encode(value, kind):
    if kind == winreg.REG_SZ:
        if is_number(value) or value.startswith(("hex:", '"')) or value != value.strip():
            return '"%s"' % value
        return value
    if kind == winreg.REG_DWORD:
        return str(value)
    return "hex:" + bytes(value).hex()   # REG_BINARY, which is also where the game keeps its numbers


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    lines = ["[Grim]"]
    with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, KEY, 0, winreg.KEY_READ | winreg.KEY_WOW64_32KEY) as k:
        i = 0
        while True:
            try:
                name, value, kind = winreg.EnumValue(k, i)
            except OSError:
                break
            i += 1
            if name.lower() != "version":
                lines.append("%s=%s" % (name, encode(value, kind)))
    open(sys.argv[1], "w", newline="").write("\r\n".join(lines) + "\r\n")
    print("wrote %d values to %s" % (len(lines) - 1, sys.argv[1]))


if __name__ == "__main__":
    main()
