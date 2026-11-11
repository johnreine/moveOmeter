"""Rule checks for SB1, read back from the written .kicad_pcb (independent of the placer); adapted from TB1's verify3.py.

usage: verify3.py board.kicad_pcb netlist_report.csv
"""
import sys, math, csv, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall

F, NETLIST = sys.argv[1], sys.argv[2]
W, H = 70.0, float(os.environ.get('SB1_H', '56.5'))
OX, OY = 50.0, 40.0
HOLES = {'H1': (3.5, 3.5), 'H2': (66.5, 3.5), 'H3': (3.5, 51.5), 'H4': (66.5, 51.5)}
MOUNT_R, BACK_R = 0.27 * 25.4, 3.3      # 0.27 in front clearance (0.25 in until 10/18 19:18)
USB_CORRIDOR = (-100, -100, -99, -99)
FACE = {'J5': 7.3, 'J4': 6.5}
TAN = {'J5': (1.73, 0.70), 'J4': (1.73, 1.73)}
BUCKS = set()
EDGE_FREE = {'J1', 'J2'}
b = sx.parse(open(F).read())


def rot(x, y, r):
    a = math.radians(r); c, s = math.cos(a), math.sin(a)
    return x * c + y * s, -x * s + y * c


def overlap(a, c):
    return a[0] < c[2] - 1e-6 and c[0] < a[2] - 1e-6 and a[1] < c[3] - 1e-6 and c[1] < a[3] - 1e-6


def rect_circle(rc, cx, cy):
    nx, ny = min(max(cx, rc[0]), rc[2]), min(max(cy, rc[1]), rc[3])
    return math.hypot(nx - cx, ny - cy)


def height(ref, fp):
    for k, h in (('IDC-Header', 9.0), ('USB_C_Receptacle', 3.3), ('CP_Radial_D6.3', 8.0), ('CP_Radial_D8', 12.0),
                 ('TestPoint_Keystone', 5.0), ('MountingHole', 0.0), ('PinHeader', 10.0), ('PinSocket', 10.0)):
        if k in fp:
            return h
    return 2.5


