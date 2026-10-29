import re,sys
setname=sys.argv[1]; pts=[tuple(map(float,a.split(','))) for a in sys.argv[2:]]
src=open("ar_nav_data.lua").read()
i=src.index('AR_NAV["%s"]'%setname)
j=src.find('\nAR_NAV[',i+10)
blk=src[i:j if j>0 else len(src)]
names=re.findall(r'"([^"]+)"',blk.split('\tt =')[0].split('n =')[1])
pm=blk.split('p = {')[1].split('adj = {')[0]
polys=[[float(v) for v in re.findall(r'-?[\d.]+',l)] for l in pm.strip().split('\n') if l.strip().startswith('{')]
adj=[[int(x)-1 for x in re.findall(r'\{ (\d+),',l)] for l in blk.split('adj = {')[1].strip().split('\n') if l.strip().startswith('{') ]
def inside(poly,x,y):
    n=len(poly)//3;ins=False;j=n-1
    for k in range(n):
        xk,yk=poly[3*k],poly[3*k+1];xj,yj=poly[3*j],poly[3*j+1]
        if (yk>y)!=(yj>y) and x<(xj-xk)*(y-yk)/(yj-yk)+xk: ins=not ins
        j=k
    return ins
def dist(poly,x,y):
    n=len(poly)//3;b=1e9
    for k in range(n):
        k2=(k+1)%n;ax,ay=poly[3*k],poly[3*k+1];cx,cy=poly[3*k2],poly[3*k2+1]
        dx,dy=cx-ax,cy-ay;l=dx*dx+dy*dy;t=max(0,min(1,((x-ax)*dx+(y-ay)*dy)/l)) if l>1e-9 else 0
        b=min(b,((ax+t*dx-x)**2+(ay+t*dy-y)**2)**.5)
    return b
comp={}
c=0
for s in range(len(polys)):
    if s in comp: continue
    st=[s];comp[s]=c
    while st:
        u=st.pop()
        for v in adj[u]:
            if v not in comp: comp[v]=c;st.append(v)
    c+=1
sizes={k:sum(1 for v in comp.values() if v==k) for k in range(c)}
print('components',sizes)
for p in pts:
    ins=[i for i,q in enumerate(polys) if inside(q,*p)]
    near=sorted(range(len(polys)),key=lambda i:dist(polys[i],*p))[:3]
    print(p,'in',[(i,names[i],comp[i]) for i in ins],'near',[(i,names[i],round(dist(polys[i],*p),2),comp[i]) for i in near])
print('--- without',sys.argv[0])
