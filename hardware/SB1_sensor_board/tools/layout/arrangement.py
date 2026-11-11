"""Sketch of the 3-board arrangement (10/26): two SB1 sensor boards in a V (fronts 90 deg apart) and the mainboard
directly behind them. Each SB1's ribbon header stands on end in the middle of its back, so the flat cable leaves
edge-on and only bends sideways (the easy way) to a matching header on the mainboard.
usage: arrangement.py out.png
"""
import math, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon, Rectangle, Wedge
from matplotlib.path import Path
from matplotlib.patches import PathPatch

OUT = sys.argv[1]
fig, (a1, a2) = plt.subplots(1, 2, figsize=(13, 7.4), dpi=130, gridspec_kw={'width_ratios': [1.25, 1]})
INK, SB, MB, RIB, FOV1, FOV2 = '#222', '#3b6fb6', '#6a8f3a', '#c07a1a', '#3b6fb655', '#c0392b33'
HDR, PLUG = 9.0, 6.0          # header height off the board, mated IDC socket above it (approximate)
MB_Y = -70.0                  # mainboard front face in the top view (drawn ~20 mm behind the V; set by the enclosure)

# ---------------- top view
a1.set_title('Top view (looking down): two SB1s in a V, mainboard directly behind', fontsize=10.5)
W, T = 70.0, 1.6


def quad(c, t, n, half, d0, d1):
    cx, cy = c
    return [(cx + t[0] * half + n[0] * d0, cy + t[1] * half + n[1] * d0), (cx - t[0] * half + n[0] * d0, cy - t[1] * half + n[1] * d0),
            (cx - t[0] * half + n[0] * d1, cy - t[1] * half + n[1] * d1), (cx + t[0] * half + n[0] * d1, cy + t[1] * half + n[1] * d1)]


for sgn in (-1, 1):
    ang = math.radians(90 - sgn * 45)                       # facing direction: left board NW, right board NE
    nx, ny = math.cos(ang), math.sin(ang)
    t = (-ny, nx)                                            # along the board
    cx, cy = sgn * 24.75, -24.75                             # boards meet at the front apex (0, 0)
    a1.add_patch(Polygon(quad((cx, cy), t, (nx, ny), W / 2, 0, -T), closed=True, fc=SB, ec=INK, lw=0.8))
    d = math.degrees(ang)
    a1.add_patch(Wedge((cx, cy), 95, d - 60, d + 60, fc=FOV1 if sgn < 0 else FOV2, ec='none'))
    back = (-nx, -ny)
    a1.add_patch(Polygon(quad((cx, cy), t, back, 5.0, T, T + HDR), closed=True, fc='#444', ec=INK, lw=0.6))     # J3
    a1.add_patch(Polygon(quad((cx, cy), t, back, 3.6, T + HDR, T + HDR + PLUG), closed=True, fc='#777', ec=INK, lw=0.5))
    a1.text(cx + nx * 14, cy + ny * 14, 'SB1 ' + ('L' if sgn < 0 else 'R') + ' front', ha='center', va='center',
            fontsize=9, color=SB, rotation=-sgn * 45)
    # mainboard header for this SB1, standing on end, and the ribbon (edge-on, so a line in this view)
    mx = sgn * 14.0
    a1.add_patch(Rectangle((mx - 5.0, MB_Y), 10.0, HDR, fc='#444', ec=INK, lw=0.6))
    a1.add_patch(Rectangle((mx - 3.6, MB_Y + HDR), 7.2, PLUG, fc='#777', ec=INK, lw=0.5))
    e = (cx + back[0] * (T + HDR + PLUG), cy + back[1] * (T + HDR + PLUG))
    f = (mx, MB_Y + HDR + PLUG)
    k = 12.0
    verts = [e, (e[0] + back[0] * k, e[1] + back[1] * k), (f[0], f[1] + k), f]
    a1.add_patch(PathPatch(Path(verts, [Path.MOVETO, Path.CURVE4, Path.CURVE4, Path.CURVE4]), fc='none', ec=RIB, lw=2.6))
