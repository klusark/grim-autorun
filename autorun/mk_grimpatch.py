# Writes GRIMDATA/grimpatch.bin for build_original.sh. The text mode of Windows python gives it CRLF line ends,
# which the original needs (it silently runs nothing from an LF-only file).
text = 'PrintDebug("running autorun_all.lua")\nlocal r = dofile("autorun_all.lua")\nPrintDebug("after")\n'
with open("C:/GOG Games/GRIMDATA/grimpatch.bin", "w") as f:
    f.write(text)
