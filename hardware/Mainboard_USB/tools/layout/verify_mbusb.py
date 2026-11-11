"""Rule checks for Mainboard-USB rev A (2026-10-31), read back from the written .kicad_pcb, independent of the
placement table. Checks: courtyards per side; through-hole pins under the other side's parts; M3 hole keep-outs
(screw head on the front, nut / bracket boss on the back); the two front FFC bands (only the ZIFs may sit there);
front parts under the SB1 V no taller than V_MAX; back parts off the adapter parking pads and zip-tie slots
(the UART / I2C headers sit beside their pads, not on them); through-hole pin stubs
may sit under the socketed VEML7700 breakout J14 (~11 mm up); edges (USB-C J1 is meant to be at the edge); nets.

usage: verify_mbusb.py board.kicad_pcb netlist_report.csv [env.json]
"""
import sys, math, csv, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall

F, NETLIST = sys.argv[1], sys.argv[2]
ENV = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else {}
W, H = 100.0, 121.0
OX, OY = 50.0, 40.0
HOLES = {'H1': (4, 4), 'H2': (96, 4), 'H3': (4, 86), 'H4': (96, 86), 'H5': (32, 15), 'H6': (68, 15),
         'H7': (32, 77), 'H8': (68, 77), 'H9': (4, 117), 'H10': (96, 117)}
FRONT_R, BACK_R = 3.5, 3.5                 # M3 pan head 5.5 mm / bracket boss or nut 6.4 mm A/F, + margin
# FFC path on the front (loop routing, 11/4): from each ZIF mouth (X 33.0 / 67.0) in toward the apex, where the cable
# arrives from its loop, full ZIF height
FFC_BANDS = {'J2': (27.0, 36.0, 38.87, 65.0), 'J3': (54.0, 36.0, 67.0, 65.0)}
V_RECT, V_MAX = (20.3, 8.0, 79.7, 84.0), 12.0
EDGE_FREE = {'J1'}
OVERHANG = {'J4', 'J5', 'J6', 'J7'}     # CP2102 sticks (in the socket courtyards) hang past the bottom edge on purpose (11/01)
RAISED = {'J14'}                           # socketed breakout ~11 mm up: other parts' pin stubs may sit under it
b = sx.parse(open(F).read())


def rot(x, y, r):
    a = math.radians(r); c, s = math.cos(a), math.sin(a)
    return x * c + y * s, -x * s + y * c


def overlap(a, c):
    return a[0] < c[2] - 1e-6 and c[0] < a[2] - 1e-6 and a[1] < c[3] - 1e-6 and c[1] < a[3] - 1e-6


def rect_circle(rc, cx, cy):
    nx, ny = min(max(cx, rc[0]), rc[2]), min(max(cy, rc[1]), rc[3])
    return math.hypot(nx - cx, ny - cy)


def height(fp):
    for k, h in (('Molex_200528', 1.9), ('USB_C_Receptacle', 3.3), ('CP_Radial_D8', 12.0),
                 ('MountingHole', 0.0), ('PinHeader', 8.5)):
        if k in fp:
            return h
    return 2.5


