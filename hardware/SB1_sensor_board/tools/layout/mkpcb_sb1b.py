"""Write moveOmeter_SB1.kicad_pcb (KiCad 10 format) for SB1 rev B (2026-10-31), from rev A's mkpcb_sb1.py.
Rev B: 42 x 86 mm, GND on In1 and In2 (5 V routed as tracks), and a keep-out behind the LD2450 on B.Cu / In1 / In2
(no tracks, vias or footprints; the module's own socket pins allowed) so the ground stays solid behind it.

Footprints from the KiCad 10 library and lib/SB1.pretty, placed from placement.json {ref: [x, y, rot, side]} in
front-view board mm. Back-side footprints are flipped the way KiCad stores them (local y mirrored, F/B layers swapped,
pad angles negated, text mirrored). Nets on every connected pad, symbol links, outline, 4-layer planes and pours.
"""
import json, csv, math, uuid, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import Q, find, findall
import schdata

P = schdata.P
FPDIR = schdata.FPDIR
TB1DIR = os.environ.get('SB1_FPLIB', f'{P}/lib/SB1.pretty')
V1 = schdata.V1
OUTF = sys.argv[1]
PLACEMENT = sys.argv[2]
NS = uuid.UUID('8a1d3f6b-2c4e-4b7a-9e0f-5d6c7b8a9e01')
W = 42.0
LAY = json.load(open(os.path.join(os.path.dirname(os.path.abspath(sys.argv[2])), 'layout.json')))  # from place_sb1b.py
H = float(LAY['H'])
OX, OY = 50.0, 40.0


def U(*k):
    return Q(str(uuid.uuid5(NS, '|'.join(map(str, k)))))


def num(v):
    v = round(float(v), 6)       # 6 places, as KiCad stores them: at 4, back-side copies of library footprints with
                                 # 5-place coordinates (D1's Fab outline) no longer matched the library (11/6)
    return float(v) if v != int(v) else int(v)


syms, GL, LL, PW, SHEETS = schdata.load()
place = json.load(open(PLACEMENT))
rows = [r for r in csv.DictReader(open(f'{P}/netlist_report.csv')) if not r['Ref'].startswith('#')]


def kname(net, sheet):
    return net if (net in PW or net in GL) else f'/{sheet}/{net}'


PADNET = {(r['Ref'], r['Pin']): kname(r['Net'], r['Sheet']) for r in rows}


def rotate(x, y, r):
    a = math.radians(r)
    c, s_ = round(math.cos(a), 12), round(math.sin(a), 12)
    return x * c + y * s_, -x * s_ + y * c


def norm_text_angle(a):
    a %= 360
    return 0 if a == 180 else 90 if a == 270 else a


def set_at(node, x, y, a):
    at = find(node, 'at')
    at[1:] = [num(x), num(y)] + ([num(a)] if a else [])


def ensure_uuid(node, *key):
    u = find(node, 'uuid')
    if u is None:
        node.append(['uuid', U(*key)])
    else:
        u[1] = U(*key)


SWAP = {}
for a, b in (('F.Cu', 'B.Cu'), ('F.SilkS', 'B.SilkS'), ('F.Fab', 'B.Fab'), ('F.CrtYd', 'B.CrtYd'),
             ('F.Mask', 'B.Mask'), ('F.Paste', 'B.Paste'), ('F.Adhes', 'B.Adhes')):
    SWAP[a], SWAP[b] = b, a


def flip_tree(node):
    """Mirror local y and swap F/B layers in a footprint child (in place)."""
    if not isinstance(node, list) or not node:
        return
    tag = node[0]
    if tag in ('start', 'end', 'mid', 'center', 'xy') and len(node) >= 3:
        node[2] = num(-float(node[2]))
        return
    if tag in ('layer', 'layers'):
        for i in range(1, len(node)):
            if isinstance(node[i], str) and str(node[i]) in SWAP:
                node[i] = Q(SWAP[str(node[i])])
        return
    for ch in node[1:]:
        if isinstance(ch, list):
            flip_tree(ch)


def mirror_effects(node):
    eff = find(node, 'effects')
    if eff is None:
        return
    j = find(eff, 'justify')
    if j is None:
        eff.append(['justify', 'mirror'])
        return
    vals = [v for v in j[1:] if v != 'mirror']
    vals = ['right' if v == 'left' else 'left' if v == 'right' else v for v in vals]
    j[1:] = vals + ['mirror']


