"""Top view of the FFC links (11/8): one ZIF per SB1 (J7 only). SB1-B unchanged; SB1-A's J7 sits near the apex, so its cable runs
out along the back, swings 135 deg round and enters a Mainboard ZIF turned to face -X. Same 51 mm Type A cable."""
import math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Rectangle
from ffc_geom import path as pathB, P, u, nb
from ffc_single_geom import pathA
INK, MUTED, GRID = '#1f2328', '#6e7781', '#d0d7de'
BOARD, ZIF, CABLE, GOLD, DIM = '#2f6f4f', '#6b5fd3', '#3d4650', '#d4a017', '#b42318'
plt.rcParams.update({'font.size': 8.5, 'svg.fonttype': 'none'})
INS = 3.5
gB = pathB(11.34, 6, 6)
gA = pathA(6, 44.0)
mir = lambda p: (100 - p[0], p[1])
img = lambda p: (p[0], -p[1])
def band(x0, x1, o0, o1): return [P(x0, o0), P(x1, o0), P(x1, o1), P(x0, o1)]
def offset_poly(pl, d):
    out = []
    for i, (x, y) in enumerate(pl):
        a = pl[max(i - 1, 0)]; b = pl[min(i + 1, len(pl) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]; n = math.hypot(tx, ty) or 1
        out.append((x - ty / n * d, y + tx / n * d))
    return out
# full cables incl. the parts inside the connectors
pB = gB['pts']; t0 = (-u[0], -u[1])
fullB = [mir(p) for p in [(pB[0][0] - t0[0] * INS, pB[0][1] - t0[1] * INS)] + pB + [(pB[-1][0] - INS, pB[-1][1])]]
pA = gA['pts']
fullA = [(pA[0][0] - u[0] * INS, pA[0][1] - u[1] * INS)] + pA + [(pA[-1][0] + INS, pA[-1][1])]
MXA = gA['mouth'][0]

fig, ax = plt.subplots(figsize=(12.5, 5.8), dpi=200); ax.set_aspect('equal'); ax.axis('off')
ax.add_patch(Rectangle((8, 9.5), 84, 1.0, color=GRID, lw=0)); ax.text(93, 9.7, 'wall', color=MUTED, fontsize=8)
ax.add_patch(Rectangle((8, 0), 84, 1.6, color=BOARD, lw=0))
ax.text(50, 6.2, 'Mainboard-USB (front face toward the room)', ha='center', color=BOARD, fontsize=8)
for side in 'AB':
    f = img if side == 'A' else (lambda p: img(mir(p)))
    ax.add_patch(Polygon([f(p) for p in band(0, 42, -0.8, 0.8)], closed=True, color=BOARD, lw=0))
    ax.add_patch(Polygon([f(p) for p in band(4, 38, -0.8, -7.3)], closed=True, fc='#eef6f0', ec='none'))
    # J7 is the only ZIF: board-x 3.09-7.89 body, actuator 7.89-9.19, on the back. On SB1-B board-x runs from its outer end
    xb = (3.09, 7.89, 9.19) if side == 'A' else (42 - 3.09, 42 - 7.89, 42 - 9.19)
    ax.add_patch(Polygon([f(p) for p in band(min(xb[0], xb[1]), max(xb[0], xb[1]), 0.8, 2.7)], closed=True, color=ZIF, lw=0))
    ax.add_patch(Polygon([f(p) for p in band(min(xb[1], xb[2]), max(xb[1], xb[2]), 0.8, 2.2)], closed=True, color=ZIF, alpha=.55, lw=0))
# MB ZIFs: B side unchanged (mouth X 67, body to 70.95); A side turned round: mouth MXA facing -X, body MXA..MXA+3.95
ax.add_patch(Rectangle((67.0, -1.9), 3.95, 1.9, color=ZIF, lw=0)); ax.add_patch(Rectangle((65.7, -1.4), 1.3, 1.4, color=ZIF, alpha=.55, lw=0))
ax.add_patch(Rectangle((MXA, -1.9), 3.95, 1.9, color=ZIF, lw=0)); ax.add_patch(Rectangle((MXA - 1.3, -1.4), 1.3, 1.4, color=ZIF, alpha=.55, lw=0))
for pl, d in ((fullA, -0.42), (fullB, -0.42)):
    ax.plot(*zip(*[img(p) for p in pl]), color=CABLE, lw=2.0, solid_capstyle='butt', zorder=5)
    face = offset_poly(pl, d)
    ax.plot(*zip(*[img(p) for p in face]), color=GOLD, lw=0.8, ls=(0, (1.5, 1.5)), zorder=6)
    for e in (face[:2], face[-2:]): ax.plot(*zip(*[img(p) for p in e]), color=GOLD, lw=2.2, solid_capstyle='butt', zorder=7)
# dimensions
for X in range(0, 101, 10):
    ax.plot([X, X], [1.6, 2.6], color=DIM, lw=0.6); ax.text(X, 3.0, f'{X}', ha='center', va='bottom', fontsize=6.2, color=DIM)
ax.plot([0, 100], [1.6, 1.6], color=DIM, lw=0.6); ax.text(101.2, 3.0, 'X', fontsize=7.5, color=DIM, weight='bold')
RX = 102.5; ax.plot([RX, RX], [0, -35], color=DIM, lw=0.6)
for Yv in range(0, 36, 5):
    ax.plot([RX - .8, RX], [-Yv, -Yv], color=DIM, lw=.6); ax.text(RX + .8, -Yv, f'{Yv}', va='center', fontsize=6.2, color=DIM)
ax.text(RX + .2, -37.2, 'Y', fontsize=7.5, color=DIM, weight='bold')
def mark(xy, txt, tx, ty):
    ax.plot(xy[0], -xy[1], 'o', ms=2.6, color=DIM, zorder=12)
    ax.annotate(txt, xy=(xy[0], -xy[1]), xytext=(tx, ty), fontsize=6.8, color=DIM, va='center', zorder=12,
                arrowprops=dict(arrowstyle='-', color=DIM, lw=.45, shrinkA=1, shrinkB=1))
LX, RT = -40.0, 108.0
s = P(7.89, 1.8); c = gA['c']; lo = (c[0] - 6, c[1]); bot = pA[-2]
mark(P(5.5, 2.7), 'SB1-A J7 (near the apex), mouth\nopens toward SB1-A\'s outer end', LX, -30.0)
mark(P(20, 1.8), f'cable lies flat on the SB1-A back {gA["L1"]:.0f} mm,\nover the clear LD2450 ground area', LX, -22.0)
mark(lo, f'swing 135 deg, r 6 mm; furthest out\n({lo[0]:.1f}, {lo[1]:.1f})', LX, -13.0)
mark((MXA, 0.95), f'Mainboard J2 mouth ({MXA:.1f}, 1.0),\nopens toward -X (turned round 11/8)', LX, -5.0)
mark(mir(gB['pts'][0]), 'SB1-B J7 mouth (72.8, 9.6), as now', RT, -9.5)
mark((67.0, 0.95), 'Mainboard J3 mouth (67.0, 1.0), as now', RT, 3.0)
mark((50.0, 35.0), 'apex (50.0, 35.0)', 58.0, -37.5)
ax.text(30.0, -33.5, 'SB1-A', ha='center', fontsize=10, weight='bold', color=BOARD)
ax.text(70.0, -33.5, 'SB1-B', ha='center', fontsize=10, weight='bold', color=BOARD)
lx, ly = 66, -44.0
for i, (col, lw_, ls_, txt) in enumerate([(CABLE, 2, '-', '20-way FFC, 1.00 mm, 51 mm, Type A (same cable both sides)'),
        (GOLD, .8, (0, (1.5, 1.5)), 'contact face, followed along the cable'), (ZIF, 4, '-', 'Molex 200528 ZIF')]):
    ax.plot([lx, lx + 3.5], [ly - i * 2.4] * 2, color=col, lw=lw_, ls=ls_); ax.text(lx + 4.5, ly - i * 2.4, txt, va='center', fontsize=7.2, color=INK)
ax.text(-40, 15.5, 'Top view, to scale (mm): one ZIF per SB1 (J7), cable loop routing inside the V (11/8)', fontsize=11, weight='bold', color=INK)
ax.text(-40, 13.4, 'Looking down; wall at the top, room at the bottom. Both SB1s use J7: on SB1-B it is at the outer end, on SB1-A near '
        'the apex, so SB1-A\'s cable runs out along the back and swings round. Same 51 mm Type A cable both sides.', fontsize=8, color=MUTED)
ax.set_xlim(-41, 140); ax.set_ylim(-56, 17)
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
fig.savefig(f'{OUT}/ffc_top_view.png', bbox_inches='tight', facecolor='white')
fig.savefig(f'{OUT}/ffc_top_view.svg', bbox_inches='tight', facecolor='white')
# clearances
def dpt(p, poly): return min(math.hypot(p[0]-q[0], p[1]-q[1]) for q in poly)
back = [P(x / 10, 0.8) for x in range(0, 421)]
arc = pA[2:-1]
print('A loop min distance to SB1-A back face (beyond the flat run): %.2f' % min(dpt(p, back) for p in arc[20:]))
print('A cable to B cable min %.1f' % min(dpt(p, fullB) for p in fullA))
print('A loop span X %.1f-%.1f Y %.1f-%.1f' % (min(p[0] for p in fullA), max(p[0] for p in fullA), min(p[1] for p in fullA), max(p[1] for p in fullA)))
print('A free length', round(gA['L1'] + 3 * math.pi / 4 * 6 + gA['L2'], 2), 'B free', round(gB['length'], 2))
