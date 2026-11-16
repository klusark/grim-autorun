import sys
# Writes GRIMDATA/grimpatch.bin for build_original.sh (or the file named first). The text mode of Windows python gives it CRLF line ends,
# which the original needs (it silently runs nothing from an LF-only file). --once: a second F12 does nothing (the run is not started again)
once = "--once" in sys.argv
if once:
    sys.argv.remove("--once")
text = 'PrintDebug("running autorun_all.lua")\nlocal r = dofile("autorun_all.lua")\nPrintDebug("after")\n'
if once:
    text = 'if AR_INJECTED then\nPrintDebug("already running")\nelse\nAR_INJECTED = TRUE\n' + text + 'end\n'
with open(sys.argv[1] if len(sys.argv) > 1 else "C:/GOG Games/GRIMDATA/grimpatch.bin", "w") as f:
    f.write(text)