def hidden_prop(name, value, rot, key, back):
    p = ['property', Q(name), Q(value), ['at', 0, 0] + ([num(rot)] if rot else []), ['layer', Q('B.Fab' if back else 'F.Fab')],
         ['hide', 'yes'], ['uuid', U(*key)], ['effects', ['font', ['size', 1, 1], ['thickness', 0.15]]]]
    if back:
        mirror_effects(p)
    return p


def load_mod(fpid):
    lib, name = fpid.split(':', 1)
    path = f'{TB1DIR}/{name}.kicad_mod' if lib == 'SB1' else f'{FPDIR}/{lib}.pretty/{name}.kicad_mod'
    return sx.parse(open(path).read())


MISSING_NET = []
# KiCad's own 3D file for these footprints isn't in this KiCad install: use the project's model (tools/layout/mk3d.py)
MODEL_OVERRIDE = {'Connector_FFC-FPC:Molex_200528-0200_1x20-1MP_P1.00mm_Horizontal':
                  '${KIPRJMOD}/3dmodels/Molex_200528-0200_approx.wrl'}
UUID_TAGS = {'fp_line', 'fp_rect', 'fp_circle', 'fp_arc', 'fp_poly', 'fp_curve', 'fp_text', 'fp_text_box', 'pad', 'dimension'}


def text_angle(local, r, back):
    return (r + 180 - local) % 360 if back else norm_text_angle(local + r)


def make_fp(ref):
    s = syms[ref]
    fpid = s['props']['Footprint']
    mod = load_mod(fpid)
    x, y, r, side = place[ref]
    back = side == 'B'
    X, Y = OX + x, OY + y
    body = mod[2:]
    skip = {'version', 'generator', 'generator_version', 'layer', 'descr', 'tags', 'property', 'attr', 'uuid', 'at',
            'path', 'sheetname', 'sheetfile', 'embedded_fonts', 'model'}
    out = ['footprint', Q(fpid), ['layer', Q('B.Cu' if back else 'F.Cu')], ['uuid', U('fp', ref)],
           ['at', num(X), num(Y)] + ([num(r)] if r else [])]
    for t in ('descr', 'tags'):
        n_ = find(body, t)
        if n_:
            out.append(n_)
    sp = s['props']
    have = set()
    for p in findall(body, 'property'):
        nm = str(p[1])
        have.add(nm)
        if nm == 'Reference':
            p[2] = Q(ref)
        elif nm == 'Value':
            p[2] = Q(sp.get('Value', ''))
        elif nm in sp:
            p[2] = Q(sp[nm])
        at = find(p, 'at')
        la = float(at[3]) if len(at) > 3 else 0
        if back:
            flip_tree(p)
            set_at(p, at[1], -float(at[2]), text_angle(la, r, True))
            mirror_effects(p)
        else:
            set_at(p, at[1], at[2], text_angle(la, r, False))
        ensure_uuid(p, 'prop', ref, nm)
        out.append(p)
    for nm, v in sp.items():
        if nm in ('Reference', 'Value', 'Footprint') or nm in have:
            continue
        out.append(hidden_prop(nm, v, (r + 180) % 360 if back else r, ('prop', ref, nm), back))
    out.append(['path', Q(f"/{s['sheet_uuid']}/{s['uuid']}")])
    out.append(['sheetname', Q(f"/{s['sheetname']}/")])
    out.append(['sheetfile', Q(s['sheetfile'])])
    attr = find(body, 'attr') or ['attr']
    attr = [a for a in attr if a not in ('exclude_from_bom', 'dnp')]
    if not s['in_bom']:
        attr.append('exclude_from_bom')
    if s['dnp']:
        attr.append('dnp')
    if len(attr) > 1:
        out.append(attr)
    k = 0
    for item in body:
        if not isinstance(item, list) or item[0] in skip:
            continue
        k += 1
        tag = item[0]
        if tag == 'fp_text':
            at = find(item, 'at')
            la = float(at[3]) if len(at) > 3 else 0
            if back:
                flip_tree(item)
                set_at(item, at[1], -float(at[2]), text_angle(la, r, True))
                mirror_effects(item)
            else:
                set_at(item, at[1], at[2], text_angle(la, r, False))
        elif tag == 'zone':
            if back:
                flip_tree(item)
            for pts in findall(find(item, 'polygon'), 'pts'):
                for xy in pts[1:]:
                    dx, dy = rotate(float(xy[1]), float(xy[2]), r)
                    xy[1], xy[2] = num(X + dx), num(Y + dy)
            ensure_uuid(item, 'zone', ref, k)
        elif tag == 'pad':
            at = find(item, 'at')
            la = float(at[3]) if len(at) > 3 else 0
            px, py = float(at[1]), float(at[2])
            if back:
                flip_tree(item)          # layers + custom-pad primitives
                py, la = -py, -la
            set_at(item, px, py, (la + r) % 360)
            pn = str(item[1])
            for old in findall(item, 'net'):
                item.remove(old)
            if pn and (ref, pn) in PADNET:
                ui = next((i for i, c in enumerate(item) if isinstance(c, list) and c[0] == 'uuid'), len(item))
                item.insert(ui, ['net', Q(PADNET[(ref, pn)])])
            elif pn and 'np_thru_hole' not in item:
                MISSING_NET.append(f'{ref}.{pn}')
        elif back:
            flip_tree(item)
        if tag in UUID_TAGS:
            ensure_uuid(item, 'item', ref, k)
        out.append(item)
    out.append(['embedded_fonts', 'no'])
    for m in findall(body, 'model'):
        if fpid in MODEL_OVERRIDE:
            m[1] = Q(MODEL_OVERRIDE[fpid])
        out.append(m)
    return out


