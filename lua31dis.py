import struct, sys
OPS = """ENDCODE PUSHNIL PUSHNIL0 PUSHNUMBER PUSHNUMBER0 PUSHNUMBER1 PUSHNUMBER2 PUSHNUMBERW
PUSHCONSTANT PUSHCONSTANT0 PUSHCONSTANT1 PUSHCONSTANT2 PUSHCONSTANT3 PUSHCONSTANT4 PUSHCONSTANT5 PUSHCONSTANT6 PUSHCONSTANT7 PUSHCONSTANTW
PUSHUPVALUE PUSHUPVALUE0 PUSHUPVALUE1
PUSHLOCAL PUSHLOCAL0 PUSHLOCAL1 PUSHLOCAL2 PUSHLOCAL3 PUSHLOCAL4 PUSHLOCAL5 PUSHLOCAL6 PUSHLOCAL7
GETGLOBAL GETGLOBAL0 GETGLOBAL1 GETGLOBAL2 GETGLOBAL3 GETGLOBAL4 GETGLOBAL5 GETGLOBAL6 GETGLOBAL7 GETGLOBALW
GETTABLE
GETDOTTED GETDOTTED0 GETDOTTED1 GETDOTTED2 GETDOTTED3 GETDOTTED4 GETDOTTED5 GETDOTTED6 GETDOTTED7 GETDOTTEDW
PUSHSELF PUSHSELF0 PUSHSELF1 PUSHSELF2 PUSHSELF3 PUSHSELF4 PUSHSELF5 PUSHSELF6 PUSHSELF7 PUSHSELFW
CREATEARRAY CREATEARRAY0 CREATEARRAY1 CREATEARRAYW
SETLOCAL SETLOCAL0 SETLOCAL1 SETLOCAL2 SETLOCAL3 SETLOCAL4 SETLOCAL5 SETLOCAL6 SETLOCAL7
SETGLOBAL SETGLOBAL0 SETGLOBAL1 SETGLOBAL2 SETGLOBAL3 SETGLOBAL4 SETGLOBAL5 SETGLOBAL6 SETGLOBAL7 SETGLOBALW
SETTABLE0 SETTABLE SETLIST SETLIST0 SETLISTW SETMAP SETMAP0
EQOP NEQOP LTOP LEOP GTOP GEOP ADDOP SUBOP MULTOP DIVOP POWOP CONCOP MINUSOP NOTOP
ONTJMP ONTJMPW ONFJMP ONFJMPW JMP JMPW IFFJMP IFFJMPW IFTUPJMP IFTUPJMPW IFFUPJMP IFFUPJMPW
CLOSURE CLOSURE0 CLOSURE1 CALLFUNC CALLFUNC0 CALLFUNC1 RETCODE SETLINE SETLINEW POP POP0 POP1""".split()
def size(name):
    if name in ("SETLISTW",): return 4
    if name in ("SETLIST","CALLFUNC"): return 3
    if name.endswith("W") and name not in ("ENDCODE",): return 3
    if name in ("PUSHNIL","PUSHNUMBER","PUSHCONSTANT","PUSHUPVALUE","PUSHLOCAL","GETGLOBAL","GETDOTTED","PUSHSELF","CREATEARRAY","SETLOCAL","SETGLOBAL","SETTABLE","SETLIST0","SETMAP","ONTJMP","ONFJMP","JMP","IFFJMP","IFTUPJMP","IFFUPJMP","CLOSURE","CALLFUNC0","CALLFUNC1","RETCODE","SETLINE","POP"): return 2
    return 1
class R:
    def __init__(s,d): s.d=d; s.p=0
    def b(s): v=s.d[s.p]; s.p+=1; return v
    def w(s): v=(s.d[s.p]<<8)|s.d[s.p+1]; s.p+=2; return v
    def sz(s): v=(s.w()<<16)|s.w(); return v
    def f(s):
        v=s.sz(); return struct.unpack(">f", struct.pack(">I", v))[0]
    def ts(s):
        n=s.w()
        if n==0: return None
        x=bytes(c^0xff for c in s.d[s.p:s.p+n]); s.p+=n; return x.rstrip(b"\0").decode("latin1")
def load_func(r):
    fn={}
    fn["line"]=r.w(); fn["file"]=r.ts()
    n=r.sz(); fn["code"]=r.d[r.p:r.p+n]; r.p+=n
    nc=r.w(); consts=[]
    for _ in range(nc):
        c=chr(r.b())
        if c=="N": consts.append(("N",r.f()))
        elif c=="S": consts.append(("S",r.ts()))
        else: consts.append(("F",None))
    fn["consts"]=consts
    nl=r.w(); fn["locals"]=[]
    for _ in range(nl): ln=r.w(); fn["locals"].append((ln,r.ts()))
    fn["subs"]=[]
    while r.b()==ord("#"):
        i=r.w(); fn["subs"].append((i,load_func(r)))
    return fn
def load(path):
    d=open(path,"rb").read(); r=R(d)
    assert r.b()==27 and d[1:4]==b"Lua"; r.p+=3
    ver=r.b(); r.b(); r.p+=4
    return load_func(r)
def dis(fn, indent="", out=sys.stdout):
    pr=lambda *a: print(*a, file=out)
    code=fn["code"]; consts=fn["consts"]; p=2  # first 2 bytes: nlocals/vararg header
    pr(f"{indent}-- function line {fn['line']} locals={[x[1] for x in fn['locals']]}")
    while p<len(code):
        op=OPS[code[p]]; sz=size(op)
        args=list(code[p+1:p+sz])
        if sz==3 and op not in("SETLIST","CALLFUNC"): a=(args[0]<<8)|args[1]
        elif sz>=2: a=args[0]
        else: a=None
        # resolve constants
        txt=op
        base=None
        for nm in ("PUSHCONSTANT","GETGLOBAL","GETDOTTED","PUSHSELF","SETGLOBAL"):
            if op.startswith(nm):
                suf=op[len(nm):]
                idx = a if suf in ("","W") else int(suf)
                c=consts[idx] if idx<len(consts) else None
                txt=f"{op} {c[1] if c else '?'!r}"; break
        else:
            if args: txt=f"{op} {args}"
        pr(f"{indent}{p:4}: {txt}")
        p+=sz
    for i,s in fn["subs"]:
        pr(f"{indent}-- sub #{i}")
        dis(s, indent+"    ", out)
if __name__ == "__main__":
    import os
    # usage: lua31dis.py <file.LUA>            -> disassembly to stdout
    #        lua31dis.py <in_dir> <out_dir>    -> every *.lua/*.LUA in in_dir to out_dir/<name>.txt
    if len(sys.argv) == 2:
        dis(load(sys.argv[1]))
    elif len(sys.argv) == 3:
        os.makedirs(sys.argv[2], exist_ok=True)
        ok = bad = 0
        for name in sorted(os.listdir(sys.argv[1])):
            if not name.lower().endswith(".lua"):
                continue
            try:
                fn = load(os.path.join(sys.argv[1], name))
                with open(os.path.join(sys.argv[2], name + ".txt"), "w", encoding="utf-8") as f:
                    dis(fn, out=f)
                ok += 1
            except Exception as e:
                bad += 1
                print("FAILED", name, e)
        print(ok, "dumped,", bad, "failed")
    else:
        print(__doc__ or "usage: lua31dis.py <file> | <in_dir> <out_dir>")
