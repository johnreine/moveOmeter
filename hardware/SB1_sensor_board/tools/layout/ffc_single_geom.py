import math
A=(50.0,35.0); u=(-0.7071068,-0.7071068); nb=(0.7071068,-0.7071068)
YM=0.95; OFF=1.8
def P(xs,off): return (A[0]+u[0]*xs+nb[0]*off, A[1]+u[1]*xs+nb[1]*off)
def pathA(r, free, xs0=7.89, n=240):
    """SB1-A with only J7 (near the apex): out along the back toward the outer end, CCW swing 135 deg, into an MB ZIF
    whose mouth faces -X (cable enters heading +X) at Y = YM."""
    xs_s=(A[1]-YM-OFF*0.7071068 - (1+0.7071068)*r + 0.7071068*0)  # placeholder, solved below
    # centre at offset OFF+r from board midline, at board-x xs_s; centre Y must be YM + r
    xs_s=(A[1]-0.7071068*(OFF+r)-YM-r)/0.7071068
    cx,cy=P(xs_s,OFF+r)
    pts=[P(xs0,OFF),P(xs_s,OFF)]
    a0=math.atan2(pts[-1][1]-cy,pts[-1][0]-cx)
    for i in range(1,n+1):
        a=a0+(3*math.pi/4)*i/n; pts.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    L1=xs_s-xs0; arc=3*math.pi/4*r; L2=free-L1-arc
    end=(pts[-1][0]+L2,pts[-1][1]); pts.append(end)
    return dict(pts=pts,mouth=end,L1=L1,L2=L2,c=(cx,cy),r=r)
if __name__=='__main__':
    for r in (5,6,7,8):
        g=pathA(r,44.0); print(r,'L1 %.1f L2 %.1f mouth X %.2f centre (%.1f,%.1f)'%(g['L1'],g['L2'],g['mouth'][0],*g['c']))