# ------------------------------------------------------------------ board-level objects
def bxy(x, y):
    return ['xy', num(OX + x), num(OY + y)]


def rect_pts(x0, y0, x1, y1):
    return ['pts', bxy(x0, y0), bxy(x1, y0), bxy(x1, y1), bxy(x0, y1)]


def circle_pts(cx, cy, r, n=36):
    import math as _m
    return ['pts'] + [bxy(cx + r * _m.cos(2 * _m.pi * k / n), cy + r * _m.sin(2 * _m.pi * k / n)) for k in range(n)]


def hole_keepouts(refs, r_front, r_back):
    """11/6 (John): no tracks or vias under the screw heads / inserts. Rule areas round each mounting hole, per side;
    GND pour is still allowed there (a screw resting on GND is harmless). Parts are kept off by the hole courtyards."""
    out = []
    for ref in refs:
        x, y = place[ref][0], place[ref][1]
        for layer, r in (('F.Cu', r_front), ('B.Cu', r_back)):
            out.append(rule_area(f'{ref} screw keep-out {layer[0]}', [layer], circle_pts(x, y, r),
                                 [('tracks', 'not_allowed'), ('vias', 'not_allowed'), ('pads', 'allowed'),
                                  ('copperpour', 'allowed'), ('footprints', 'allowed')]))
    return out


def zone(net, layer, name, pts, key):
    return ['zone', ['net', Q(net)], ['layer', Q(layer)], ['uuid', U('zone', key)], ['name', Q(name)], ['hatch', 'edge', 0.5],
            ['connect_pads', ['clearance', 0.3]], ['min_thickness', 0.2],
            ['fill', ['thermal_gap', 0.3], ['thermal_bridge_width', 0.4], ['island_removal_mode', 0]],
            ['polygon', pts]]


def rule_area(name, layers, pts, rules):
    return ['zone', ['layers'] + [Q(l) for l in layers], ['uuid', U('rule', name)], ['name', Q(name)], ['hatch', 'edge', 0.5],
            ['connect_pads', ['clearance', 0]], ['min_thickness', 0.25],
            ['keepout'] + [[k_, v] for k_, v in rules],
            ['placement', ['enabled', 'no'], ['sheetname', Q('')]],
            ['fill', ['thermal_gap', 0.5], ['thermal_bridge_width', 0.5]],
            ['polygon', pts]]


def gr_rect(x0, y0, x1, y1, layer, w, key):
    return ['gr_rect', ['start', num(OX + x0), num(OY + y0)], ['end', num(OX + x1), num(OY + y1)],
            ['stroke', ['width', w], ['type', 'solid']], ['fill', 'no'], ['layer', Q(layer)], ['uuid', U('gr', key)]]


