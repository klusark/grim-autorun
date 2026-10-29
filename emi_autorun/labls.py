import struct,glob,os,sys
base='C:/GOG Games/Escape from Monkey Island/'
BS=chr(92)
out=[]
for f in glob.glob(base+'*.m4b'):
    d=open(f,'rb').read()
    n,strsz,stoff=struct.unpack('<III',d[8:20]); stoff-=0x13d0f
    names=bytes(b^0x96 if b else 0 for b in d[stoff:stoff+strsz])
    for i in range(n):
        no,start,size,_=struct.unpack('<IIII',d[20+i*16:36+i*16])
        e=names.index(b'\0',no); nm=names[no:e].decode('latin1').replace(BS,'/').lower()
        out.append((os.path.basename(f),nm,start,size))
import collections
ext=collections.Counter(os.path.splitext(x[1])[1] for x in out)
print(ext.most_common(25))
for x in out:
    if x[1].endswith(('.lua','.lab','.lua.bin','.lc','.luac','.lab')): print(x)
