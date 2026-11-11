"""Top view of the V (Mainboard-USB front at Y=0, Y toward the room). SB1-A board line apex A -> outer end E (42 mm).
Cable: leaves SB1-A's J3 mouth at board x 34.1, 1.8 mm off the board, heading toward the apex; straight L1; clockwise
U-turn radius r into the triangle; straight L2; clockwise 45 deg bend radius R2; arrives at the MB ZIF mouth heading -X
at Y = YM. Free length between mouths = cable - 2 x insertion."""
import math, json, sys
A=(50.0,35.0); E=(20.3,5.3); u=((E[0]-A[0])/42,(E[1]-A[1])/42); nb=(0.7071068,-0.7071068)
YM=0.95
def P(xs,off): return (A[0]+u[0]*xs+nb[0]*off, A[1]+u[1]*xs+nb[1]*off)
def path(L1,r,R2,xs0=34.1,off0=1.8,n=200):
    pts=[]; S0=P(xs0,off0); t=(-u[0],-u[1])
    x,y=S0; pts.append((x,y))
    x,y=x+t[0]*L1,y+t[1]*L1; pts.append((x,y))
    # clockwise turn: centre on the right of heading
    def arc(x,y,h,rad,ang):
        right=(h[1],-h[0]); cx,cy=x+right[0]*rad,y+right[1]*rad
        a0=math.atan2(y-cy,x-cx); out=[]
        for i in range(1,n+1):
            a=a0-ang*i/n; out.append((cx+rad*math.cos(a),cy+rad*math.sin(a)))
        hh=(math.cos(math.atan2(h[1],h[0])-ang),math.sin(math.atan2(h[1],h[0])-ang))
        return out,hh,(cx,cy)
    o,h,c1=arc(x,y,t,r,math.pi); pts+=o; x,y=o[-1]
    drop=R2*(1-math.cos(math.pi/4))
    L2=(y-drop-YM)/0.7071068
    x,y=x+h[0]*L2,y+h[1]*L2; pts.append((x,y))
    o,h2,c2=arc(x,y,h,R2,math.pi/4); pts+=o
    length=L1+math.pi*r+L2+R2*math.pi/4
    return dict(pts=pts,L2=L2,mouth=o[-1],length=length,c1=c1,h_end=h2)
if __name__=='__main__':
    for total in (51.0,):
      for ins in (3.5,):
        free=total-2*ins
        for r in (5,6,7):
          for R2 in (5,6,8):
            lo,hi=0,30
            for _ in range(80):
                m=(lo+hi)/2
                if path(m,r,R2)['length']<free: lo=m
                else: hi=m
            g=path(lo,r,R2)
            xs=[p[0] for p in g['pts']]; ys=[p[1] for p in g['pts']]
            print(f'r{r} R2 {R2}: L1 {lo:5.2f} L2 {g["L2"]:5.2f} mouth X {g["mouth"][0]:5.2f} Y {g["mouth"][1]:4.2f}  loop X {min(xs):5.1f}-{max(xs):5.1f} Y {min(ys):4.1f}-{max(ys):4.1f}  end heading {tuple(round(v,3) for v in g["h_end"])}')
