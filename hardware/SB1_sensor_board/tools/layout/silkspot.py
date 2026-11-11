"""Free spots for a silk text box on one side of a written SB1 board. usage: silkspot.py board side width height"""
import sys, math
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall
F, SIDE, TW, TH = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
import os
H_ = float(os.environ.get('SB1_H', '56.5'))
b = sx.parse(open(F).read())
def rot(x, y, r):
    a = math.radians(r); return x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a)
obs = []
for f in findall(b, 'footprint'):
    at = find(f, 'at'); X, Y = float(at[1]) - 50, float(at[2]) - 40; R = float(at[3]) if len(at) > 3 else 0
    side = 'B' if str(find(f, 'layer')[1]) == 'B.Cu' else 'F'
    crt = ('F' if SIDE == 'F' else 'B') + '.CrtYd'
    for g in f:
        if isinstance(g, list) and g[0] in ('fp_line', 'fp_rect', 'fp_circle') and str(find(g, 'layer')[1]) == crt:
            if g[0] == 'fp_circle':
                c, e = find(g, 'center'), find(g, 'end'); cx, cy = float(c[1]), float(c[2]); r = math.hypot(float(e[1]) - cx, float(e[2]) - cy)
                dx, dy = rot(cx, cy, R); obs.append((X + dx - r, Y + dy - r, X + dx + r, Y + dy + r)); continue
            q = [rot(float(find(g, k)[1]), float(find(g, k)[2]), R) for k in ('start', 'end')]
            obs.append((X + min(p[0] for p in q), Y + min(p[1] for p in q), X + max(p[0] for p in q), Y + max(p[1] for p in q)))
    for p in findall(f, 'pad'):
        if str(p[2]) in ('thru_hole', 'np_thru_hole') or side == SIDE:
            pa = find(p, 'at'); dx, dy = rot(float(pa[1]), float(pa[2]), R); sz = find(p, 'size'); w, h = float(sz[1]), float(sz[2])
            m = max(w, h) / 2 + 0.3
            obs.append((X + dx - m, Y + dy - m, X + dx + m, Y + dy + m))
def free(x, y):
    r = (x - TW / 2, y - TH / 2, x + TW / 2, y + TH / 2)
    if r[0] < 1 or r[1] < 0.8 or r[2] > 69 or r[3] > H_ - 1:
        return False
    return not any(r[0] < o[2] and o[0] < r[2] and r[1] < o[3] and o[1] < r[3] for o in obs)
spots = [(x / 2, y / 2) for y in range(2, int(H_ * 2)) for x in range(2, 140) if free(x / 2, y / 2)]
print(len(spots), 'free centres')
# cluster: print a few distinct ones
seen = []
for s in spots:
    if all(abs(s[0] - t[0]) > 6 or abs(s[1] - t[1]) > 4 for t in seen):
        seen.append(s)
print(seen[:20])
import os
for q in os.environ.get("CHK","").split(";"):
    if q: x, y = map(float, q.split(",")); print("check", q, free(x, y))
