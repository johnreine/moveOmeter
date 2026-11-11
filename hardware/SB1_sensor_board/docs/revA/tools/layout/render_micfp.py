"""1:1 check print (A4 PDF) and an enlarged PNG of the mic-breakout socket footprint.
Lay an Adafruit 6049 / 3421 breakout on the print, sound-hole side up: its header pins should sit on the pads with
pin 1 (3V) at the square pad, and its sound hole on the cross.
usage: render_micfp.py <kicad_mod> <out.pdf> <out.png>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle, Arc

F, PDF, PNG = sys.argv[1:4]
fp = sx.parse(open(F).read())
COL = {'F.Fab': '#3b6fb6', 'F.SilkS': '#b8860b', 'F.CrtYd': '#bbbbbb'}


def draw(ax, lw_scale=1.0, labels=True):
    for g in fp:
        if not isinstance(g, list) or g[0] not in ('fp_line', 'fp_rect', 'fp_circle', 'fp_arc', 'fp_text'):
            continue
        L = str(find(g, 'layer')[1])
        if L not in COL:
            continue
        c = COL[L]; w = float(find(find(g, 'stroke'), 'width')[1]) * 2 * lw_scale if g[0] != 'fp_text' else 0
        if g[0] == 'fp_line':
            s, e = find(g, 'start'), find(g, 'end')
            ax.plot([float(s[1]), float(e[1])], [float(s[2]), float(e[2])], color=c, lw=w)
        elif g[0] == 'fp_rect':
            s, e = find(g, 'start'), find(g, 'end')
            x0, y0, x1, y1 = float(s[1]), float(s[2]), float(e[1]), float(e[2])
            ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0, fill=False, ec=c, lw=w))
        elif g[0] == 'fp_circle':
            cc, e = find(g, 'center'), find(g, 'end')
            r = math.hypot(float(e[1]) - float(cc[1]), float(e[2]) - float(cc[2]))
            ax.add_patch(Circle((float(cc[1]), float(cc[2])), r, fill=False, ec=c, lw=w))
        elif g[0] == 'fp_arc':
            pts = [(float(find(g, k)[1]), float(find(g, k)[2])) for k in ('start', 'mid', 'end')]
            (ax_, ay), (bx, by), (cx, cy) = pts
            d = 2 * (ax_ * (by - cy) + bx * (cy - ay) + cx * (ay - by))
            ux = ((ax_**2 + ay**2) * (by - cy) + (bx**2 + by**2) * (cy - ay) + (cx**2 + cy**2) * (ay - by)) / d
            uy = ((ax_**2 + ay**2) * (cx - bx) + (bx**2 + by**2) * (ax_ - cx) + (cx**2 + cy**2) * (bx - ax_)) / d
            r = math.hypot(ax_ - ux, ay - uy)
            a0, am, a2 = [math.degrees(math.atan2(y - uy, x - ux)) % 360 for x, y in pts]
            ccw = (am - a0) % 360 < (a2 - a0) % 360          # going counter-clockwise from start passes the mid point
            t1, t2 = (a0, a2) if ccw else (a2, a0)
            ax.add_patch(Arc((ux, uy), 2 * r, 2 * r, theta1=t1, theta2=t2, ec=c, lw=w))
        elif g[0] == 'fp_text' and labels:
            at = find(g, 'at'); sz = float(find(find(find(g, 'effects'), 'font'), 'size')[1])
            ax.text(float(at[1]), float(at[2]), str(g[2]), color=c, fontsize=sz * 2.835 * lw_scale * (2.2 if lw_scale >= 1 else 1), ha='center', va='center')
    for p in findall(fp, 'pad'):
        at = find(p, 'at'); x, y = float(at[1]), float(at[2]); sz = float(find(p, 'size')[1]); dr = float(find(p, 'drill')[1])
        if p[3] == 'rect':
            ax.add_patch(Rectangle((x - sz / 2, y - sz / 2), sz, sz, fc='#c87533', ec='none'))
        else:
            ax.add_patch(Circle((x, y), sz / 2, fc='#c87533', ec='none'))
        ax.add_patch(Circle((x, y), dr / 2, fc='white', ec='none'))
        if labels:
            ax.text(x, y + 1.6, str(p[1]), fontsize=6 * lw_scale, ha='center', va='center')


# 1:1 on A4 portrait (210 x 297 mm)
fig = plt.figure(figsize=(210 / 25.4, 297 / 25.4))
ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(-105, 105); ax.set_ylim(170, -127); ax.set_aspect('equal'); ax.axis('off')
draw(ax, 0.6, labels=False)
ax.plot([-25, 25], [40, 40], color='k', lw=1); ax.plot([-25, -25], [38.5, 41.5], color='k', lw=1); ax.plot([25, 25], [38.5, 41.5], color='k', lw=1)
ax.text(0, 44, '50 mm: measure this to check the print is 1:1', ha='center', fontsize=8)
ax.text(0, -40, 'SB1 mic socket footprint, 1:1 (Adafruit 6049 ICS-43434 / 3421 SPH0645)', ha='center', fontsize=10)
ax.text(0, -34, 'Lay the breakout sound-hole side up: pins on the pads, pin 1 (3V) on the square pad, sound hole on the cross.',
        ha='center', fontsize=7)
ax.text(0, 52, 'Blue: breakout outline, sound hole and its 2.5 mm holes. Gold: socket body on silk. Grey: courtyard.', ha='center', fontsize=7)
fig.savefig(PDF)
# enlarged preview
fig2, ax2 = plt.subplots(figsize=(7, 6.2), dpi=130)
draw(ax2, 1.0)
ax2.set_xlim(-10.5, 10.5); ax2.set_ylim(5.2, -12.4); ax2.set_aspect('equal')
ax2.set_title('SB1 mic socket footprint, seen from the front (room side)\nAdafruit 6049 / 3421 breakout lies over it, sound hole facing out', fontsize=9)
ax2.set_xlabel('mm'); ax2.grid(alpha=0.2)
fig2.tight_layout(); fig2.savefig(PNG)
print('ok')
