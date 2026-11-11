"""Render the two-sided TB1 board file: front view and back view (back shown as seen from behind)."""
import sys, math, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Rectangle, Circle

F, OUT, W, H = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
OX, OY = 50.0, 40.0
b = sx.parse(open(F).read())


def rot(x, y, r):
    a = math.radians(r); c, s = math.cos(a), math.sin(a)
    return x * c + y * s, -x * s + y * c


NETC = {'GND': '#2e8b57', '+5V': '#d62728', '+3V3_PER': '#ff7f0e'}
SB1 = os.environ.get('BOARD', 'TB1') in ('SB1', 'MBUSB')
GR = os.environ.get('BOARD', 'TB1') == 'MBUSB'   # also draw board-level rects (slots, parking pads, V outline)


def netcol(n_):
    if SB1 and n_:   # SB1: every 5 V net red (ribbon, USB VBUS, per-sensor), the 3.3 V logic rail orange
        n_ = n_.split('/')[-1]
        if n_ == 'GND':
            return '#2e8b57'
        if n_.startswith('+5V') or n_.startswith('VBUS'):
            return '#d62728'
        if n_ == '+3V3':
            return '#ff7f0e'
    return NETC.get(n_, '#999' if n_ else '#ccc')
fig, axs = plt.subplots(1, 2, figsize=(15, 13.5 if H > 80 else 8.2), dpi=110)
for ax, side in zip(axs, ('F', 'B')):
    mx = (lambda x: x) if side == 'F' else (lambda x: W - x)
    ax.add_patch(Rectangle((0, 0), W, H, fill=False, lw=2, ec='k'))
    silk = 'F.SilkS' if side == 'F' else 'B.SilkS'
    crt = 'F.CrtYd' if side == 'F' else 'B.CrtYd'
    for f in findall(b, 'footprint'):
        ref = next(str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference')
        fside = 'B' if str(find(f, 'layer')[1]) == 'B.Cu' else 'F'
        at = find(f, 'at'); X, Y = float(at[1]) - OX, float(at[2]) - OY; R = float(at[3]) if len(at) > 3 else 0
        mine = fside == side
        for g in f:
            if not (isinstance(g, list) and g[0] in ('fp_line', 'fp_rect', 'fp_circle')):
                continue
            L = str(find(g, 'layer')[1])
            if L not in (silk, crt) or not mine:
                continue
            col, lw = ('#3b6fb6', 0.35) if L == crt else ('#b8860b', 0.5)
            if g[0] == 'fp_circle':
                c, e = find(g, 'center'), find(g, 'end'); cx, cy = float(c[1]), float(c[2])
                rr = math.hypot(float(e[1]) - cx, float(e[2]) - cy); dx, dy = rot(cx, cy, R)
                ax.add_patch(Circle((mx(X + dx), Y + dy), rr, fill=False, ec=col, lw=lw)); continue
            s_, e_ = find(g, 'start'), find(g, 'end')
            p0, p1 = (float(s_[1]), float(s_[2])), (float(e_[1]), float(e_[2]))
            pts = [p0, p1] if g[0] == 'fp_line' else [p0, (p1[0], p0[1]), p1, (p0[0], p1[1]), p0]
            q = [(mx(X + rot(px, py, R)[0]), Y + rot(px, py, R)[1]) for px, py in pts]
            ax.plot([p[0] for p in q], [p[1] for p in q], c=col, lw=lw)
        for p in findall(f, 'pad'):
            tht = p[2] in ('thru_hole', 'np_thru_hole')
            if not (mine or tht):
                continue
            pa = find(p, 'at'); dx, dy = rot(float(pa[1]), float(pa[2]), R)
            sz = find(p, 'size'); w, h = float(sz[1]), float(sz[2])
            pr = float(pa[3]) if len(pa) > 3 else 0
            cx, cy = X + dx, Y + dy
            corners = [rot(a, c, pr) for a, c in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
            net = find(p, 'net'); n_ = str(net[1]) if net else ''
            fc = netcol(n_) if mine else '#bbbbbb'
            ax.add_patch(Polygon([(mx(cx + a), cy + c) for a, c in corners], closed=True, fc=fc, ec='none', alpha=0.9 if mine else 0.5))
            if tht:
                d = find(p, 'drill'); dd = float([v for v in d[1:] if not isinstance(v, list) and v != 'oval'][0])
                ax.add_patch(Circle((mx(cx), cy), dd / 2, fc='white', ec='none'))
        if mine:
            big = ref in ('A1', 'M1', 'J13', 'J7') and not GR
            ax.text(mx(X), Y, ref, fontsize=10 if big else 4.2, ha='center', va='center', color='k',
                    alpha=0.35 if ref in ('A1', 'M1') else 1)
    for g in (findall(b, 'gr_rect') if GR else []):
        L = str(find(g, 'layer')[1])
        if L in (silk, 'Edge.Cuts', 'F.Fab' if side == 'F' else '-'):
            s_, e_ = find(g, 'start'), find(g, 'end')
            x0, y0, x1, y1 = float(s_[1]) - OX, float(s_[2]) - OY, float(e_[1]) - OX, float(e_[2]) - OY
            col = {'Edge.Cuts': 'k', 'F.Fab': '#9467bd'}.get(L, '#b8860b')
            ax.add_patch(Rectangle((min(mx(x0), mx(x1)), y0), abs(x1 - x0), y1 - y0, fill=False, ec=col,
                                   lw=0.8 if L == 'Edge.Cuts' else 0.6, ls='--' if L == 'F.Fab' else '-'))
    for g in findall(b, 'gr_text'):
        if str(find(g, 'layer')[1]) == silk:
            a_ = find(g, 'at')
            ax.text(mx(float(a_[1]) - OX), float(a_[2]) - OY, str(g[1]), fontsize=7, color='#b8860b',
                    rotation=float(a_[3]) if len(a_) > 3 else 0, ha='center', va='center')
    ax.set_xlim(-3, W + 3); ax.set_ylim(H + 10, -4); ax.set_aspect('equal')
    ax.set_title('FRONT (room side)' if side == 'F' else 'BACK, as seen from behind (mirrored)', fontsize=11)
LEG = 'red 5 V nets / orange +3V3' if SB1 else 'red +5V / orange +3V3_PER'
fig.suptitle(f'{os.environ.get("BOARD", "TB1")} {W:g} x {H:g} mm - pads green GND / {LEG} / grey other; light grey = pins of parts on the other side; courtyards blue, silk gold',
             fontsize=9)
plt.tight_layout(); plt.savefig(OUT)
print('ok')
