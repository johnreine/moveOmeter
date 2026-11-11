"""GND fan-out (John, 11/7): every SMD pad on GND gets a short track to its own via into the In1 / In2 GND planes, so
no GND pad depends on the outer pours (which the routing chops into islands). Placed before routing and locked, so the
autorouter routes round them.

Rules for each via (0.6 / 0.3, through): clear of every other-net pad by CL, of other vias, of the board edge, outside
the screw keep-outs and the LD2450 solid-ground rule area (vias not allowed there); the stub track (0.3 mm) clear of
other-net pads too. Nearest spot wins, straight out from the pad preferred. ZIF connector (J7): vias only on the
housing side, so the signal pins keep the tail side for their exits. Pads listed in DOUBLE get two vias.
usage: fanout_gnd.py board.kicad_pcb"""
import math, os, sys, uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall

PCB = sys.argv[1]
NET = 'GND'
VIA_D, VIA_DR, STUB_W = 0.6, 0.3, 0.3
CL = 0.2                       # a little over the board's minimum clearance
DOUBLE = set()                 # 11/8: U1.2's second via landed under the IC body and blocked the buck's routing
ZIF = ('J7',)
b = sx.parse(open(PCB).read())
NS = uuid.UUID('6b1f3c2e-9a57-4f0e-8d2e-2c51f0a0d001')


def rot(x, y, r):
    a = math.radians(r)
    return x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a)


edge = None
for g in b:
    if isinstance(g, list) and g[0] == 'gr_rect' and str(find(g, 'layer')[1]) == 'Edge.Cuts':
        s, e = find(g, 'start'), find(g, 'end')
        edge = (float(s[1]), float(s[2]), float(e[1]), float(e[2]))
# ---------------------------------------------------------------- pads, footprint centres, rule areas
pads = []
fpc = {}
for f in findall(b, 'footprint'):
    ref = [str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference'][0]
    at = find(f, 'at'); X, Y = float(at[1]), float(at[2]); R = float(at[3]) if len(at) > 3 else 0.0
    fpc[ref] = (X, Y)
    side = 'B' if str(find(f, 'layer')[1]) == 'B.Cu' else 'F'
    for p in findall(f, 'pad'):
        q = find(p, 'at'); dx, dy = rot(float(q[1]), float(q[2]), R); pr = float(q[3]) if len(q) > 3 else R
        sz = find(p, 'size'); w, h = float(sz[1]), float(sz[2]); a = math.radians(pr)
        hw = abs(w / 2 * math.cos(a)) + abs(h / 2 * math.sin(a)); hh = abs(w / 2 * math.sin(a)) + abs(h / 2 * math.cos(a))
        net = find(p, 'net'); net = str(net[-1]) if net else ''
        pads.append(dict(ref=ref, num=str(p[1]), x=X + dx, y=Y + dy, hw=hw, hh=hh, net=net, kind=str(p[2]), side=side))
holes, noviaz = [], []
for z in findall(b, 'zone'):
    ko = find(z, 'keepout'); nm = find(z, 'name')
    if not ko:
        continue
    rules = {str(k[0]): str(k[1]) for k in ko[1:]}
    pts = [(float(q[1]), float(q[2])) for q in find(find(z, 'polygon'), 'pts')[1:]]
    if rules.get('vias') == 'not_allowed':
        noviaz.append(pts)
vias = [(float(find(v, 'at')[1]), float(find(v, 'at')[2]), float(find(v, 'size')[1])) for v in findall(b, 'via')]


def pip(x, y, pts):
    c = False
    for i in range(len(pts)):
        x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % len(pts)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def d_pt_rect(x, y, p):
    return math.hypot(max(abs(x - p['x']) - p['hw'], 0), max(abs(y - p['y']) - p['hh'], 0))


def d_seg_rect(a, c, p, n=24):
    return min(d_pt_rect(a[0] + (c[0] - a[0]) * k / n, a[1] + (c[1] - a[1]) * k / n, p) for k in range(n + 1))


def via_ok(x, y, own):
    r = VIA_D / 2
    if not (edge[0] + 0.5 + r <= x <= edge[2] - 0.5 - r and edge[1] + 0.5 + r <= y <= edge[3] - 0.5 - r):
        return False
    for pts in noviaz:                                     # rule areas that ban vias (screw keep-outs, LD2450)
        if pip(x, y, pts) or any(math.hypot(x - px, y - py) < r for px, py in pts[::3]):
            return False
    for p in pads:
        if p is own:
            continue
        if p['net'] == NET and p['kind'] == 'smd' and p['side'] != own['side']:
            continue                                       # a GND pad on the other side is fine to sit behind
        if d_pt_rect(x, y, p) < r + CL:
            return False
    return all(math.hypot(x - vx, y - vy) >= (r + vd / 2 + CL) for vx, vy, vd in vias)


def stub_ok(a, c, own):
    for p in pads:
        if p is own or (p['net'] == NET and p['side'] == own['side'] and p['kind'] == 'smd' and p['ref'] == own['ref']):
            continue
        if p['side'] != own['side'] and p['kind'] == 'smd':
            continue
        if p['net'] != NET and d_seg_rect(a, c, p) < STUB_W / 2 + CL:
            return False
    return True


def place(p, avoid):
    best = None
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (0.7071, 0.7071), (-0.7071, 0.7071), (0.7071, -0.7071), (-0.7071, -0.7071)]
    if p['ref'] in ZIF:                                    # housing side only: toward the footprint origin's side
        cx, cy = fpc[p['ref']]
        dx = -1 if p['x'] > cx else 1
        dirs = [(dx, 0)]
    for k, (ux, uy) in enumerate(dirs):
        # start just outside the pad edge in this direction
        ex = p['hw'] * abs(ux) + p['hh'] * abs(uy)
        for step in range(0, 26):
            d = ex + VIA_D / 2 + 0.08 + step * 0.1
            x, y = p['x'] + ux * d, p['y'] + uy * d
            if any(math.hypot(x - ax, y - ay) < VIA_D + CL for ax, ay in avoid):
                continue
            if via_ok(x, y, p) and stub_ok((p['x'], p['y']), (x, y), p):
                cost = d + (0.4 if k >= 4 else 0)
                if best is None or cost < best[0]:
                    best = (cost, x, y)
                break
    return best