a1.add_patch(Rectangle((-50, MB_Y - T), 100, T, fc=MB, ec=INK, lw=0.8))
a1.text(0, MB_Y - 8, 'mainboard (its distance behind the V is up to the enclosure)', ha='center', fontsize=8.5, color=MB)
a1.text(0, -50, 'ribbons\n(edge-on)', ha='center', va='center', fontsize=7.5, color=RIB)
a1.text(0, 88, 'room', ha='center', fontsize=10)
a1.text(-98, 74, 'Each radar ±60°: ~210° per\nradar type, ~30° overlap\nstraight ahead', fontsize=8.5)
a1.set_xlim(-100, 100); a1.set_ylim(-82, 100); a1.set_aspect('equal'); a1.axis('off')

# ---------------- side view: one SB1 edge-on, its ribbon running level to the mainboard behind
a2.set_title('Side view: J3 stands on end; the ribbon runs level to the mainboard', fontsize=10.5)
H = 56.5
a2.add_patch(Rectangle((0, 0), T, H, fc=SB, ec=INK, lw=0.8))                     # SB1 edge-on, 56.5 mm tall
a2.add_patch(Rectangle((-7, H - 4.3 - 3.5), 7, 7, fc='#9ab', ec=INK, lw=0.6))      # LD6004 on the front
a2.add_patch(Rectangle((-8, H - 18.2 - 7.5), 8, 15, fc='#9ab', ec=INK, lw=0.6))    # LD2450
a2.text(-10, H - 8, 'radars\n(front)', ha='right', fontsize=8.5)
j_lo, j_hi = H - 50.46 - 5.6, H - 27.6 + 5.6                                        # J3 shroud, 0.4 .. 34.5 mm up
a2.add_patch(Rectangle((T, j_lo), HDR, j_hi - j_lo, fc='#444', ec=INK, lw=0.6))
a2.add_patch(Rectangle((T + HDR, j_lo + 3), PLUG, j_hi - j_lo - 6, fc='#777', ec=INK, lw=0.5))
a2.text(T + 1, j_hi + 2.5, 'J3: 2x10 shrouded header,\nlong side vertical', fontsize=8.5)
c_lo, c_hi = H - 50.46 - 1.3, H - 27.6 + 1.3                                        # the 25.4 mm wide 20-way flat cable
MBX = 62.0
a2.add_patch(Rectangle((T + HDR + PLUG, c_lo), MBX - HDR - PLUG - (T + HDR + PLUG), c_hi - c_lo, fc=RIB, ec='none', alpha=0.55))
a2.text((MBX + T) / 2, (c_lo + c_hi) / 2, 'flat ribbon,\nedge-on', ha='center', va='center', fontsize=8.5)
a2.add_patch(Rectangle((MBX, -14), T, 84, fc=MB, ec=INK, lw=0.8))                 # mainboard edge-on (size TBD)
a2.add_patch(Rectangle((MBX - HDR, j_lo), HDR, j_hi - j_lo, fc='#444', ec=INK, lw=0.6))
a2.add_patch(Rectangle((MBX - HDR - PLUG, j_lo + 3), PLUG, j_hi - j_lo - 6, fc='#777', ec=INK, lw=0.5))
a2.text(MBX + 3, 40, 'mainboard:\ntwo 2x10 headers,\nlong side vertical,\nsame height as J3', fontsize=8.5, color=MB)
a2.text(T + 1, -10, 'USB-C ports: back, bottom\ncorners (behind J3 in this view)', fontsize=7.5)
a2.set_xlim(-32, 98); a2.set_ylim(-20, 75); a2.set_aspect('equal'); a2.axis('off')
plt.tight_layout(); plt.savefig(OUT)
print('ok')
