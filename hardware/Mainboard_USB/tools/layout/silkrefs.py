"""Tidy the silkscreen reference designators on a written board (John, 11/6: not under the parts, so the board can be
debugged with everything fitted; smaller text is fine).

For every footprint, its Reference text (and any user silk text that collides, e.g. the mic breakouts' "MIC") is moved
to the nearest free spot beside its own part:
  hard limits: off every part body on that side (F/B.Fab outline, or the courtyard if there's no Fab outline), off
               every pad with copper on that side (+0.2 mm), off other silk lines and texts (+0.15 mm), off the other
               labels already placed, and 0.5 mm inside the board edge;
  preferences: horizontal, close to its own part, closer to its own part than to any other, not inside another
               part's courtyard.
Text is 0.8 mm (0.12 stroke), the board setup's minimum, within 3 mm of the part, else 4 or 5 mm away; only if there's
still no spot does it drop to 0.7, then 0.6 mm (which KiCad's DRC will flag). Labels are placed hardest
first (fewest free spots). Prints what it couldn't place cleanly. usage: silkrefs.py board.kicad_pcb
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall

PCB = sys.argv[1]
SIZES = [(0.8, 0.12), (0.7, 0.1), (0.6, 0.1)]
CW = 0.84                       # stroke-font character advance / height (KiCad newstroke caps, a little generous)
PAD_CL, SILK_CL, EDGE_CL, LAB_CL = 0.2, 0.15, 0.5, 0.25
STEP = 0.25

b = sx.parse(open(PCB).read())


def fl(v):
    return float(v)


def rot(x, y, r):
    a = math.radians(r); c, s = math.cos(a), math.sin(a)
    return x * c + y * s, -x * s + y * c


def unrot(dx, dy, r):
    a = math.radians(r); c, s = math.cos(a), math.sin(a)
    return dx * c - dy * s, dx * s + dy * c


def box_of(pts, m=0.0):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return (min(xs) - m, min(ys) - m, max(xs) + m, max(ys) + m)


def over(a, bx, gap=0.0):
    return a[0] < bx[2] + gap and bx[0] < a[2] + gap and a[1] < bx[3] + gap and bx[1] < a[3] + gap


def rdist(a, bx):
    dx = max(bx[0] - a[2], a[0] - bx[2], 0); dy = max(bx[1] - a[3], a[1] - bx[3], 0)
    return math.hypot(dx, dy)


def text_box(cx, cy, txt, size, thick, vertical):
    w = len(txt) * size * CW + thick; h = size + thick
    if vertical:
        w, h = h, w
    return (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)


def graphic_pts(g):
    t = g[0]
    if t in ('fp_line', 'gr_line', 'fp_rect', 'gr_rect'):
        return [(fl(find(g, 'start')[1]), fl(find(g, 'start')[2])), (fl(find(g, 'end')[1]), fl(find(g, 'end')[2]))]
    if t in ('fp_arc', 'gr_arc'):
        return [(fl(find(g, k)[1]), fl(find(g, k)[2])) for k in ('start', 'mid', 'end')]
    if t in ('fp_circle', 'gr_circle'):
        c = find(g, 'center'); e = find(g, 'end'); cx, cy = fl(c[1]), fl(c[2]); r = math.hypot(fl(e[1]) - cx, fl(e[2]) - cy)
        return [(cx - r, cy - r), (cx + r, cy + r)]
    if t in ('fp_poly', 'gr_poly'):
        pts = find(g, 'pts')
        return [(fl(p[1]), fl(p[2])) for p in pts[1:] if isinstance(p, list) and p[0] == 'xy']
    return None


def layer_of(g):
    l = find(g, 'layer')
    return str(l[1]) if l else ''


# ---------------------------------------------------------------- board outline
edge = None
for g in b:
    if isinstance(g, list) and g[0] == 'gr_rect' and layer_of(g) == 'Edge.Cuts':
        p = graphic_pts(g); edge = box_of(p)
assert edge, 'no Edge.Cuts rectangle'
INNER = (edge[0] + EDGE_CL, edge[1] + EDGE_CL, edge[2] - EDGE_CL, edge[3] - EDGE_CL)

# ---------------------------------------------------------------- collect geometry per side
SIDES = ('F', 'B')
bodies = {s: [] for s in SIDES}     # (ref, box)
courts = {s: [] for s in SIDES}     # (ref, box)
pads = {s: [] for s in SIDES}       # box
silk = {s: [] for s in SIDES}       # (ref or None, box)  fixed silk graphics and texts
labels = []                         # movable: dict(fp, item, ref, side, txt, X, Y, R, own_body)


def silk_side(l):
    return 'F' if l.startswith('F.Silk') else ('B' if l.startswith('B.Silk') else None)


for f in findall(b, 'footprint'):
    ref = [str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference'][0]
    at = find(f, 'at'); X, Y = fl(at[1]), fl(at[2]); R = fl(at[3]) if len(at) > 3 else 0.0
    fside = 'B' if layer_of(f) == 'B.Cu' else 'F'

    def to_board(pts):
        return [(X + rot(x, y, R)[0], Y + rot(x, y, R)[1]) for x, y in pts]
    fab, crt = [], []
    for g in f:
        if not isinstance(g, list):
            continue
        pts = graphic_pts(g)
        if pts is None:
            continue
        l = layer_of(g)
        if l.endswith('.Fab'):
            fab += to_board(pts)
        elif l.endswith('.CrtYd'):
            (crt if l[0] == fside else []).extend(to_board(pts))
            if l[0] != fside:                       # e.g. screw-head courtyard on the other side
                courts['F' if l[0] == 'F' else 'B'].append((ref, box_of(to_board(pts))))
        elif silk_side(l):
            bx = box_of(to_board(pts), 0.06)
            silk[silk_side(l)].append((ref, bx))
    own_body = box_of(fab) if fab else (box_of(crt) if crt else None)
    if own_body:
        bodies[fside].append((ref, own_body))
    if crt:
        courts[fside].append((ref, box_of(crt)))
    for p in findall(f, 'pad'):
        kind = str(p[2]); pa = find(p, 'at'); sz = find(p, 'size')
        dx, dy = rot(fl(pa[1]), fl(pa[2]), R); w, h = fl(sz[1]), fl(sz[2])
        pr = fl(pa[3]) if len(pa) > 3 else R
        rr = math.radians(pr - 0); hw = abs(w / 2 * math.cos(rr)) + abs(h / 2 * math.sin(rr))
        hh = abs(w / 2 * math.sin(rr)) + abs(h / 2 * math.cos(rr))
        bx = (X + dx - hw, Y + dy - hh, X + dx + hw, Y + dy + hh)
        layers = ' '.join(str(v) for v in (find(p, 'layers') or [])[1:])
        for s in SIDES:
            if kind in ('thru_hole', 'np_thru_hole') or f'{s}.Cu' in layers or '*.Cu' in layers:
                pads[s].append(bx)
    # texts on silk: Reference is movable; user texts are fixed unless they collide (checked below)
    for t in findall(f, 'property') + findall(f, 'fp_text'):
        l = layer_of(t); s = silk_side(l)
        if not s:
            continue
        eff = find(t, 'effects')
        if eff and any(e == 'hide' or (isinstance(e, list) and e[0] == 'hide' and str(e[1]) == 'yes') for e in eff):
            continue
        if t[0] == 'property' and str(t[1]) != 'Reference':
            continue
        if find(t, 'hide') and str(find(t, 'hide')[1]) == 'yes':
            continue
        txt = str(t[2])
        ta = find(t, 'at'); tx, ty = rot(fl(ta[1]), fl(ta[2]), R); ang = fl(ta[3]) if len(ta) > 3 else 0.0
        font = find(eff, 'font'); sz = find(font, 'size'); th = find(font, 'thickness')
        size, thick = fl(sz[1]), (fl(th[1]) if th else 0.15)
        vertical = round(ang) % 180 == 90
        cur = text_box(X + tx, Y + ty, txt, size, thick, vertical)
        item = dict(fp=f, item=t, ref=ref, side=s, txt=txt, X=X, Y=Y, R=R, body=own_body, cur=cur,
                    is_ref=(t[0] == 'property'))
        labels.append(item)

# board-level silk (names, notes on silk)
for g in b:
    if isinstance(g, list) and g[0] in ('gr_text',):
        s = silk_side(layer_of(g))
        if s:
            ta = find(g, 'at'); eff = find(g, 'effects'); font = find(eff, 'font'); sz = find(font, 'size')
            txt = str(g[1]); size = fl(sz[1]); ang = fl(ta[3]) if len(ta) > 3 else 0
            jl = any(isinstance(e, list) and e[0] == 'justify' and 'left' in [str(v) for v in e] for e in eff)
            w = len(txt) * size * CW; cx = fl(ta[1]) + (w / 2 if jl else 0)
            silk[s].append((None, text_box(cx, fl(ta[2]), txt, size, 0.15, round(ang) % 180 == 90)))
    elif isinstance(g, list) and g[0] in ('gr_line', 'gr_rect', 'gr_circle', 'gr_arc', 'gr_poly'):
        s = silk_side(layer_of(g))
        if s:
            silk[s].append((None, box_of(graphic_pts(g), 0.06)))


def justified(t):
    eff = find(t, 'effects'); j = find(eff, 'justify') if eff else None
    return bool(j) and any(str(v) in ('left', 'right', 'top', 'bottom') for v in j[1:])


def user_text_ok(L):
    """A fixed user text stays where it is if it's clean. Left / right justified ones (the module pin labels) are
    always kept: they run away from their pins, and KiCad's DRC passes them."""
    if justified(L['item']):
        return True
    s, bx = L['side'], L['cur']
    if not (INNER[0] <= bx[0] and INNER[1] <= bx[1] and bx[2] <= INNER[2] and bx[3] <= INNER[3]):
        return False
    if any(over(bx, p) for p in pads[s]):              # same test KiCad's DRC makes (it passed J4 / J5 pin labels)
        return False
    return True