def U(*k):
    return str(uuid.uuid5(NS, '/'.join(map(str, k))))


added, failed = [], []
layer = {'F': 'F.Cu', 'B': 'B.Cu'}
for p in sorted([p for p in pads if p['net'] == NET and p['kind'] == 'smd'], key=lambda q: (q['ref'], q['num'], q['x'])):
    n = 2 if (p['ref'], p['num']) in DOUBLE else 1
    mine = []
    for i in range(n):
        got = place(p, mine)
        if not got:
            failed.append(f"{p['ref']}.{p['num']}")
            break
        _, x, y = got
        x, y = round(x, 3), round(y, 3)
        mine.append((x, y))
        vias.append((x, y, VIA_D))
        key = (p['ref'], p['num'], round(p['x'], 2), round(p['y'], 2), i)
        b.append(['segment', ['start', round(p['x'], 4), round(p['y'], 4)], ['end', x, y], ['width', STUB_W],
                  ['locked', 'yes'], ['layer', sx.Q(layer[p['side']])], ['net', sx.Q(NET)], ['uuid', sx.Q(U('fanout_seg', *key))]])
        b.append(['via', ['at', x, y], ['size', VIA_D], ['drill', VIA_DR], ['layers', sx.Q('F.Cu'), sx.Q('B.Cu')],
                  ['locked', 'yes'], ['net', sx.Q(NET)], ['uuid', sx.Q(U('fanout_via', *key))]])
        added.append(f"{p['ref']}.{p['num']}")
# keep the board's closing items (embedded_fonts) last
tail = [g for g in b if isinstance(g, list) and g[0] == 'embedded_fonts']
for g in tail:
    b.remove(g); b.append(g)
open(PCB, 'w').write(sx.dump(b) + '\n')
print(f'GND fan-out: {len(added)} vias on {len(set(added))} pads; no room: {failed or "none"}')