def gr_text(txt, x, y, layer, size, key, just='left', angle=0, thick=None, mirror=False):
    eff = ['effects', ['font', ['size', size, size], ['thickness', thick or round(size * 0.15, 3)]]]
    j = ([just] if just else []) + (['mirror'] if mirror else [])
    if j:
        eff.append(['justify'] + j)
    return ['gr_text', Q(txt), ['at', num(OX + x), num(OY + y)] + ([angle] if angle else []), ['layer', Q(layer)],
            ['uuid', U('txt', key)], eff]


v1 = sx.parse(open(V1).read())
layers = find(v1, 'layers')
# 11/6: In1 / In2 are GND planes, not routing layers: layer type "power", so the Specctra export (Freerouting) treats
# them as planes and routes on F.Cu / B.Cu only. (11/9 tried "signal", wrongly blaming the power type for Freerouting
# placing no vias; the real cause was the board-wide inner rule area, see below. Back to "power" 11/10.)
for _l in layers[1:]:
    if isinstance(_l, list) and str(_l[1]) in ('In1.Cu', 'In2.Cu'):
        _l[2] = 'power'
setup = find(v1, 'setup')
stack = find(setup, 'stackup')
TH = {'F.Cu': 0.035, 'dielectric 1': 0.2104, 'In1.Cu': 0.0152, 'dielectric 2': 1.065, 'In2.Cu': 0.0152,
      'dielectric 3': 0.2104, 'B.Cu': 0.035}
ER = {'dielectric 1': 4.4, 'dielectric 2': 4.6, 'dielectric 3': 4.4}
for l in findall(stack, 'layer'):
    nm = str(l[1])
    if nm in TH:
        find(l, 'thickness')[1] = TH[nm]
    if nm in ER:
        find(l, 'epsilon_r')[1] = ER[nm]
        if nm != 'dielectric 2':
            find(l, 'material')[1] = Q('FR4 7628')
find(stack, 'copper_finish')[1] = Q('HAL lead-free')
find(find(setup, 'pcbplotparams'), 'outputdirectory')[1] = Q('fab/')

board = ['kicad_pcb', ['version', 20260206], ['generator', Q('pcbnew')], ['generator_version', Q('10.0')],
         ['general', ['thickness', 1.6], ['legacy_teardrops', 'no']], ['paper', Q('A4')],
         ['title_block', ['title', Q('moveOmeter sensor board SB1 rev B')], ['date', Q('2026-10-31')], ['rev', Q('B')],
          ['company', Q('Still Kicking / moveOmeter')],
          ['comment', 1, Q(f'{W:g} x {H:g} mm; four M2.5 holes, screws from the FRONT into inserts in the holder behind.')],
          ['comment', 2, Q('4-layer: F.Cu sig+GND / In1 GND / In2 GND / B.Cu sig+GND; 5 V as Power tracks. Fill zones (B) after routing.')]],
         layers, setup]


def refkey(r):
    return (''.join(c for c in r if c.isalpha()), int(''.join(c for c in r if c.isdigit()) or 0))


refs = sorted(syms, key=refkey)
assert set(refs) == set(place), (set(refs) ^ set(place))
for ref in refs:
    board.append(make_fp(ref))

board.append(gr_rect(0, 0, W, H, 'Edge.Cuts', 0.05, 'outline'))
notes = ['FRONT (this side) faces the room: mics J1 / J2 at the top, LD6004 (J4), LD2450 (J5) upright (patches up), VEML7700 (U4).',
         'Screws from the front into heat-set inserts in the holder: keep 3.0 mm (front) / 3.3 mm (back) clear round each hole.',
         'Front: nothing taller than the radar faces in their field of view. No through-hole pins behind the radars.',
         'Behind the LD2450 + 3 mm: solid GND on every layer (rule area on B.Cu / In1 / In2: no tracks, vias or parts).',
         'In1 / In2 are GND planes (layer type power): no tracks on them anywhere (custom DRC rule). Route on F.Cu / B.Cu only.',
         'Mounting holes: no tracks or vias within 3.0 mm (front, screw head) / 3.3 mm (back, insert) of each hole centre.',
         'BACK: one FFC ZIF, J7 (left edge), opening toward the centre (J3 removed 11/8). SB1-B: J7 at the outer end, cable lies flat toward the apex ~11 mm, then loops into the V. SB1-A: J7 near the apex, cable lies flat out along the back ~24 mm, then swings 135 deg into the Mainboard. Keep the back clear in the cable lanes.',
         'Two identical SB1s stand in a 90 deg V (point toward the room); the Mainboard stands upright behind them, parallel to the wall.']
