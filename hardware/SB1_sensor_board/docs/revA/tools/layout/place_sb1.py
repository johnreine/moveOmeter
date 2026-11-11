"""SB1 fill placement (2026-10-25), adapted from TB1's place4.py: fixed big parts from plan_sb1.py, then every other
part by connectivity inside per-block regions, with decoupling caps anchored to their pins and the buck as one group.
Rules: front 0.27 in mount discs (no front parts, no through-hole pins), back screw heads r 3.3, radar fields of view,
no through-hole pins behind the radars. Output: placement.json {ref: [x, y, rot, side]} in front-view board mm.
"""
import json, csv, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall
import schdata

OUT = sys.argv[1]
BIG = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
FPDIR = schdata.FPDIR
TB1DIR = os.environ.get('SB1_FPLIB', f'{schdata.P}/lib/SB1.pretty')
# H here is the bottom of the fill area, not the board edge (56.5 mm): keeping the filled parts 2 mm above the edge
# leaves the strip by the USB-C mouths clear.
W, H = 70.0, float(os.environ.get('SB1_FILL_H', '54.5'))
HOLES = {'H1': (3.5, 3.5), 'H2': (66.5, 3.5), 'H3': (3.5, 51.5), 'H4': (66.5, 51.5)}
MOUNT_R, BACK_R = 0.27 * 25.4, 3.3      # 0.27 in front clearance (0.25 in until 10/18 19:18)
MOD_TOP = 51.5 + 3.3 + 0.4
# part -> (chip, pin) it must sit next to, in placement priority order (same side, straight after that chip).
# Refs come from SB1's design.py; anchors.json (written by plan_sb1.py from the netlist) can extend this.
ANCHOR = json.load(open(os.environ.get('SB1_ANCHORS', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'anchors.json'))))
ANCHOR = {k: tuple(v) for k, v in ANCHOR['anchor'].items()} if 'anchor' in ANCHOR else ANCHOR
EXTRA = {}
CLUSTER = json.load(open(os.environ.get('SB1_ANCHORS', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'anchors.json'))))['cluster']
IN_CLUSTER = {m: ic for ic, ms in CLUSTER.items() for m in ms}

syms, _, _, _, SHEETS = schdata.load()
rows = [r for r in csv.DictReader(open(f'{schdata.P}/netlist_report.csv')) if not r['Ref'].startswith('#')]


def load_fp(fpid):
    lib, name = fpid.split(':', 1)
    path = f'{TB1DIR}/{name}.kicad_mod' if lib == 'SB1' else f'{FPDIR}/{lib}.pretty/{name}.kicad_mod'
    m = sx.parse(open(path).read())
    xs, ys, pads, prims = [], [], [], []
    for g in m:
        if not isinstance(g, list):
            continue
        if g[0] in ('fp_rect', 'fp_circle') and str(find(g, 'layer')[1]) == 'F.CrtYd':
            if g[0] == 'fp_circle':
                c, e = find(g, 'center'), find(g, 'end')
                r = math.hypot(float(e[1]) - float(c[1]), float(e[2]) - float(c[2]))
                prims.append((float(c[1]) - r, float(c[2]) - r, float(c[1]) + r, float(c[2]) + r))
            else:
                s0, e0 = find(g, 'start'), find(g, 'end')
                prims.append((min(float(s0[1]), float(e0[1])), min(float(s0[2]), float(e0[2])),
                              max(float(s0[1]), float(e0[1])), max(float(s0[2]), float(e0[2]))))
        if g[0] in ('fp_line', 'fp_rect', 'fp_circle', 'fp_arc', 'fp_poly') and str(find(g, 'layer')[1]) == 'F.CrtYd':
            if g[0] == 'fp_circle':
                c, e = find(g, 'center'), find(g, 'end')
                r = math.hypot(float(e[1]) - float(c[1]), float(e[2]) - float(c[2]))
                xs += [float(c[1]) - r, float(c[1]) + r]; ys += [float(c[2]) - r, float(c[2]) + r]
            elif g[0] == 'fp_poly':
                for p in find(g, 'pts')[1:]:
                    xs.append(float(p[1])); ys.append(float(p[2]))
            else:
                for k in ('start', 'end', 'mid'):
                    q = find(g, k)
                    if q:
                        xs.append(float(q[1])); ys.append(float(q[2]))
        if g[0] == 'pad':
            at = find(g, 'at'); sz = find(g, 'size')
            w, h = float(sz[1]), float(sz[2])
            a = float(at[3]) if len(at) > 3 else 0
            if round(a) % 180 == 90:
                w, h = h, w
            kind = 'smd' if g[2] in ('smd', 'connect') else 'tht'
            pads.append((str(g[1]), float(at[1]), float(at[2]), w, h, kind))
    if not xs:
        xs = [p[1] - p[3] / 2 for p in pads] + [p[1] + p[3] / 2 for p in pads]
        ys = [p[2] - p[4] / 2 for p in pads] + [p[2] + p[4] / 2 for p in pads]
    return (min(xs), min(ys), max(xs), max(ys)), pads, prims