movable = [L for L in labels if L['is_ref'] or not user_text_ok(L)]
fixed_texts = [L for L in labels if L not in movable]
for L in fixed_texts:
    silk[L['side']].append((L['ref'], L['cur']))


def candidates(L, size, thick, placed, near=3.0):
    s = L['side']; body = L['body'] or (L['X'] - 0.5, L['Y'] - 0.5, L['X'] + 0.5, L['Y'] + 0.5)
    out = []
    reach = near + len(L['txt']) * size * CW / 2 + 1.0    # search the band around the part's outline, not its centre
    nx = int((body[2] - body[0] + 2 * reach) / STEP) + 1
    ny = int((body[3] - body[1] + 2 * reach) / STEP) + 1
    for i in range(nx):
        for j in range(ny):
            cx, cy = body[0] - reach + i * STEP, body[1] - reach + j * STEP
            for vertical in (False, True):
                bx = text_box(cx, cy, L['txt'], size, thick, vertical)
                if not (INNER[0] <= bx[0] and INNER[1] <= bx[1] and bx[2] <= INNER[2] and bx[3] <= INNER[3]):
                    continue
                if any(over(bx, bb) for _, bb in bodies[s]):
                    continue
                if any(over(bx, p, PAD_CL) for p in pads[s]):
                    continue
                if any(over(bx, sb, SILK_CL) for _, sb in silk[s]):
                    continue
                if any(over(bx, pb, LAB_CL) for pb in placed[s]):
                    continue
                d_own = rdist(bx, body)
                if d_own > near:
                    continue
                d_other = min([rdist(bx, bb) for r_, bb in bodies[s] if r_ != L['ref']] or [99])
                score = d_own + (1.5 if vertical else 0) + (3.0 if d_other < d_own + 0.3 else 0)
                score += 1.0 * sum(1 for r_, cb in courts[s] if r_ != L['ref'] and over(bx, cb))
                out.append((score, cx, cy, vertical, bx))
    out.sort(key=lambda t: t[0])
    return out


