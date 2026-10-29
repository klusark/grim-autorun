# maps the functions of a compiled EMI script to their names: table.key = function (source line)
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
import lua31dis as L
def walk(fn, path, out):
    code = fn["code"]; consts = fn["consts"]; subs = dict(fn["subs"])
    p = 2; lastg = None; lasts = None
    while p < len(code):
        op = L.OPS[code[p]]; sz = L.size(op); args = list(code[p+1:p+sz])
        if sz == 3 and op not in ("SETLIST", "CALLFUNC"): a = (args[0] << 8) | args[1]
        elif sz >= 2: a = args[0]
        else: a = None
        for nm in ("PUSHCONSTANT", "GETGLOBAL", "GETDOTTED", "PUSHSELF"):
            if op.startswith(nm):
                suf = op[len(nm):]
                idx = a if suf in ("", "W") else int(suf)
                c = consts[idx] if idx < len(consts) else None
                if nm == "GETGLOBAL" and c and c[0] == "S": lastg = c[1]
                if nm == "GETDOTTED" and c and c[0] == "S": lastg = (lastg or "?") + "." + c[1]
                if nm == "PUSHCONSTANT" and c:
                    if c[0] == "S": lasts = c[1]
                    elif c[0] == "F" and idx in subs:
                        out.append((f"{lastg}.{lasts}", subs[idx]["line"], path))
                break
        p += sz
    for i, s in fn["subs"]:
        walk(s, path + "/" + str(i), out)
for f in sys.argv[1:]:
    out = []
    walk(L.load(f), os.path.basename(f), out)
    for name, line, path in out:
        print(f"{os.path.basename(f)}\t{line}\t{name}")
