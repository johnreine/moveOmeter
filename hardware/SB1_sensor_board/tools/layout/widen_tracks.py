"""Widen thin tracks in a routed board in place where clearance allows. usage: widen.py in.kicad_pcb out.kicad_pcb"""
import sys,math,collections
sys.path.insert(0,sys.argv[3] if len(sys.argv)>3 else __import__("os").path.dirname(__import__("os").path.abspath(__file__)));import sx
from sx import find,findall
b=sx.parse(open(sys.argv[1]).read())
PW={'+5V','+5V_6004','/LD2450/+5V_2450','+3V3','/LD6004/A_3V3','/LD6004/A_3V3R','/LD6004/A_SW','/LD2450/B_5V'}
CLP,CLD=0.2,0.1421   # Power class / Default clearance (+ margin below)
M=0.01
def rot(x,y,r):
    a=math.radians(r); return x*math.cos(a)+y*math.sin(a), -x*math.sin(a)+y*math.cos(a)
obj=collections.defaultdict(list)   # layer -> (kind,net,geom)
for f in findall(b,'footprint'):
    at=find(f,'at');X,Y=float(at[1]),float(at[2]);R=float(at[3]) if len(at)>3 else 0
    side='B.Cu' if str(find(f,'layer')[1])=='B.Cu' else 'F.Cu'
    for p in findall(f,'pad'):
        q=find(p,'at');dx,dy=rot(float(q[1]),float(q[2]),R);pr=float(q[3]) if len(q)>3 else R
        sz=find(p,'size');w,h=float(sz[1]),float(sz[2]);a=math.radians(pr)
        hw=abs(w/2*math.cos(a))+abs(h/2*math.sin(a));hh=abs(w/2*math.sin(a))+abs(h/2*math.cos(a))
        n=find(p,'net');n=str(n[-1]) if n else ''
        lays=['F.Cu','B.Cu'] if str(p[2]) in ('thru_hole','np_thru_hole') else [side]
        for L in lays: obj[L].append(('pad',n,(X+dx,Y+dy,hw,hh)))
for v in findall(b,'via'):
    at=find(v,'at');n=str(find(v,'net')[1]);d=float(find(v,'size')[1])
    for L in ('F.Cu','B.Cu'): obj[L].append(('via',n,(float(at[1]),float(at[2]),d/2)))
segs=findall(b,'segment')
def sg(s):
    a=find(s,'start');e=find(s,'end');return (float(a[1]),float(a[2]),float(e[1]),float(e[2]))
for s in segs: obj[str(find(s,'layer')[1])].append(('seg',str(find(s,'net')[1]),s))
def dps(px,py,x1,y1,x2,y2):
    dx,dy=x2-x1,y2-y1;L=dx*dx+dy*dy
    t=0 if L==0 else max(0,min(1,((px-x1)*dx+(py-y1)*dy)/L));return math.hypot(px-x1-t*dx,py-y1-t*dy)
def dss(a,c):
    return min(dps(a[0],a[1],*c),dps(a[2],a[3],*c),dps(c[0],c[1],*a),dps(c[2],c[3],*a)) if not inter(a,c) else 0
def inter(a,c):
    def o(p,q,r): return (q[0]-p[0])*(r[1]-p[1])-(q[1]-p[1])*(r[0]-p[0])
    p1,p2,p3,p4=(a[0],a[1]),(a[2],a[3]),(c[0],c[1]),(c[2],c[3])
    return o(p1,p2,p3)*o(p1,p2,p4)<0 and o(p3,p4,p1)*o(p3,p4,p2)<0
def drect(g,x,y,hw,hh,n=16):
    return min(math.hypot(max(abs(g[0]+(g[2]-g[0])*k/n-x)-hw,0),max(abs(g[1]+(g[3]-g[1])*k/n-y)-hh,0)) for k in range(n+1))
edge=[float(v) for g in b if isinstance(g,list) and g[0]=='gr_rect' and str(find(g,'layer')[1])=='Edge.Cuts' for v in (find(g,'start')[1],find(g,'start')[2],find(g,'end')[1],find(g,'end')[2])]
def room(s):
    """largest half-width allowed by other-net copper"""
    g=sg(s);n=str(find(s,'net')[1]);L=str(find(s,'layer')[1]);best=9
    for k,on,G in obj[L]:
        if on==n: continue
        cl=CLP if (n in PW or on in PW) else CLD
        if k=='pad': d=drect(g,*G)
        elif k=='via': d=dps(G[0],G[1],*g)-G[2]
        else:
            if G is s: continue
            d=dss(g,sg(G))-float(find(G,'width')[1])/2
        best=min(best,d-cl-M)
    for x in (g[0],g[2]): best=min(best,x-edge[0]-0.5-M,edge[2]-x-0.5-M)
    for y in (g[1],g[3]): best=min(best,y-edge[1]-0.5-M,edge[3]-y-0.5-M)
    return best
changed=collections.Counter();left=collections.defaultdict(float)
for _ in range(3):
  for s in segs:
    n=str(find(s,'net')[1]);w=float(find(s,'width')[1]);tgt=0.5 if n in PW else 0.2
    if w>=tgt-1e-6: continue
    hw=room(s);neww=min(tgt,math.floor(2*hw/0.025)*0.025)
    if neww>w+1e-6:
        find(s,'width')[1]=round(neww,4);changed[n]+=1
for s in segs:
    n=str(find(s,'net')[1]);w=float(find(s,'width')[1]);g=sg(s);l=math.hypot(g[2]-g[0],g[3]-g[1])
    lim=0.4 if n in PW else 0.15
    if w<lim-1e-6: left[(n,round(w,3))]+=l
open(sys.argv[2],'w').write(sx.dump(b)+'\n')
print('widened',dict(changed));print('still thin (mm):',{k:round(v,1) for k,v in sorted(left.items())})