FP, PART = {}, {}
for ref, s in syms.items():
    fpid = s['props']['Footprint']
    if fpid not in FP:
        FP[fpid] = load_fp(fpid)
    cy, pads, prims = FP[fpid]
    PART[ref] = dict(fp=fpid, cy=cy, pads=pads, prims=prims, tht=any(p[5] == 'tht' for p in pads), sheet=s['sheetfile'],
                     val=s['props'].get('Value', ''))

# schematic position of every symbol (for the functional-block split)
SCHPOS = {}
for f in SHEETS:
    e = sx.parse(open(f'{schdata.P}/{f}').read())
    for s in findall(e, 'symbol'):
        props = {str(p[1]): str(p[2]) for p in findall(s, 'property')}
        ref = props.get('Reference', '#')
        if not ref.startswith('#'):
            at = find(s, 'at')
            SCHPOS[ref] = (f.replace('.kicad_sch', ''), float(at[1]), float(at[2]))

NETS, size, NETS_BY_NET = {}, {}, {}
for r in rows:
    NETS.setdefault(r['Ref'], {})[r['Pin']] = r['Net']
    size[r['Net']] = size.get(r['Net'], 0) + 1
    NETS_BY_NET.setdefault(r['Net'], []).append((r['Ref'], r['Pin']))
BIGNET = {n for n, c in size.items() if c > 12} | {'GND', '+5V', '+3V3_PER'}


def wt(n):
    return 0.0 if n in BIGNET or size.get(n, 0) < 2 else 1.0 / (size[n] - 1)


def xf(px, py, x, y, r, side):
    if side == 'B':
        py = -py
    a = math.radians(r)
    c, s_ = round(math.cos(a)), round(math.sin(a))
    return x + px * c + py * s_, y - px * s_ + py * c


def rect_of(box, x, y, r, side, pad=0.0):
    pts = [xf(px, py, x, y, r, side) for px, py in ((box[0], box[1]), (box[2], box[1]), (box[2], box[3]), (box[0], box[3]))]
    return (min(p[0] for p in pts) - pad, min(p[1] for p in pts) - pad, max(p[0] for p in pts) + pad, max(p[1] for p in pts) + pad)


def pad_rects(ref, x, y, r, side, grow=0.35):
    return [rect_of((px - w / 2, py - h / 2, px + w / 2, py + h / 2), x, y, r, side, grow)
            for num, px, py, w, h, kind in PART[ref]['pads'] if kind == 'tht']