placed = {s: [] for s in SIDES}
todo = sorted(movable, key=lambda L: len(candidates(L, *SIZES[0], placed)))
problems, result = [], {}
for L in todo:
    got = None
    # the board setup's minimum silk text is 0.8 mm / 0.12 mm, so look further out at full size before shrinking
    for size, thick, near in [SIZES[0] + (d,) for d in (3.0, 4.0, 5.0)] + [sz + (5.0,) for sz in SIZES[1:]]:
        c = candidates(L, size, thick, placed, near)
        if c:
            got = (size, thick) + c[0][1:]
            break
    if not got:
        problems.append(L['ref'] + ' ' + L['txt'])
        continue
    size, thick, cx, cy, vertical, bx = got
    placed[L['side']].append(bx)
    result[id(L['item'])] = got
    t = L['item']
    lx, ly = unrot(cx - L['X'], cy - L['Y'], L['R'])
    back = L['side'] == 'B'
    ang = (180 if back else 0) + (90 if vertical else 0)
    ta = find(t, 'at')
    ta[1:] = [round(lx, 4), round(ly, 4), ang % 360]
    eff = find(t, 'effects'); font = find(eff, 'font')
    font[:] = ['font', ['size', size, size], ['thickness', thick]]
    for e in list(eff):                                  # centred, mirrored on the back
        if isinstance(e, list) and e[0] == 'justify':
            eff.remove(e)
    if back:
        eff.append(['justify', 'mirror'])

open(PCB, 'w').write(sx.dump(b) + '\n')
sizes = {}
for g in result.values():
    sizes[g[0]] = sizes.get(g[0], 0) + 1
print(f'silk labels placed: {len(result)} ({", ".join(f"{n} at {s} mm" for s, n in sorted(sizes.items(), reverse=True))}), '
      f'{sum(1 for g in result.values() if g[4])} vertical; not placed: {problems or "none"}')