FPS = {}
for f in findall(b, 'footprint'):
    ref = next(str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference')
    at = find(f, 'at'); X, Y = float(at[1]) - OX, float(at[2]) - OY; R = float(at[3]) if len(at) > 3 else 0
    side = 'B' if str(find(f, 'layer')[1]) == 'B.Cu' else 'F'
    crt = []
    for g in f:
        if not (isinstance(g, list) and g[0] in ('fp_line', 'fp_rect', 'fp_circle', 'fp_arc', 'fp_poly')):
            continue
        lay = str(find(g, 'layer')[1])
        if 'CrtYd' not in lay:
            continue
        if g[0] == 'fp_circle':
            c, e = find(g, 'center'), find(g, 'end'); cx, cy = float(c[1]), float(c[2])
            rr = math.hypot(float(e[1]) - cx, float(e[2]) - cy)
            pts = [(cx - rr, cy - rr), (cx + rr, cy + rr)]
        elif g[0] == 'fp_poly':
            pts = [(float(p[1]), float(p[2])) for p in find(g, 'pts')[1:]]
        else:
            pts = [(float(find(g, k)[1]), float(find(g, k)[2])) for k in ('start', 'end', 'mid') if find(g, k)]
            if g[0] == 'fp_rect':
                pts += [(pts[0][0], pts[1][1]), (pts[1][0], pts[0][1])]
        q = [(X + rot(px, py, R)[0], Y + rot(px, py, R)[1]) for px, py in pts]
        crt.append((lay[0], (min(p[0] for p in q), min(p[1] for p in q), max(p[0] for p in q), max(p[1] for p in q))))
    pads = []
    for p in findall(f, 'pad'):
        pa = find(p, 'at'); dx, dy = rot(float(pa[1]), float(pa[2]), R)
        sz = find(p, 'size'); w, h = float(sz[1]), float(sz[2])
        if round((float(pa[3]) if len(pa) > 3 else 0) - R) % 180 == 90:
            w, h = h, w
        net = find(p, 'net')
        cx, cy = X + dx, Y + dy
        pads.append(dict(num=str(p[1]), rc=(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2),
                         net=str(net[1]) if net else '', kind=str(p[2])))
    FPS[ref] = dict(side=side, crt=crt, pads=pads, fp=str(f[1]), h=height(str(f[1])))


def own(ref):
    A = FPS[ref]
    return [rc for s, rc in A['crt'] if s == A['side']]


probs = []
refs = sorted(FPS)
# 1. same-side courtyards
for i, a in enumerate(refs):
    for c in refs[i + 1:]:
        if a in HOLES or c in HOLES or FPS[a]['side'] != FPS[c]['side']:
            continue
        if any(overlap(ra, rc) for ra in own(a) for rc in own(c)):
            probs.append(f'courtyards {a}/{c} overlap ({FPS[a]["side"]})')
# 2. through-hole pins under the other side's parts
for a in refs:
    for p in FPS[a]['pads']:
        if p['kind'] != 'thru_hole':
            continue
        for c in refs:
            if c != a and c not in HOLES and c not in RAISED and FPS[c]['side'] != FPS[a]['side'] and any(overlap(p['rc'], rc) for rc in own(c)):
                probs.append(f'{a}.{p["num"]} pin under {c} (other side)')
# 3. M3 holes
for a in refs:
    if a in HOLES:
        continue
    for hn, (hx, hy) in HOLES.items():
        r = FRONT_R if FPS[a]['side'] == 'F' else BACK_R
        if any(rect_circle(rc, hx, hy) < r - 1e-6 for rc in own(a)):
            probs.append(f'{a} ({FPS[a]["side"]}) inside the {hn} keep-out')
        if any(p['kind'] == 'thru_hole' and rect_circle(p['rc'], hx, hy) < max(FRONT_R, BACK_R) - 1e-6 for p in FPS[a]['pads']):
            probs.append(f'{a} through-hole pin inside the {hn} keep-out')
# 4. front: FFC bands and the V
for a in refs:
    A = FPS[a]
    if A['side'] != 'F' or a in HOLES:
        continue
    for z, band in FFC_BANDS.items():
        if a not in FFC_BANDS and any(overlap(rc, band) for rc in own(a)):
            probs.append(f'{a} in the {z} FFC band')
    if A['h'] > V_MAX and any(overlap(rc, V_RECT) for rc in own(a)):
        probs.append(f'{a} ({A["h"]:g} mm) under the SB1 V')
# 5. back: parking pads and slots
pads_b = [tuple(p[:4]) for p in ENV.get('MB_PADS', [])]
slots = [(cx - 0.8, cy - 2.0, cx + 0.8, cy + 2.0) for cx, cy in ENV.get('MB_SLOTS', [])]
for a in refs:
    A = FPS[a]
    if a in HOLES:
        continue
    if A['side'] == 'B' and any(overlap(rc, pr) for rc in own(a) for pr in pads_b):
        probs.append(f'{a} on an adapter parking pad (back)')
    if any(overlap(rc, s) for rc in own(a) for s in slots):
        probs.append(f'{a} over a zip-tie slot')
for (x0, y0, x1, y1) in slots:
    for hn, (hx, hy) in HOLES.items():
        if rect_circle((x0, y0, x1, y1), hx, hy) < BACK_R:
            probs.append(f'slot at {x0 + 0.8:g},{y0 + 2:g} inside the {hn} keep-out')
    if x0 < 1 or y0 < 1 or x1 > W - 1 or y1 > H - 1:
        probs.append(f'slot at {x0 + 0.8:g},{y0 + 2:g} too close to the edge')
# 6. edges
edge = []
for a in refs:
    for p in FPS[a]['pads']:
        if p['kind'] == 'np_thru_hole' or a in EDGE_FREE:
            continue
        d = min(p['rc'][0], p['rc'][1], W - p['rc'][2], H - p['rc'][3])
        if d < 0.5:
            edge.append(f'{a}.{p["num"]} {d:.2f}')
    if a not in HOLES and a not in EDGE_FREE and a not in OVERHANG and any(rc[0] < -0.01 or rc[1] < -0.01 or rc[2] > W + 0.01 or rc[3] > H + 0.01 for rc in own(a)):
        probs.append(f'{a} courtyard past the board edge')
# 7. nets
rows = [r for r in csv.DictReader(open(NETLIST)) if not r['Ref'].startswith('#')]
got = {}
for a, A in FPS.items():
    for p in A['pads']:
        got.setdefault((a, p['num']), set()).add(p['net'])
miss = [(r['Ref'], r['Pin']) for r in rows if (r['Ref'], r['Pin']) not in got]
wrong = [(r['Ref'], r['Pin']) for r in rows if (r['Ref'], r['Pin']) in got and not any(n.split('/')[-1] == r['Net'] for n in got[(r['Ref'], r['Pin'])])]

print('footprints:', len(FPS), '| front', sum(1 for A in FPS.values() if A['side'] == 'F'), '| back', sum(1 for A in FPS.values() if A['side'] == 'B'))
print('rule problems:', len(probs))
for p in probs:
    print('  ', p)
print('pads within 0.5 mm of the edge:', edge or 'none')
print('netlist pins without a pad:', miss or 'none', '| net mismatches:', wrong or 'none')
