"""Remove vias connected on only one copper layer (post-route clean-up). usage: dangle.py in out"""
import sys,math,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)));import sx
from sx import find,findall
b=sx.parse(open(sys.argv[1]).read())
def rot(x,y,r):
    a=math.radians(r); return x*math.cos(a)+y*math.sin(a), -x*math.sin(a)+y*math.cos(a)
pads=[]
for f in findall(b,'footprint'):
    at=find(f,'at');X,Y=float(at[1]),float(at[2]);R=float(at[3]) if len(at)>3 else 0
    side='B.Cu' if str(find(f,'layer')[1])=='B.Cu' else 'F.Cu'
    for p in findall(f,'pad'):
        q=find(p,'at');dx,dy=rot(float(q[1]),float(q[2]),R);sz=find(p,'size');n=find(p,'net');n=str(n[-1]) if n else ''
        ls=['F.Cu','B.Cu'] if 'thru' in str(p[2]) else [side]
        pads.append((X+dx,Y+dy,max(float(sz[1]),float(sz[2]))/2,n,ls))
segs=[(str(find(s,'layer')[1]),str(find(s,'net')[1]),[(float(find(s,k)[1]),float(find(s,k)[2])) for k in ('start','end')]) for s in findall(b,'segment')]
rm=[]
for v in findall(b,'via'):
    x,y=float(find(v,'at')[1]),float(find(v,'at')[2]);r=float(find(v,'size')[1])/2;n=str(find(v,'net')[1])
    if n=='GND': continue   # GND vias also join the inner planes
    con={}
    for L in ('F.Cu','B.Cu'):
        c=sum(1 for l,sn,pts in segs if l==L and sn==n for px,py in pts if math.hypot(px-x,py-y)<=r)
        c+=sum(1 for px,py,pr,pn,ls in pads if pn==n and L in ls and math.hypot(px-x,py-y)<=pr+r)
        con[L]=c
    if min(con.values())==0:
        rm.append(v); print('dangling via',n,(x,y),con)
        if con['B.Cu']==1:      # only our locked stub reaches it: the stub goes too
            for s in findall(b,'segment'):
                if find(s,'locked') and str(find(s,'net')[1])==n and str(find(s,'layer')[1])=='B.Cu' and \
                   any(math.hypot(float(find(s,k)[1])-x,float(find(s,k)[2])-y)<0.01 for k in ('start','end')):
                    rm.append(s); print('  + stub')
for v in rm: b.remove(v)
open(sys.argv[2],'w').write(sx.dump(b)+'\n'); print('removed',len(rm))
