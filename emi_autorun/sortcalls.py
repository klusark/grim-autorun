import re,glob,os,collections
hist=collections.Counter(); neg=[]; dyn=[]
per=collections.defaultdict(collections.Counter)
for f in sorted(glob.glob('luadis/*.txt')):
    L=open(f).read().split('\n')
    name=os.path.basename(f)[:-4]
    for i,l in enumerate(L):
        m=re.search(r"(PUSHSELF\w*|GETDOTTED\w*|PUSHCONSTANT\w*|SETGLOBAL\w*|GETGLOBAL\w*) '(set_sortorder|SetActorSortOrder|SetLayerSortOrder|set_layer_sortorder|sortorder|[a-z_]*sortorder[a-z_]*)'",l)
        if not m: continue
        kind=m.group(2)
        # collect following ops until CALLFUNC
        val=None; neg_flag=False; ops=[]
        for k in range(i+1,min(i+8,len(L))):
            t=L[k].strip()
            ops.append(t)
            if 'CALLFUNC' in t: break
            mm=re.search(r"PUSHNUMBER \[(\d+)\]",t)
            if mm: val=int(mm.group(1))
            elif 'PUSHNUMBER0' in t: val=0
            elif 'PUSHNUMBER1' in t: val=1
            elif 'PUSHNUMBER2' in t: val=2
            mw=re.search(r"PUSHNUMBERW \[(\d+), ?(\d+)\]",t)
            if mw: val=(int(mw.group(1))<<8)|int(mw.group(2))
            mc=re.search(r"PUSHCONSTANT\w* (-?\d+\.?\d*)$",t)
            if mc: val=float(mc.group(1))
            if 'MINUSOP' in t: neg_flag=True
        hist[(kind,val,neg_flag)]+=1
        per[name][(kind,val,neg_flag)]+=1
        if neg_flag: neg.append((name,kind,val,i,ops))
        if val is None and 'sortorder' in kind and kind!='sortorder': dyn.append((name,kind,i,ops))
for k,v in sorted(hist.items(), key=lambda x:(x[0][0],str(x[0][1]))): print(k,v)
print('NEGATIVE:',len(neg))
for n in neg: print(n)
print('DYNAMIC:',len(dyn))
for d in dyn[:15]: print(d)
