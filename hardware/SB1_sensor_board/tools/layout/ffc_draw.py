"""FFC drawings for SB1 / Mainboard-USB. usage: python3 tools/layout/ffc_draw.py docs   (writes ffc_links_flat.png/.svg; ffc_single_draw.py writes ffc_top_view)
FFC loop-routing drawings (11/4). Fig 1: top view of the V to scale, cable path and contact face. Fig 2: each link
unfolded flat, seen from the contact face, with pin heights at both connectors. Geometry from geom.py (51 mm cable,
3.5 mm in each connector, U-turn r 6, last bend R 6)."""
import math, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import Polygon, Rectangle, FancyArrowPatch
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
from ffc_geom import path, P, u, nb, A, E

for f in fm.findSystemFonts():
    if 'Inter' in f:
        fm.fontManager.addfont(f)
plt.rcParams.update({'font.family': 'Inter', 'font.size': 8.5, 'svg.fonttype': 'none'})

INK, MUTED, GRID = '#1f2328', '#6e7781', '#d0d7de'
BOARD, ZIF, CABLE, GOLD, STIFF = '#2f6f4f', '#6b5fd3', '#3d4650', '#d4a017', '#4a90d9'
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'

# ------------------------------------------------------------------ geometry
g = path(11.34, 6, 6)                      # r6 R2 6 solution for a 51 mm cable
pts = g['pts']
INS = 3.5


def mirror(p):                             # SB1-B side
    return (100 - p[0], p[1])


def to_img(p):                             # top view: wall at the top of the picture, room at the bottom
    return (p[0], -p[1])


