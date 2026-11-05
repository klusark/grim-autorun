import subprocess,sys,re,collections,os
root=sys.argv[1]; cc=sys.argv[2]
locs=collections.Counter()
for dp,_,fs in os.walk(os.path.join(root,cc)):
    for f in fs:
        if not f.endswith(".o"): continue
        out=subprocess.run(["objdump","-d","-l","--no-show-raw-insn",os.path.join(dp,f)],capture_output=True,text=True,errors="replace").stdout
        loc=None
        for l in out.split("\n"):
            m=re.match(r"^(\S+?\.(?:cpp|h)):(\d+)(?: \(discriminator \d+\))?$",l)
            if m: loc=(m.group(1).replace("\\","/"),int(m.group(2))); continue
            if re.search(r"\t(cvtss2sd|cvtps2pd)\b",l) or re.search(r"\s(cvtss2sd|cvtps2pd)\s",l):
                locs[loc]+=1
print(cc,"surviving float->double conversions:",sum(locs.values()),"in",len(locs),"distinct source lines")
def short(p): return re.sub(r"^.*?/(engines/grim|math|common)/",r"\1/",p) if p else "?"
byf=collections.Counter(short(k[0]) if k else "?" for k in locs)
for f,c in byf.most_common(40): print("  %3d %s"%(c,f))
import json
json.dump([[short(k[0]) if k else "?",k[1] if k else 0,v] for k,v in locs.items()],open("C:/msys64/tmp/surv_%s.json"%cc.replace("+","p"),"w"))
