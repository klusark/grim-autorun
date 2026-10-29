import struct,glob,os
base='C:/GOG Games/Escape from Monkey Island/'
BS=chr(92)
n_out=0
for f in glob.glob(base+'*.m4b'):
    d=open(f,'rb').read()
    n,strsz,stoff=struct.unpack('<III',d[8:20]); stoff-=0x13d0f
    names=bytes(b^0x96 if b else 0 for b in d[stoff:stoff+strsz])
    for i in range(n):
        no,start,size,_=struct.unpack('<IIII',d[20+i*16:36+i*16])
        e=names.index(b'\0',no); nm=names[no:e].decode('latin1').replace(BS,'/').lower()
        if nm.endswith('.lua'):
            open('luax/'+os.path.basename(nm),'wb').write(d[start:start+size]); n_out+=1
print(n_out)
