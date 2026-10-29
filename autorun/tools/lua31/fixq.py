import sys
lines=open(sys.argv[1]).read().split('\n')
out=[];i=0;bs=chr(92)
while i<len(lines):
    l=lines[i]
    while l.count('"')%2==1 and i+1<len(lines):
        i+=1; l=l+bs+'n'+lines[i]
    out.append(l); i+=1
open(sys.argv[1],'w').write('\n'.join(out))