FPS = {}
for f in findall(b, 'footprint'):
    ref = next(str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference')
    at = find(f, 'at'); X, Y = float(at[1]) - OX, float(at[2]) - OY; R = float(at[3]) if len(at) > 3 else 0
    side = 'B' if str(find(f, 'layer')[1]) == 'B.Cu' else 'F'
    crt, fab = [], []
    for g in f:
        if not (isinstance(g, list) and g[0] in ('fp_line', 'fp_rect', 'fp_circle', 'fp_arc', 'fp_poly')):
            continue
        lay = str(find(g, 'layer')[1])
        if g[0] == 'fp_circle':
            c, e = find(g, 'center'), find(g, 'end'); cx, cy = float(c[1]), float(c[2])
            rr = math.hypot(float(e[1]) - cx, float(e[2]) - cy)
            pts = [(cx - rr, cy - rr), (cx + rr, cy + rr), (cx - rr, cy + rr), (cx + rr, cy - rr)]
        elif g[0] == 'fp_poly':
            pts = [(float(p[1]), float(p[2])) for p in find(g, 'pts')[1:]]
        else:
            pts = [(float(find(g, k)[1]), float(find(g, k)[2])) for k in ('start', 'end', 'mid') if find(g, k)]
            if g[0] == 'fp_rect':
                pts += [(pts[0][0], pts[1][1]), (pts[1][0], pts[0][1])]
        q = [(X + rot(px, py, R)[0], Y + rot(px, py, R)[1]) for px, py in pts]
        rc = (min(p[0] for p in q), min(p[1] for p in q), max(p[0] for p in q), max(p[1] for p in q))
        if 'CrtYd' in lay:
            if (side == 'B') != lay.startswith('B.') and g[0] != 'fp_circle':
                pass
            crt.append((lay[0], rc, g[0] == 'fp_circle'))
        elif 'Fab' in lay:
            fab.append(rc)
    pads = []
    for p in findall(f, 'pad'):
        pa = find(p, 'at'); dx, dy = rot(float(pa[1]), float(pa[2]), R)
        sz = find(p, 'size'); w, h = float(sz[1]), float(sz[2])
        pr = (float(pa[3]) if len(pa) > 3 else 0) - R
        if round(pr) % 180 == 90:
            w, h = h, w
        net = find(p, 'net')
        lays = [str(v) for v in find(p, 'layers')[1:]]
        cx, cy = X + dx, Y + dy
        pads.append(dict(num=str(p[1]), x=cx, y=cy, rc=(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2),
                         net=str(net[1]) if net else '', kind=str(p[2]), layers=lays))
    fpid = str(f[1])
    FPS[ref] = dict(side=side, X=X, Y=Y, R=R, crt=crt, fab=fab, pads=pads, fp=fpid, h=height(ref, fpid))

probs = []


def own(ref):
    """this part's courtyard rects on its own side (KiCad flips F.CrtYd to B.CrtYd on the back)"""
    A = FPS[ref]
    return [rc for s, rc, circ in A['crt'] if s == A['side']]


def other_side_crt(ref):
    A = FPS[ref]
    return [rc for s, rc, circ in A['crt'] if s != A['side']]


def bbox(rects):
    return (min(r[0] for r in rects), min(r[1] for r in rects), max(r[2] for r in rects), max(r[3] for r in rects))


MODBODY = {}
J6_BODY = (-100, -100, -99, -99)
J6_SUPPORTS = []

refs = sorted(FPS)
# 1. same-side courtyards (holes excluded: they're handled as circles below)
for i, a in enumerate(refs):
    if a in HOLES:
        continue
    for c in refs[i + 1:]:
        if c in HOLES or FPS[a]['side'] != FPS[c]['side']:
            continue
        if any(overlap(ra, rc) for ra in own(a) for rc in own(c)):
            probs.append(f'courtyards {a}/{c} overlap ({FPS[a]["side"]})')
# 2. through-hole pins under the other side's courtyards; through-hole parts under module bodies
for a in refs:
    A = FPS[a]
    for p in A['pads']:
        if p['kind'] not in ('thru_hole', 'np_thru_hole'):
            continue
        for c in refs:
            if c == a or c in HOLES or FPS[c]['side'] == A['side']:
                continue
            if any(overlap(p['rc'], rc) for rc in own(c)):
                probs.append(f'{a}.{p["num"] or "hole"} pin under {c} (other side)')
    if False:
        for m, mb in MODBODY.items():
            if any(overlap(rc, mb) for rc in own(a)):
                probs.append(f'through-hole {a} under module {m}')
# 3. mount discs / screw heads
for a in refs:
    if a in HOLES:
        continue
    A = FPS[a]
    for hname, (hx, hy) in HOLES.items():
        if A['side'] == 'F' and any(rect_circle(rc, hx, hy) < MOUNT_R - 1e-6 for rc in own(a)):
            probs.append(f'{a} on the front inside the {hname} mount clearance')
        if A['side'] == 'B' and any(rect_circle(rc, hx, hy) < BACK_R - 1e-6 for rc in own(a)):
            probs.append(f'{a} inside the {hname} screw-head keep-out (back)')
        for p in A['pads']:
            if p['kind'] in ('thru_hole', 'np_thru_hole') and rect_circle(p['rc'], hx, hy) < MOUNT_R - 1e-6:
                probs.append(f'{a}.{p["num"]} through-hole pin inside the {hname} mount clearance')
# 4. radar fields of view (front)
for a in refs:
    A = FPS[a]
    if A['side'] != 'F' or a in FACE or a in HOLES:
        continue
    for m, face in FACE.items():
        if A['h'] > face:
            tx, ty = TAN[m]
            hx_, hy_ = tx * (A['h'] - face) + 0.5, ty * (A['h'] - face) + 0.5
            mr = bbox(own(m))
            zone = (mr[0] - hx_, mr[1] - hy_, mr[2] + hx_, mr[3] + hy_)
            if any(overlap(rc, zone) for rc in own(a)) or (a == 'J6' and overlap(J6_BODY, zone)):
                probs.append(f'{a} ({A["h"]:g} mm) in the {m} field of view')
# 5. NFC module rules, USB plug strip
for a in refs:
    A = FPS[a]
    if a == 'J6' or a in HOLES:
        continue
    under = any(overlap(rc, J6_BODY) for rc in own(a))
    if A['side'] == 'F' and under and (A['h'] > 10.5 or a in BUCKS or a.startswith('TP')):
        probs.append(f'{a} ({A["h"]:g} mm) not allowed under the NFC module')
    if A['side'] == 'B':
        if a in BUCKS and under:
            probs.append(f'{a} (buck) behind the NFC antenna')
        if any(rect_circle(rc, sx_, sy_) < 2.6 - 1e-6 for rc in own(a) for sx_, sy_ in J6_SUPPORTS):
            probs.append(f'{a} on a J6 support barb (back)')
        if A['h'] > 5.0 and any(overlap(rc, USB_CORRIDOR) for rc in own(a)):
            probs.append(f'{a} ({A["h"]:g} mm) in the DevKit USB plug strip')
# 6. edges
edge = []
for a in refs:
    if a in EDGE_FREE:
        continue
    for p in FPS[a]['pads']:
        if p['kind'] == 'np_thru_hole':
            continue
        d = min(p['rc'][0], p['rc'][1], W - p['rc'][2], H - p['rc'][3])
        if d < 0.5:
            edge.append(f'{a}.{p["num"]} {d:.2f}')
    if a not in HOLES and any(rc[0] < -0.01 or rc[1] < -0.01 or rc[2] > W + 0.01 or rc[3] > H + 0.01 for rc in own(a)):
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