def offset_poly(pl, d):
    """Offset a polyline by d to its LEFT (left of the direction of travel)."""
    out = []
    for i, (x, y) in enumerate(pl):
        a = pl[max(i - 1, 0)]; b = pl[min(i + 1, len(pl) - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]; n = math.hypot(tx, ty) or 1
        out.append((x - ty / n * d, y + tx / n * d))
    return out


# cable including the parts inside the connectors (SB1 end: back toward the outer edge; MB end: on in -X)
t0 = (-u[0], -u[1])
s_in = (pts[0][0] - t0[0] * INS, pts[0][1] - t0[1] * INS)
m_in = (pts[-1][0] - INS, pts[-1][1])
full = [s_in] + pts + [m_in]


def board_band(x0, x1, off0, off1):        # rectangle along SB1-A, board-x x0..x1, offsets off0..off1 from its midline
    return [P(x0, off0), P(x1, off0), P(x1, off1), P(x0, off1)]


def fig_top():
    fig, ax = plt.subplots(figsize=(12.5, 5.6), dpi=200)
    ax.set_aspect('equal'); ax.axis('off')
    # wall and Mainboard-USB
    ax.add_patch(Rectangle((8, 9.5), 84, 1.0, color=GRID, lw=0))
    ax.text(93, 9.7, 'wall', color=MUTED, fontsize=8)
    ax.add_patch(Rectangle((8, 0), 84, 1.6, color=BOARD, lw=0))
    ax.text(50, 6.2, 'Mainboard-USB (front face toward the room)', ha='center', color=BOARD, fontsize=8)
    for side in (0, 1):
        f = (lambda p: to_img(p)) if side == 0 else (lambda p: to_img(mirror(p)))
        # SB1 board (midline A-E, 1.6 thick)
        ax.add_patch(Polygon([f(p) for p in board_band(0, 42, -0.8, 0.8)], closed=True, color=BOARD, lw=0))
        # front parts band (radars) on the room side, just to show which face is the front
        ax.add_patch(Polygon([f(p) for p in board_band(4, 38, -0.8, -7.3)], closed=True, fc='#eef6f0', ec='none', lw=0))
        # SB1 ZIF on the back: body board-x 34.1-38.9 (wide part), actuator to 32.8, 1.9 mm tall
        ax.add_patch(Polygon([f(p) for p in board_band(34.11, 38.91, 0.8, 2.7)], closed=True, color=ZIF, lw=0))
        ax.add_patch(Polygon([f(p) for p in board_band(32.81, 34.11, 0.8, 2.2)], closed=True, color=ZIF, alpha=0.55, lw=0))
        # MB ZIF: body X 29.05-33.0, actuator to 34.3, 1.9 tall
        if side == 0:
            mb_body, mb_act = (29.05, 33.0), (33.0, 34.3)
        else:
            mb_body, mb_act = (100 - 33.0, 100 - 29.05), (100 - 34.3, 100 - 33.0)
        ax.add_patch(Rectangle((mb_body[0], -1.9), mb_body[1] - mb_body[0], 1.9, color=ZIF, lw=0))
        ax.add_patch(Rectangle((mb_act[0], -1.4), mb_act[1] - mb_act[0], 1.4, color=ZIF, alpha=0.55, lw=0))
        # cable
        pl = full if side == 0 else [mirror(p) for p in full]          # world coordinates
        # contact face = the face toward SB1 at the SB1 end; for SB1-A that is the cable's LEFT side
        # (SB1-B is mirrored, so its contact face is the RIGHT side of its direction of travel)
        d = 0.42 if side == 0 else -0.42
        ax.plot(*zip(*[to_img(p) for p in pl]), color=CABLE, lw=2.0, solid_capstyle='butt', zorder=5)
        face = offset_poly(pl, d)
        ax.plot(*zip(*[to_img(p) for p in face]), color=GOLD, lw=0.8, ls=(0, (1.5, 1.5)), zorder=6)
        n = len(pl)
        ends = [face[:2], face[-2:]]            # exposed contact strip, inside each connector
        for e_ in ends:
            ax.plot(*zip(*[to_img(p) for p in e_]), color=GOLD, lw=2.2, solid_capstyle='butt', zorder=7)
        back = offset_poly(pl, -d)
        for e_ in (back[:2], back[-2:]):
            ax.plot(*zip(*[to_img(p) for p in e_]), color=STIFF, lw=2.2, solid_capstyle='butt', zorder=7)
    # labels
    lab = dict(fontsize=8, color=INK)
    ax.text(30.0, -33.0, 'SB1-A', ha='center', fontsize=10, weight='bold', color=BOARD, zorder=9)
    ax.text(70.0, -33.0, 'SB1-B', ha='center', fontsize=10, weight='bold', color=BOARD, zorder=9)
    ax.annotate('', xy=(50, -38.5), xytext=(50, -35.5), arrowprops=dict(arrowstyle='->', color=MUTED, lw=0.8))
    ax.text(51, -38.6, 'Room', color=MUTED, fontsize=8)
    # ---- dimensions: X ruler on the Mainboard, Y ruler at the right, coordinates of the key points
    DIM = '#b42318'
    for X in range(0, 101, 10):
        ax.plot([X, X], [1.6, 2.6], color=DIM, lw=0.6)
        ax.text(X, 3.0, f'{X}', ha='center', va='bottom', fontsize=6.2, color=DIM)
    ax.plot([0, 100], [1.6, 1.6], color=DIM, lw=0.6)
    ax.text(101.2, 3.0, 'X', fontsize=7.5, color=DIM, weight='bold')
    RX = 102.5
    ax.plot([RX, RX], [0, -35], color=DIM, lw=0.6)
    for Yv in range(0, 36, 5):
        ax.plot([RX - 0.8, RX], [-Yv, -Yv], color=DIM, lw=0.6)
        ax.text(RX + 0.8, -Yv, f'{Yv}', va='center', fontsize=6.2, color=DIM)
    ax.text(RX + 0.2, -37.2, 'Y', fontsize=7.5, color=DIM, weight='bold')
    ax.plot([50, RX], [-35, -35], color=DIM, lw=0.4, ls=(0, (2, 2)))

    def mark(xy, txt, tx, ty, ha='left', col=DIM):
        X, Yw = xy
        ax.plot(X, -Yw, 'o', ms=2.6, color=DIM, zorder=12)
        ax.annotate(txt, xy=(X, -Yw), xytext=(tx, ty), fontsize=6.8 if abs(tx - X) > 12 else 6.2, color=col, ha=ha, va='center', zorder=12,
                    arrowprops=dict(arrowstyle='-', color=DIM, lw=0.45, shrinkA=1, shrinkB=1))
    LX, RXT = -37.0, 108.0
    mark((20.3, 5.3), 'SB1-A outer end (20.3, 5.3)', LX, -3.0)
    mark((27.16, 9.61), 'SB1-A J3 mouth (27.2, 9.6),\nopens toward the centre', LX, -9.5)
    mark((35.18, 17.63), 'cable lies flat on the SB1 back ~11 mm,\nleaves it at (35.2, 17.6)', LX, -17.0)
    mark((39.42, 19.39), 'loop nearest the room (39.4, 19.4);\nU-turn r 6 mm, takes up length error', LX, -24.5)
    mark((79.7, 5.3), 'SB1-B outer end (79.7, 5.3)', RXT, -3.0)
    mark((72.84, 9.61), 'SB1-B J7 mouth (72.8, 9.6),\nopens toward the centre', RXT, -9.5)
    mark((60.58, 19.39), 'loop nearest the room (60.6, 19.4)', RXT, -24.5)
    mark((33.0, 0.95), 'Mainboard J2 mouth (33.0, 1.0)', LX, 3.0)
    mark((67.0, 0.95), 'Mainboard J3 mouth (67.0, 1.0)', RXT, 3.0)
    mark((50.0, 35.0), 'apex (50.0, 35.0)', 58.0, -37.5)
    ax.annotate('', xy=(45.42, -13.39), xytext=(54.58, -13.39), arrowprops=dict(arrowstyle='<->', color=DIM, lw=0.6, shrinkA=0, shrinkB=0))
    ax.text(50, -14.6, 'gap\n9.2', ha='center', va='top', fontsize=6.6, color=DIM)
    ax.text(45.0, -12.6, '(45.4, 13.4)', ha='right', va='bottom', fontsize=6.0, color=DIM)
    ax.text(55.0, -12.6, '(54.6, 13.4)', ha='left', va='bottom', fontsize=6.0, color=DIM)
    ax.text(LX, -40.0, 'Shaded: each SB1 front (radars), facing the room', fontsize=7.0, color=BOARD)
    # legend
    lx, ly = 70, -44.0
    for i, (col, lw_, ls_, txt) in enumerate([
            (CABLE, 2.0, '-', '20-way FFC, 1.00 mm, ~51 mm (Type A)'),
            (GOLD, 2.2, '-', 'exposed contacts (inside each ZIF)'),
            (GOLD, 0.8, (0, (1.5, 1.5)), 'contact face, followed along the cable'),
            (STIFF, 2.2, '-', 'stiffener (opposite face)'),
            (ZIF, 4, '-', 'Molex 200528 ZIF, 1.9 mm tall')]):
        ax.plot([lx, lx + 3.5], [ly - i * 2.4] * 2, color=col, lw=lw_, ls=ls_)
        ax.text(lx + 4.5, ly - i * 2.4, txt, va='center', fontsize=7.2, color=INK)
    ax.text(-37, 15.5, 'Top view, to scale (mm): cable loop routing inside the V', fontsize=11, weight='bold', color=INK)
    ax.text(-37, 13.4, 'Looking down. Wall at the top, room at the bottom, so SB1-A is on the left as seen from the room. '
            '(X, Y) in mm: X from Mainboard-USB\'s left edge as seen from the room, Y out from its front face.',
            fontsize=8, color=MUTED)
    ax.text(-37, -61.0, 'The contact face (gold) faces the SB1 at one end and the Mainboard at the other, and it is the same face of the '
            'cable all the way round: contacts on the same side at both ends (Type A).\nEvery bend is across the cable\'s thickness, about a vertical axis, so each conductor stays at the same height from end to end.',
            fontsize=7.6, color=INK, va='top')
    ax.set_xlim(-38, 140); ax.set_ylim(-66, 17)
    fig.savefig(f'{OUT}/ffc_top_view.png', bbox_inches='tight', facecolor='white')
    fig.savefig(f'{OUT}/ffc_top_view.svg', bbox_inches='tight', facecolor='white')


SIG = ['GND', '+5V', '+5V', 'GND', '6004 TX', '6004 RX', 'GND', '2450 TX', '2450 RX', 'GND', 'BCLK', 'GND', 'WS',
       'MIC DATA', 'GND', 'SDA', 'SCL', 'P20', 'SPARE1', 'SPARE2']


def fig_flat():
    K = 3.0                                     # vertical stretch: 1 mm of height = 3 drawing units
    L = 51.0
    fig, axs = plt.subplots(2, 1, figsize=(9.6, 11.0), dpi=200)
    for ax, side in zip(axs, 'AB'):
        ax.axis('off'); ax.set_aspect('equal')
        # height on Mainboard-USB (SB1 y + 8): side A pin 1 at y 60 (bottom); side B pin 1 at y 41 (top)
        # 11/7: SB1 J7 and MB J3 are wired in reverse, so GND (wire 1) is at the bottom on both links; on the B link it
        # lands on pad 20 of both connectors
        hy = lambda n: 60 - (n - 1)
        padno = lambda n: 21 - n                    # 11/8: SB1 J7 on both, MB J2 / J3 both reversed
        Y = lambda h: -(h - 50.5) * K                # drawing y, centred on y 50.5
        top, bot = Y(40.0), Y(61.0)
        ax.add_patch(Rectangle((0, bot), L, top - bot, fc='#f4f6f8', ec=CABLE, lw=0.9))
        for xa in (0, L - 4.0):                      # exposed contacts, both on this face (Type A)
            ax.add_patch(Rectangle((xa, bot), 4.0, top - bot, fc=GOLD, alpha=0.40, ec='none'))
        for n in range(1, 21):
            sig = SIG[n - 1]
            col = '#c0392b' if sig == '+5V' else ('#8c959f' if sig == 'GND' else '#57606a')
            ax.plot([0, L], [Y(hy(n))] * 2, color=col, lw=1.0 if sig == '+5V' else 0.6)
        for xa in (8.0, L - 8.0):                    # GND-wire marks, as on the paper mock-up
            ax.text(xa, Y(hy(1)), '1', fontsize=9, weight='bold', color='#c0392b', ha='center', va='center',
                    bbox=dict(boxstyle='circle,pad=0.18', fc='white', ec='#c0392b', lw=0.9), zorder=8)
        # connector pin columns
        for xc, lab, sub in ((-5.5, f"SB1-{side} J7", 'SB1 back'),
                             (L + 5.5, f"MB-USB {'J2' if side == 'A' else 'J3'}", 'Mainboard front')):
            ax.add_patch(Rectangle((xc - 2.2, bot - 1.5), 4.4, top - bot + 3.0, fc=ZIF, alpha=0.15, ec=ZIF, lw=0.7))
            ax.text(xc, top + 6.0, lab, ha='center', fontsize=8.5, weight='bold', color=ZIF)
            ax.text(xc, top + 3.0, sub, ha='center', fontsize=7, color=MUTED)
            for n in range(1, 21):
                ax.text(xc, Y(hy(n)), str(padno(n)), ha='center', va='center', fontsize=6.2, color=INK)
        for n in range(1, 21):                       # signal names outside each end
            sig = SIG[n - 1]
            col = '#c0392b' if sig == '+5V' else INK
            ax.text(-9.0, Y(hy(n)), sig, ha='right', va='center', fontsize=6.2, color=col)
            ax.text(L + 9.0, Y(hy(n)), sig, ha='left', va='center', fontsize=6.2, color=col)
        for h in (41, 60):
            ax.text(L + 24.5, Y(h), f'MB y {h}', va='center', fontsize=6.5, color=MUTED)
        ax.text(L / 2, top + 13.0, f'SB1-{side} link, unfolded flat, seen from the contact face', ha='center',
                fontsize=10.5, weight='bold', color=INK)
        ax.text(L / 2, top + 9.5, 'GND at the BOTTOM at both connectors: ' +
                'both wired in reverse (GND on pad 20), pad n meets pad n',
                ha='center', fontsize=8.5, color='#c0392b')
        ax.text(L / 2, bot - 4.0, 'Gold ends = exposed contacts (4 mm), both on this face. ~51 mm overall; height drawn 3x.',
                ha='center', fontsize=7.2, color=MUTED)
        ax.set_xlim(-26, L + 32); ax.set_ylim(bot - 7, top + 16)
    fig.text(0.07, 0.035,
             'It is the same 51 mm Type A cable on both sides, the same way up: GND on the bottom wire, contacts facing you at both '
             'ends. Both links are identical: SB1 J7 to MB-USB J2 / J3, all wired in reverse (11/8).\n'
             'Heights are on Mainboard-USB (SB1 y + 8). The bracket must hold each SB1 top edge at MB y 8, to about +/-0.5 mm.',
             fontsize=8, color=INK)
    fig.savefig(f'{OUT}/ffc_links_flat.png', bbox_inches='tight', facecolor='white')
    fig.savefig(f'{OUT}/ffc_links_flat.svg', bbox_inches='tight', facecolor='white')


if __name__ == '__main__':
    fig_flat()                                   # 11/8: the top view is drawn by ffc_single_draw.py
    print('cable free length', round(g['length'], 2), 'mouth', [round(v, 2) for v in g['mouth']])
