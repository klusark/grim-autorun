import re,sys,glob,os
os.chdir('C:/Users/Joel/grim_lua_src')
files=sys.argv[1:]
cur=None
for f in files:
    for l in open(f,errors='replace'):
        m=re.match(r'^([A-Za-z_][\w\.\[\]]*) = function',l)
        if m: cur=m.group(1); continue
        g=re.search(r'([\w\.]+):get\(\)|generic_pickup\(([\w\.]+)\)|([\w\.]+):put_in_limbo\(\)|([\w\.]+):free\(\)|([\w\.]+)\.owner\s*=\s*([\w\.]+)',l)
        if g and cur and 'Actor' not in l:
            print('%s: %s :: %s'%(f,cur,l.strip()[:110]))
