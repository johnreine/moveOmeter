"""Routing prep for Mainboard-USB (2026-11-13), the SB1 lessons applied before the first Freerouting run.
usage: fanout_mbusb.py moveOmeter_MBUSB.kicad_pcb   (rebuild.sh runs it after mkpcb_mbusb.py)

- Edge strips: a 0.4 mm no-track / no-via rule area inside each board edge on F.Cu and B.Cu. Freerouting ignores
  KiCad's 0.5 mm copper-to-edge rule; the strips put it into the DSN. Pads and pour are still allowed there.
- GND fan-out: every SMD pad on GND gets a 0.3 mm stub to its own 0.6 / 0.3 mm via, so the two GND pours stay joined
  however the routing cuts them up (SB1's first routed board had 20 GND pads stranded on pour islands). The ZIF GND
  pads (J2 / J3 pads 6, 9, 11, 14, 17, 20) put theirs on the housing side, leaving the pad side free for signal exits.
  J1's GND pins and the ZIF tabs already sit next to plated shell / pour, so they get none.
- +5V into the ZIFs: pads 18 and 19 joined at 0.4 mm, out 0.4 mm past the courtyard, then 1.0 mm (the Power class
  width) for 1.1 mm, so Freerouting picks +5V up at full width clear of the 1 mm-pitch pads.
All stubs and vias are locked so the autorouter routes round them. Every via is checked: >= 0.43 mm (copper to copper)
from other-net pads and vias, outside the screw keep-outs and edge strips."""
import sys, re, math, uuid
path = sys.argv[1]
t = open(path).read()