def overlap(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def rect_circle(rc, cx, cy):
    nx, ny = min(max(cx, rc[0]), rc[2]), min(max(cy, rc[1]), rc[3])
    return math.hypot(nx - cx, ny - cy)


# ------------------------------------------------------------------ occupancy
CELL = 4.0
GRID = {('F', 'all'): {}, ('B', 'all'): {}, ('F', 'tht'): {}, ('B', 'tht'): {}}


def cells(rc):
    for i in range(int(math.floor(rc[0] / CELL)), int(math.floor(rc[2] / CELL)) + 1):
        for j in range(int(math.floor(rc[1] / CELL)), int(math.floor(rc[3] / CELL)) + 1):
            yield i, j


def add_ob(side, kind, rc, tag):
    for c in cells(rc):
        GRID[side, kind].setdefault(c, []).append((rc, tag))


def hits(side, kind, rc, ignore=()):
    for c in cells(rc):
        for o, tag in GRID[side, kind].get(c, ()):
            if tag not in ignore and overlap(rc, o):
                return tag
    return None


OTHER = {'F': 'B', 'B': 'F'}
MODULES = set()
MODBODY = {}
EDGE_FREE = {'J1', 'J2'}                       # USB-C mouths sit at the bottom edge
FIX = {k: tuple(v) for k, v in json.load(open(BIG)).items()}
FAR = (-100.0, -100.0, -99.0, -99.0)
J6_BODY, J6_SOLID, J6_SUPPORTS = FAR, [], []   # (TB1's NFC-module rules don't apply)
BUCKS = set()
RADARS = json.load(open(BIG + '.radars')) if os.path.exists(BIG + '.radars') else {'J4': 'LD6004', 'J5': 'LD2450'}
FACE = {r: (6.5 if t == 'LD6004' else 7.3) for r, t in RADARS.items()}
TAN = {r: ((1.73, 1.73) if t == 'LD6004' else (1.73, 0.70)) for r, t in RADARS.items()}
USB_CORRIDOR = FAR


def height(ref):
    fp = PART[ref]['fp']
    for k, h in (('IDC-Header', 9.0), ('USB_C_Receptacle', 3.3), ('CP_Radial_D6.3', 8.0), ('CP_Radial_D8', 12.0),
                 ('TestPoint_Keystone', 5.0), ('MountingHole', 0.0), ('PinHeader', 10.0), ('PinSocket', 10.0)):
        if k in fp:
            return h
    return 2.5


placed = {}


def can_place(ref, x, y, r, side, reg):
    p = PART[ref]
    rc = rect_of(p['cy'], x, y, r, side, 0.2)
    if ref not in EDGE_FREE:
        if rc[0] < reg[0] or rc[1] < reg[1] or rc[2] > reg[2] or rc[3] > reg[3]:
            return False
        if rc[0] < 0.3 or rc[1] < 0.3 or rc[2] > W - 0.3 or rc[3] > H - 0.3:
            return False
    if hits(side, 'all', rc, ignore=(ref,)):
        return False
    if p['tht'] and hits(side, 'tht', rc, ignore=(ref,)):
        return False
    prs = pad_rects(ref, x, y, r, side) if p['tht'] else []
    for prc in prs:
        if hits(OTHER[side], 'all', prc, ignore=(ref,)):
            return False
    # mount discs and screw heads
    for hx, hy in HOLES.values():
        if side == 'F' and rect_circle(rc, hx, hy) < MOUNT_R:
            return False
        if side == 'B' and rect_circle(rc, hx, hy) < BACK_R:
            return False
        if any(rect_circle(prc, hx, hy) < MOUNT_R for prc in prs):
            return False
    hgt = height(ref)
    if side == 'B':
        if hgt > 5.0 and overlap(rc, USB_CORRIDOR):
            return False
        if any(rect_circle(rc, sx_, sy_) < 2.6 for sx_, sy_ in J6_SUPPORTS):
            return False
        if ref in BUCKS and overlap(rc, J6_BODY):
            return False
    else:
        for m, face in FACE.items():
            if hgt > face:
                tx, ty = TAN[m]
                hx_, hy_ = tx * (hgt - face) + 0.5, ty * (hgt - face) + 0.5
                a = rect_of(PART[m]['cy'], *placed[m])
                if overlap(rc, (a[0] - hx_, a[1] - hy_, a[2] + hx_, a[3] + hy_)):
                    return False
        if overlap(rc, J6_BODY) and (hgt > 10.5 or ref in BUCKS or ref.startswith('TP')):
            return False
    return True


def place(ref, x, y, r, side):
    placed[ref] = (round(x, 3), round(y, 3), r, side)
    if ref.startswith('H') and ref in HOLES:
        return                                   # handled by the circle checks
    p = PART[ref]
    rc = rect_of(p['cy'], x, y, r, side, 0.2)
    if ref in MODULES:
        add_ob(side, 'tht', rect_of(MODBODY[ref], x, y, r, side, 0.2), ref)
        for pr in p['prims']:                    # socket rows and standoff holes are solid
            add_ob(side, 'all', rect_of(pr, x, y, r, side, 0.2), ref)
        for prc in pad_rects(ref, x, y, r, side):
            add_ob(side, 'all', prc, ref)
            add_ob(OTHER[side], 'all', prc, ref)
    elif ref == 'J6':
        for s_ in J6_SOLID:
            add_ob('F', 'all', s_, ref)
        for sx_, sy_ in J6_SUPPORTS:
            add_ob('F', 'all', (sx_ - 3.0, sy_ - 3.0, sx_ + 3.0, sy_ + 3.0), ref)
        for prc in pad_rects(ref, x, y, r, side):
            add_ob('B', 'all', prc, ref)
    else:
        add_ob(side, 'all', rc, ref)
        if p['tht']:
            for prc in pad_rects(ref, x, y, r, side):
                add_ob(OTHER[side], 'all', prc, ref)


def pad_abs(ref, pin):
    x, y, r, side = placed[ref]
    for num, px, py, w, h, kind in PART[ref]['pads']:
        if num == pin:
            return xf(px, py, x, y, r, side)
    return (x, y)


def cost(ref, x, y, r, side):
    c = 0.0
    if ref in ANCHOR and ANCHOR[ref][0] in placed:
        ic, pin = ANCHOR[ref]
        ax, ay = pad_abs(ic, pin)
        net = NETS[ic][pin]
        d = min(math.hypot(*(lambda q: (q[0] - ax, q[1] - ay))(xf(px, py, x, y, r, side)))
                for num, px, py, *_ in PART[ref]['pads'] if NETS[ref].get(num) == net)
        c += 20.0 * d
    for mp, tref, tpin in EXTRA.get(ref, ()):
        if tref in placed:
            ax, ay = pad_abs(tref, tpin)
            px, py = next((px, py) for num, px, py, *_ in PART[ref]['pads'] if num == mp)
            qx, qy = xf(px, py, x, y, r, side)
            c += 20.0 * math.hypot(qx - ax, qy - ay)
    for pin, net in NETS.get(ref, {}).items():
        w = wt(net)
        if not w:
            continue
        pp = next(((px, py) for num, px, py, *_ in PART[ref]['pads'] if num == pin), None)
        if pp is None:
            continue
        ax, ay = xf(pp[0], pp[1], x, y, r, side)
        for o, op in NETS_BY_NET[net]:
            if o != ref and o in placed:
                ox, oy = pad_abs(o, op)
                c += w * (abs(ax - ox) + abs(ay - oy))
    return c


# ------------------------------------------------------------------ blocks and regions
def blk(ref):
    sh, sx_, sy_ = SCHPOS[ref]
    if PART[ref]['tht'] and height(ref) > 5.0:
        return 'TALL'                          # tall through-hole parts (bulk cap) go on the back
    if sh == 'ld6004':
        return 'A'
    if sh == 'ld2450':
        return 'B'
    if sh == 'power_usb':
        if sy_ < 135:                          # USB-C / CH340C / 5 V selection, channel by sheet half
            return 'USB_A' if sx_ < 210 else 'USB_B'
        return 'LOGIC' if sy_ < 210 and sx_ < 210 else 'LINK'
    return 'MISC'


F_BAND = ('F', (0.3, 26.5, W - 0.3, H - 0.3))
F_BANDL = ('F', (0.3, 26.5, 38.0, H - 0.3))
F_BANDR = ('F', (32.0, 26.5, W - 0.3, H - 0.3))
F_ALL = ('F', (0.3, 0.3, W - 0.3, H - 0.3))
B_ALL = ('B', (0.3, 0.3, W - 0.3, H - 0.3))
B_LEFT = ('B', (0.3, 0.3, 38.0, H - 0.3))
B_RIGHT = ('B', (32.0, 0.3, W - 0.3, H - 0.3))
# front-view x: USB-C A (J1) is at the left, B (J2) at the right
REGIONS = {
    'A': [F_BANDL, F_BAND, B_LEFT, F_ALL, B_ALL],
    'B': [F_BANDR, F_BAND, B_RIGHT, F_ALL, B_ALL],
    'USB_A': [B_LEFT, B_ALL, F_ALL],
    'USB_B': [B_RIGHT, B_ALL, F_ALL],
    'LOGIC': [B_ALL, F_ALL],
    'LINK': [B_ALL, F_ALL],
    'TALL': [B_ALL],
    'MISC': [B_ALL, F_ALL],
}

# ------------------------------------------------------------------ place
for ref in sorted(FIX, key=lambda r: (0 if r in MODULES or r in FACE or r == 'J6' else 1, r)):
    place(ref, *FIX[ref])
todo = [r for r in PART if r not in placed]


def links(ref):
    return sum(wt(n) * sum(1 for o, _ in NETS_BY_NET[n] if o != ref and o in placed) for n in NETS.get(ref, {}).values() if wt(n))


def area(ref):
    c = PART[ref]['cy']
    return (c[2] - c[0]) * (c[3] - c[1])


def padxy(ref, pin, x, y, r, side):
    for num, px, py, *_ in PART[ref]['pads']:
        if num == pin:
            return xf(px, py, x, y, r, side)
    raise KeyError((ref, pin))


def net_pads(ref, net, x, y, r, side):
    return [xf(px, py, x, y, r, side) for num, px, py, *_ in PART[ref]['pads'] if NETS[ref].get(num) == net]


def template(ic, side):
    tpl = {ic: (0.0, 0.0, 0)}
    rects = [rect_of(PART[ic]['cy'], 0.0, 0.0, 0, side, 0.2)]
    cin = CLUSTER[ic][0]
    grid = [i * 0.25 for i in range(-48, 49)]
    for m in CLUSTER[ic]:
        tref, tpin = ANCHOR[m]
        tx_, ty_ = padxy(tref, tpin, *tpl[tref], side)
        net = NETS[tref][tpin]
        best = None
        for dx in grid:
            for dy in grid:
                if abs(dx - tx_) + abs(dy - ty_) > 9:
                    continue
                for r in (0, 90, 180, 270):
                    rc = rect_of(PART[m]['cy'], dx, dy, r, side, 0.2)
                    if any(overlap(rc, o) for o in rects):
                        continue
                    d = min(math.hypot(qx - tx_, qy - ty_) for qx, qy in net_pads(m, net, dx, dy, r, side))
                    d += 0.05 * math.hypot(dx, dy)
                    if m != cin and 'GND' in NETS[m].values():   # keep every ground return next to the input cap's
                        g0 = net_pads(cin, 'GND', *tpl[cin], side)[0]
                        d += 0.3 * min(math.hypot(qx - g0[0], qy - g0[1]) for qx, qy in net_pads(m, 'GND', dx, dy, r, side))
                    if best is None or d < best[0]:
                        best = (d, dx, dy, r, rc)
        tpl[m] = best[1:4]
        rects.append(best[4])
    return tpl


TPL = {ic: {s_: template(ic, s_) for s_ in ('F', 'B')} for ic in CLUSTER}


def cluster_at(ic, X, Y, th, side):
    a = math.radians(th); c, s_ = round(math.cos(a)), round(math.sin(a))
    return {m: (X + dx * c + dy * s_, Y - dx * s_ + dy * c, (r + th) % 360) for m, (dx, dy, r) in TPL[ic][side].items()}


log = []
STEP = 0.5
for phase in (0, 1):
    pending = [r for r in todo if (PART[r]['tht'] if phase == 0 else not PART[r]['tht']) and r not in IN_CLUSTER]
    queue = [c_ for c_, (ic, _) in ANCHOR.items() if ic in placed and c_ in pending]
    for c_ in queue:
        pending.remove(c_)
    while pending or queue:
        if queue:
            ref = queue.pop(0)
        else:
            pending.sort(key=lambda r: (-links(r), -area(r)))
            ref = pending.pop(0)
        regs = REGIONS[blk(ref)]
        tx = ty = tw = 0.0
        if ref in ANCHOR and ANCHOR[ref][0] in placed:
            ic, pin = ANCHOR[ref]
            tx, ty = pad_abs(ic, pin); tw = 1.0
            for mp, tref, tpin in EXTRA.get(ref, ()):
                ex, ey = pad_abs(tref, tpin)
                tx, ty = (tx + ex) / 2, (ty + ey) / 2
            s_ = placed[ic][3]
            bx = [4.0, 8.0] if PART[ref]['cy'][2] - PART[ref]['cy'][0] < 6 else [8.0, 12.0]
            regs = [(s_, (max(0.3, tx - b), max(0.3, ty - b), min(W - 0.3, tx + b), min(H - 0.3, ty + b))) for b in bx] + regs
            if ref.startswith('C') and ref not in IN_CLUSTER:   # no room beside the pin: straight behind it, through a via
                regs.insert(1, (OTHER[s_], (max(0.3, tx - 3.0), max(0.3, ty - 3.0), min(W - 0.3, tx + 3.0), min(H - 0.3, ty + 3.0))))
        for pin, net in ([] if ref in ANCHOR else NETS.get(ref, {}).items()):
            w = wt(net)
            for o, op in NETS_BY_NET.get(net, []):
                if w and o != ref and o in placed:
                    ox, oy = pad_abs(o, op)
                    tx += w * ox; ty += w * oy; tw += w
        best = None
        for k, (side, reg) in enumerate(regs):
            if tw:
                cx, cy = min(max(tx / tw, reg[0]), reg[2]), min(max(ty / tw, reg[1]), reg[3])
            else:
                cx, cy = (reg[0] + reg[2]) / 2, (reg[1] + reg[3]) / 2
            pts = [(reg[0] + i * STEP, reg[1] + j * STEP) for i in range(int((reg[2] - reg[0]) / STEP) + 1)
                   for j in range(int((reg[3] - reg[1]) / STEP) + 1)]
            pts.sort(key=lambda p: abs(p[0] - cx) + abs(p[1] - cy))
            cands = []
            for x, y in pts:
                for r in (0, 90, 180, 270):
                    if ref in CLUSTER:
                        grp = cluster_at(ref, x, y, r, side)
                        if all(can_place(m, *grp[m], side, reg) for m in grp):
                            cands.append((sum(cost(m, *grp[m], side) for m in grp if m != ref) + cost(ref, x, y, r, side)
                                          + 0.1 * (abs(x - cx) + abs(y - cy)), x, y, r))
                    elif can_place(ref, x, y, r, side, reg):
                        cands.append((cost(ref, x, y, r, side) + 0.1 * (abs(x - cx) + abs(y - cy)), x, y, r))
                if len(cands) >= 40:
                    break
            if cands:
                best = min(cands) + (side,)
                if k:
                    log.append(f'{ref} ({blk(ref)}) used region {k} ({side})')
                break
        if not best:
            log.append(f'{ref} ({blk(ref)}) NOT PLACED')
            continue
        place(ref, best[1], best[2], best[3], best[4])
        if ref in CLUSTER:
            for m, (mx, my, mr) in cluster_at(ref, best[1], best[2], best[3], best[4]).items():
                if m != ref:
                    place(m, mx, my, mr, best[4])
                    if m in pending:
                        pending.remove(m)
        for c_ in [c_ for c_, (ic, _) in ANCHOR.items() if ic == ref and c_ in pending]:
            pending.remove(c_)
            queue.append(c_)

json.dump(placed, open(f'{OUT}/placement.json', 'w'), indent=0)
nF = sum(1 for v in placed.values() if v[3] == 'F')
print(f'{len(placed)} placed of {len(PART)} (front {nF}, back {len(placed) - nF})')
print('\n'.join(log) or 'every part in its first-choice region')
