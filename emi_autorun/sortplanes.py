import struct,glob,os,collections
def parse(path):
    d=open(path,'rb').read(); o=0
    def u32():
        nonlocal o; v=struct.unpack_from('<I',d,o)[0]; o+=4; return v
    def i32():
        nonlocal o; v=struct.unpack_from('<i',d,o)[0]; o+=4; return v
    ns=u32(); setups=[]
    for _ in range(ns):
        nm=d[o:o+128].split(b'\0')[0].decode('latin1'); o+=128
        fl=u32(); o+=fl; o+=12+16+12; setups.append(nm)
    nl=u32(); o+=nl*(32+12+16+4+4+4+12+16)
    nsec=u32(); secs=[]
    for _ in range(nsec):
        nv=u32(); o+=nv*12
        nl2=u32(); nm=d[o:o+nl2].split(b'\0')[0].decode('latin1'); o+=nl2
        sid=u32(); vis=d[o]; o+=1; typ=u32(); nsp=u32()
        sp=[i32() for _ in range(nsp)]; o+=4
        secs.append((nm,typ,vis,sp))
    return setups,secs
allv=collections.Counter(); neg=collections.defaultdict(list)
for f in sorted(glob.glob('setx/*.setb')):
    try: setups,secs=parse(f)
    except Exception as e: print('ERR',f,e); continue
    for nm,typ,vis,sp in secs:
        for si,v in enumerate(sp):
            allv[v]+=1
            if v<0: neg[os.path.basename(f)].append((nm,typ,si,v))
print('value histogram (all sectors, all setups):')
for v,c in sorted(allv.items()): print(' ',v,c)
print()
for f,l in neg.items():
    vals=collections.Counter(x[3] for x in l); types=collections.Counter(x[1] for x in l)
    print(f,dict(vals),'sector types',dict(types),'sectors',len(set(x[0] for x in l)))