for i, t in enumerate(notes):
    board.append(gr_text(t, W + 3, 5 + i * 3, 'Cmts.User', 0.9, f'note{i}'))
MARK = LAY['marks']
fx, fy = MARK.get('front', (35.0, 40.0))
bx, by = MARK.get('back', (35.0, 40.0))
board.append(gr_text('SB1 rev B  FRONT', fx, fy, 'F.SilkS', 0.8, 'mark1', just=None, thick=0.15))
board.append(gr_text('moveOmeter SB1 rev B  BACK', bx, by, 'B.SilkS', 0.8, 'mark3', just=None, thick=0.15, mirror=True))

full = rect_pts(0, 0, W, H)
board.append(zone('GND', 'In1.Cu', 'GND plane In1', full, 'gnd_in1'))
board.append(zone('GND', 'In2.Cu', 'GND plane In2', full, 'gnd_in2'))
# keep the ground solid behind the LD2450 (+3 mm), except at its header end (bottom), where its socket pins are
ZX0, ZY0, ZX1, ZY1 = LAY['zone']
board.append(rule_area('LD2450 solid ground', ['B.Cu', 'In1.Cu', 'In2.Cu'], rect_pts(ZX0, ZY0, ZX1, ZY1),
                       [('tracks', 'not_allowed'), ('vias', 'not_allowed'), ('pads', 'allowed'), ('copperpour', 'allowed'),
                        ('footprints', 'not_allowed')]))
# 11/6 (John): In1 / In2 stay unbroken GND planes everywhere: no tracks on them anywhere. Vias are allowed; GND vias
# join the planes, signal vias leave small holes. 11/10: this used to be a board-wide rule area. KiCad exports it to the
# DSN as a "wire_keepout", which Freerouting treats as a full keep-out, vias included: four runs (routed5-8) placed no
# vias at all. The ban now lives in the custom DRC rules (moveOmeter_SB1.kicad_dru, written by fixpro_sb1b.py), which
# aren't exported; the "power" layer type keeps Freerouting off In1 / In2.
# screw heads on the front (M2.5, ~5 mm), heat-set insert / holder boss on the back: the hole courtyards' radii
board.extend(hole_keepouts(('H1', 'H2', 'H3', 'H4'), 3.0, 3.3))
# 11/8: Freerouting doesn't see KiCad's 0.5 mm board-edge clearance (it only keeps its normal clearance from the outline),
# so it ran tracks 0.3-0.4 mm from the edge. A 0.4 mm no-track / no-via strip inside each edge puts the rule into the
# DSN: track edge >= 0.4 + its clearance (>= 0.14) from the outline. Pads and pour are still allowed.
EB = 0.4
for nm, r in (('top', (0, 0, W, EB)), ('bottom', (0, H - EB, W, H)), ('left', (0, 0, EB, H)), ('right', (W - EB, 0, W, H))):
    board.append(rule_area(f'Edge clearance {nm}', ['F.Cu', 'B.Cu'], rect_pts(*r),
                           [('tracks', 'not_allowed'), ('vias', 'not_allowed'), ('pads', 'allowed'), ('copperpour', 'allowed'),
                            ('footprints', 'allowed')]))
board.append(zone('GND', 'F.Cu', 'GND pour top', full, 'gnd_f'))
board.append(zone('GND', 'B.Cu', 'GND pour bottom', full, 'gnd_b'))
board.append(['embedded_fonts', 'no'])

txt = sx.dump(board) + '\n'
os.makedirs(os.path.dirname(os.path.abspath(OUTF)), exist_ok=True)
open(OUTF, 'w').write(txt)
nb = sum(1 for v in place.values() if v[3] == 'B')
print('wrote', OUTF, len(txt), 'chars;', len(refs), 'footprints (', nb, 'on the back )')
print('pads with a number but no net:', ' '.join(MISSING_NET) or 'none')
