# usage: mk_cmd.py <lua file>: writes GRIMDATA/grimpatch.bin = the Lua code + a closing PrintDebug, CRLF line ends
import sys
code = open(sys.argv[1]).read()
with open("C:/GOG Games/GRIMDATA/grimpatch.bin", "w") as f:
    f.write(code + "\nPrintDebug(\"ORL done\")\n")