def parse(text):
    st = [[]]
    for k in re.findall(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+', text):
        if k == '(': st.append([])
        elif k == ')': x = st.pop(); st[-1].append(x)
        else: st[-1].append(k[1:-1] if k[0] == '"' else k)
    return st[0][0]
def find(n, tag): return [c for c in n if isinstance(c, list) and c and c[0] == tag]
def one(n, tag):
    f = find(n, tag); return f[0] if f else None

B = parse(t)
NS = uuid.UUID('6b1f3c2e-1d4a-4c8e-9a51-3f0e2b7d9c10')
def U(*k): return str(uuid.uuid5(NS, '/'.join(map(str, k))))

xs, ys = [], []
for g in find(B, 'gr_rect') + find(B, 'gr_line'):
    if one(g, 'layer')[1] == 'Edge.Cuts':
        for k in ('start', 'end'):
            e = one(g, k); xs.append(float(e[1])); ys.append(float(e[2]))
X0, Y0, X1, Y1 = min(xs), min(ys), max(xs), max(ys)
STRIP = 0.4

pads = []    # (ref, num, net, cx, cy, hw, hh, smd)  axis-aligned half sizes in board coords
fpc = {}
for fp in find(B, 'footprint'):
    ref = [p[2] for p in find(fp, 'property') if p[1] == 'Reference'][0]
    at = one(fp, 'at'); fx, fy = float(at[1]), float(at[2]); fr = float(at[3]) if len(at) > 3 else 0.0
    fpc[ref] = (fx, fy)
    r = math.radians(fr)
    for pd in find(fp, 'pad'):
        pa = one(pd, 'at'); lx, ly = float(pa[1]), float(pa[2]); pr = float(pa[3]) if len(pa) > 3 else fr
        sz = one(pd, 'size'); sx, sy = float(sz[1]), float(sz[2])
        cx = fx + lx * math.cos(r) + ly * math.sin(r); cy = fy - lx * math.sin(r) + ly * math.cos(r)
        a = math.radians(pr) % math.pi
        hw = abs(sx * math.cos(a)) / 2 + abs(sy * math.sin(a)) / 2
        hh = abs(sx * math.sin(a)) / 2 + abs(sy * math.cos(a)) / 2
        dr = one(pd, 'drill')
        if dr and pd[2] == 'np_thru_hole':
            hw = hh = float(dr[1]) / 2
        net = one(pd, 'net')
        pads.append((ref, pd[1], net[-1] if net else '', cx, cy, hw, hh, pd[2] == 'smd'))

holes = [(p[3], p[4]) for p in pads if p[0].startswith('H')]
vias = []; segs = []; items = []

def gap_rect(x, y, r, p):
    dx = max(abs(x - p[3]) - p[5], 0); dy = max(abs(y - p[4]) - p[6], 0)
    return math.hypot(dx, dy) - r

def via_ok(x, y, net, r=0.3):
    if x - X0 < STRIP + r + 0.2 or X1 - x < STRIP + r + 0.2 or y - Y0 < STRIP + r + 0.2 or Y1 - y < STRIP + r + 0.2:
        return False
    if any(math.hypot(x - hx, y - hy) < 3.45 + r for hx, hy in holes):
        return False
    for p in pads:
        if p[2] != net and gap_rect(x, y, r, p) < 0.43:
            return False
    for vx, vy, vr, vn in vias:
        if math.hypot(x - vx, y - vy) - r - vr < (0.43 if vn != net else 0.25):
            return False
    return True

def seg(x1, y1, x2, y2, w, net, key):
    segs.append((x1, y1, x2, y2, w, net))
    items.append(f'\t(segment\n\t\t(start {x1:.4f} {y1:.4f})\n\t\t(end {x2:.4f} {y2:.4f})\n\t\t(width {w})\n'
                 f'\t\t(locked yes)\n\t\t(layer "F.Cu")\n\t\t(net "{net}")\n\t\t(uuid "{U("seg", key)}")\n\t)')

def via(x, y, net, key):
    vias.append((x, y, 0.3, net))
    items.append(f'\t(via\n\t\t(at {x:.4f} {y:.4f})\n\t\t(size 0.6)\n\t\t(drill 0.3)\n\t\t(layers "F.Cu" "B.Cu")\n'
                 f'\t\t(locked yes)\n\t\t(net "{net}")\n\t\t(uuid "{U("via", key)}")\n\t)')

report = []
# ZIF GND pads: via on the housing side (-x; both ZIFs stand on end, pads toward +x)
for ref in ('J2', 'J3'):
    for p in pads:
        if p[0] == ref and p[2] == 'GND' and p[1] != 'MP':
            vx = p[3] - p[5] - 0.87; vy = p[4]
            if not via_ok(vx, vy, 'GND'):
                sys.exit(f'fanout_mbusb: no room for the {ref}.{p[1]} GND via at ({vx:.2f}, {vy:.2f})')
            seg(p[3], p[4], vx, vy, 0.3, 'GND', f'{ref}.{p[1]}'); via(vx, vy, 'GND', f'{ref}.{p[1]}')
            report.append(f'{ref}.{p[1]}')
# other SMD GND pads: via just past the pad's outer end, away from its part's centre (try the other directions next)
for p in pads:
    if p[2] != 'GND' or not p[7] or p[0] in ('J1', 'J2', 'J3'):
        continue
    fx, fy = fpc[p[0]]
    out = (p[3] - fx, p[4] - fy); n = math.hypot(*out) or 1.0; out = (out[0] / n, out[1] / n)
    dirs = [out] + [(1, 0), (-1, 0), (0, 1), (0, -1)]
    done = False
    for d in dirs:
        for extra in (0.55, 0.8, 1.1, 1.5):
            ext = abs(d[0]) * p[5] + abs(d[1]) * p[6]
            vx, vy = p[3] + d[0] * (ext + extra), p[4] + d[1] * (ext + extra)
            if via_ok(vx, vy, 'GND'):
                seg(p[3], p[4], vx, vy, 0.3, 'GND', f'{p[0]}.{p[1]}'); via(vx, vy, 'GND', f'{p[0]}.{p[1]}')
                report.append(f'{p[0]}.{p[1]}'); done = True; break
        if done: break
    if not done:
        print(f'fanout_mbusb: no GND via for {p[0]}.{p[1]} (left to the pour)')
FOUR = '"In1.Cu"' in t       # 4-layer board (to4layer_mbusb.py, 11/13): +5V is the In2 plane
P5 = '/Mainboard_USB/+5V'
if not FOUR:
    P5 = '/Mainboard_USB/+5V'
    for ref in ('J2', 'J3'):
        p18 = [p for p in pads if p[0] == ref and p[1] == '18'][0]; p19 = [p for p in pads if p[0] == ref and p[1] == '19'][0]
        assert p18[2] == P5 and p19[2] == P5, (ref, p18[2], p19[2])
        px = p18[3]; ym = (p18[4] + p19[4]) / 2
        seg(px, p18[4], px, p19[4], 0.4, P5, f'{ref}.5v.join')
        seg(px, ym, px + 1.4, ym, 0.4, P5, f'{ref}.5v.neck')
        seg(px + 1.4, ym, px + 2.5, ym, 1.0, P5, f'{ref}.5v.wide')
        for p in pads:   # the wide part must clear every other-net pad by 0.2 mm
            if p[2] != P5:
                dx = max(abs((px + 1.95) - p[3]) - p[5] - 1.05, 0); dy = max(abs(ym - p[4]) - p[6] - 0.5, 0)
                assert math.hypot(dx, dy) >= 0.2, (ref, p)

# 11/13 (routed1 left 12 connections open, all of them J2 / J3 signals and +5V): every ZIF signal pad gets a 0.2 mm
# stub to its own via just past the pad's outer end, as SB1's J7 got (fanout_j7.py), so each signal can drop to B.Cu
# at once instead of being boxed in on F.Cu beside the connector. Neighbouring vias are 1.0 mm apart (0.4 mm copper
# gap, 0.7 mm hole gap: inside the 0.175 / 0.25 mm rules). Vias Freerouting doesn't use come out after routing
# (postroute_dangling_vias.py).
SIGX = 1.3
for ref in ('J2', 'J3'):
    for p in pads:
        if p[0] == ref and p[1] != 'MP' and p[2] not in ('GND', P5):
            vx, vy = p[3] + SIGX, p[4]
            for q in pads:
                if q[2] != p[2] and gap_rect(vx, vy, 0.3, q) < 0.3:
                    sys.exit(f'fanout_mbusb: {ref}.{p[1]} fan-out via too close to {q[0]}.{q[1]}')
            seg(p[3], p[4], vx, vy, 0.2, p[2], f'{ref}.{p[1]}.sig'); via(vx, vy, p[2], f'{ref}.{p[1]}.sig')

if not FOUR:
    # 11/13 (routed2 / routed3 still left 12-14 open, all long runs from the ZIFs down to the sockets): the +5V trunk is
    # pre-routed, 1.0 mm on F.Cu, so Freerouting can't lay it across the board where it walls off the signals heading
    # down. From J2's +5V stub straight down to y 67 (just below both ZIF housings), across to below J3's stub and up into
    # it, and left from J2 to x 27 (clear of the H7 keep-out), down and into C3 (the 100 nF beside the bulk caps). Every
    # ZIF signal already drops to B.Cu at its fan-out via, so it passes under the trunk.
    OX, OY = X0, Y0
    def bxy(x, y): return OX + x, OY + y
    TY, TX = 67.0, 27.0
    j2x = [p for p in pads if p[0] == 'J2' and p[1] == '18'][0][3] + 2.5
    j3x = [p for p in pads if p[0] == 'J3' and p[1] == '18'][0][3] + 2.5
    sy = [p for p in pads if p[0] == 'J2' and p[1] == '18'][0][4] + 0.5
    c3 = [p for p in pads if p[0] == 'C3' and p[2] == P5][0]
    ty, tx = OY + TY, OX + TX
    for k, (a, b) in enumerate((((j2x, sy), (j2x, ty)), ((j2x, ty), (j3x, ty)), ((j3x, ty), (j3x, sy)),
                                ((j2x, ty), (tx, ty)), ((tx, ty), (tx, c3[4])), ((tx, c3[4]), (c3[3], c3[4])))):
        seg(a[0], a[1], b[0], b[1], 1.0, P5, f'5v.trunk{k}')
else:
    # 4 layers: every SMD +5V pad gets a 0.4 mm stub to its own 0.6 / 0.3 mm via into the In2 +5V plane (the
    # through-hole C1 joins it by its own pin). The ZIF +5V pads (18, 19) put theirs in the signal fan-out column.
    for ref in ('J2', 'J3'):
        for p in pads:
            if p[0] == ref and p[2] == P5:
                vx, vy = p[3] + SIGX, p[4]
                for q in pads:
                    if q[2] != P5 and gap_rect(vx, vy, 0.3, q) < 0.3:
                        sys.exit(f'fanout_mbusb: {ref}.{p[1]} +5V via too close to {q[0]}.{q[1]}')
                seg(p[3], p[4], vx, vy, 0.4, P5, f'{ref}.{p[1]}.5v'); via(vx, vy, P5, f'{ref}.{p[1]}.5v')
    for p in pads:
        if p[2] != P5 or not p[7] or p[0] in ('J2', 'J3'):
            continue
        fx, fy = fpc[p[0]]
        out = (p[3] - fx, p[4] - fy); n = math.hypot(*out) or 1.0; out = (out[0] / n, out[1] / n)
        done = False
        for d in [out, (1, 0), (-1, 0), (0, 1), (0, -1)]:
            for extra in (0.55, 0.8, 1.1, 1.5):
                ext = abs(d[0]) * p[5] + abs(d[1]) * p[6]
                vx, vy = p[3] + d[0] * (ext + extra), p[4] + d[1] * (ext + extra)
                if via_ok(vx, vy, P5):
                    seg(p[3], p[4], vx, vy, 0.4, P5, f'{p[0]}.{p[1]}.5v'); via(vx, vy, P5, f'{p[0]}.{p[1]}.5v')
                    report.append(f'{p[0]}.{p[1]}(+5V)'); done = True; break
            if done: break
        if not done:
            sys.exit(f'fanout_mbusb: no room for a +5V via at {p[0]}.{p[1]}')

def strip(name, x1, y1, x2, y2):
    items.append(f'\t(zone\n\t\t(layers "F.Cu" "B.Cu")\n\t\t(uuid "{U("strip", name)}")\n\t\t(name "edge strip {name}")\n'
                 f'\t\t(hatch edge 0.5)\n\t\t(connect_pads (clearance 0))\n\t\t(min_thickness 0.25)\n'
                 f'\t\t(keepout\n\t\t\t(tracks not_allowed)\n\t\t\t(vias not_allowed)\n\t\t\t(pads allowed)\n'
                 f'\t\t\t(copperpour allowed)\n\t\t\t(footprints allowed)\n\t\t)\n'
                 f'\t\t(placement (enabled no) (sheetname ""))\n\t\t(fill (thermal_gap 0.5) (thermal_bridge_width 0.5))\n'
                 f'\t\t(polygon\n\t\t\t(pts (xy {x1} {y1}) (xy {x2} {y1}) (xy {x2} {y2}) (xy {x1} {y2}))\n\t\t)\n\t)')
strip('top', X0, Y0, X1, Y0 + STRIP); strip('bottom', X0, Y1 - STRIP, X1, Y1)
strip('left', X0, Y0, X0 + STRIP, Y1); strip('right', X1 - STRIP, Y0, X1, Y1)

def drop_blocks(text, uuids):
    out, i = [], 0
    for m in re.finditer(r'\n\t\((segment|via|zone)\n', text):
        if m.start() < i: continue
        depth, j = 0, m.start() + 2
        while True:
            c = text[j]
            if c == '(': depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0: break
            j += 1
        blk = text[m.start():j + 1]
        u = re.search(r'\(uuid "([^"]+)"\)', blk)
        if u and u.group(1) in uuids:
            out.append(text[i:m.start()]); i = j + 1
    out.append(text[i:]); return ''.join(out)
new_ids = set(re.findall(r'\(uuid "([^"]+)"\)', '\n'.join(items)))
new_ids |= {U('via', r, '5v') for r in ('J2', 'J3')}   # the +5V drop vias of 11/13 prep2, replaced by the trunk
if FOUR:   # the 2-layer +5V tracks (ZIF necks, trunk) aren't made on 4 layers: drop any earlier copies
    new_ids |= {U('seg', f'{r}.5v.{k}') for r in ('J2', 'J3') for k in ('join', 'neck', 'wide')}
    new_ids |= {U('seg', f'5v.trunk{k}') for k in range(6)}
t = drop_blocks(t, new_ids)
end = t.rfind('\t(embedded_fonts')
t = t[:end] + '\n'.join(items) + '\n' + t[end:]
open(path, 'w').write(t)
print(f'fanout_mbusb: {sum(1 for v in vias if v[3] == "GND")} GND vias, {sum(1 for v in vias if v[3] != "GND")} signal / +5V vias ({", ".join(report)}), {"+5V vias into In2" if FOUR else "+5V necks and trunk"}, 4 edge strips')
