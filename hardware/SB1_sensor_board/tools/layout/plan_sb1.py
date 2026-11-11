"""SB1 big-part plan and placement anchors (2026-10-25; ribbon header stood on end and cut to 20 pins 10/26).

Fixed parts (footprint origins, front-view board mm, origin top-left):
  - Board 70 x 56.5 mm. H1-H4: TB1's holes (3.5 mm in from the top and side edges, 63 x 48 mm apart), front-mount
    0.27 in clearance.
  - J4 LD6004 on the top edge and J5 LD2450 below it (front), same as TB1's J7 / J13.
  - J3 ribbon header on the back: straight 2x10 shrouded header standing on end (long side top to bottom), centred
    left-right, pins from just below the LD2450 (y 27.6) to y 50.46, pin 1 at the top. The flat cable leaves straight
    back edge-on and swings sideways (bending the easy way) to the mainboard directly behind the two sensor boards.
    It can't go behind the radars (no through-hole pins there) or near a side edge (on one board of each pair that
    edge is the point of the V). Its shroud sets the board height: 56.5 mm (64 mm with the 2x13 it replaced).
  - J1 / J2 USB-C on the back at the bottom edge (bench use), clear of the hole clearances.
Anchors: decoupling / input caps whose nets are all rails get pinned to the nearest (in the schematic) chip pin on
the same rail; the LD6004 buck is placed as one rigid group.
usage: plan_sb1.py <out_dir>   -> <out>/plan.json, <out>/plan.json.radars, anchors.json (next to this script)
"""
import json, csv, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall
import schdata

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
H = float(os.environ.get('SB1_H', '56.5'))
W = 70.0
PLAN = {
    'H1': (3.5, 3.5, 0, 'F'), 'H2': (66.5, 3.5, 0, 'F'), 'H3': (3.5, 51.5, 0, 'F'), 'H4': (66.5, 51.5, 0, 'F'),
    'J4': (35.0, 4.3, 0, 'F'),                 # LD6004 (TB1 J7)
    'J5': (35.0, 18.2, 0, 'F'),                # LD2450 (TB1 J13)
    'J3': (36.27, 27.6, 180, 'B'),             # ribbon: pin rows x 36.27 (odd) / 33.73 (even), y 27.6..50.46 (SB1_J3 overrides)
    'J1': (16.2, H - 3.68, 180, 'B'),          # USB-C A (LD6004), mouth on the bottom edge
    'J2': (53.8, H - 3.68, 180, 'B'),          # USB-C B (LD2450)
}
if os.environ.get('SB1_J3'):
    PLAN['J3'] = tuple(json.loads(os.environ['SB1_J3']))
json.dump(PLAN, open(f'{OUT}/plan.json', 'w'), indent=0)
json.dump({'J4': 'LD6004', 'J5': 'LD2450'}, open(f'{OUT}/plan.json.radars', 'w'))

# ---------------------------------------------------------------- anchors from the netlist + schematic positions
P = schdata.P
rows = [r for r in csv.DictReader(open(f'{P}/netlist_report.csv')) if not r['Ref'].startswith('#')]
NETS, PNAME = {}, {}
for r in rows:
    NETS.setdefault(r['Ref'], {})[r['Pin']] = r['Net']
    PNAME[(r['Ref'], r['Pin'])] = r['Pin name']
SUPPLY = ('VCC', 'VS', 'VIN', 'VDD', 'IN', 'VBUS', '+5V')
POS = {}
syms, _, _, _, SHEETS = schdata.load()
for f in SHEETS:
    e = sx.parse(open(f'{P}/{f}').read())
    for s in findall(e, 'symbol'):
        props = {str(p[1]): str(p[2]) for p in findall(s, 'property')}
        ref = props.get('Reference', '#')
        if not ref.startswith('#'):
            at = find(s, 'at')
            POS[ref] = (f, float(at[1]), float(at[2]))
RAILS = {'GND', '+3V3', '+5V_A', '+5V_B', '+5V_RIB', '+5V_LOGIC', 'VBUS_A', 'VBUS_B'}
anchor, cluster = {}, {}

# LD6004 buck: input cap(s), inductor on SW, feedback parts, output cap on the inductor
buck = next(r for r, n in NETS.items() if r.startswith('U') and 'A_SW' in n.values())
vin_pin = next(p for p, n in NETS[buck].items() if n == '+5V_A')
sw_pin = next(p for p, n in NETS[buck].items() if n == 'A_SW')
fb_pin = next(p for p, n in NETS[buck].items() if n == 'A_FB')
ind = next(r for r, n in NETS.items() if r != buck and 'A_SW' in n.values())
ind_out = next(p for p, n in NETS[ind].items() if n != 'A_SW')
cin = sorted([r for r, n in NETS.items() if r.startswith('C') and set(n.values()) == {'+5V_A', 'GND'}],
             key=lambda r: 0 if 'u' in r else 1)
fbp = sorted(r for r, n in NETS.items() if r not in (buck,) and 'A_FB' in n.values())
cout = [r for r, n in NETS.items() if r.startswith('C') and set(n.values()) == {NETS[ind][ind_out], 'GND'}]
order = []
if cin:
    anchor[cin[0]] = (buck, vin_pin); order.append(cin[0])
anchor[ind] = (buck, sw_pin); order.append(ind)
for c in cin[1:]:
    anchor[c] = (buck, vin_pin); order.append(c)
for r in fbp:
    anchor[r] = (buck, fb_pin); order.append(r)
for c in cout:
    anchor[c] = (ind, ind_out); order.append(c)
cluster[buck] = order

# rail-only caps elsewhere -> nearest chip / connector pin on the same rail (same sheet)
for r, n in NETS.items():
    if not r.startswith('C') or r in anchor:
        continue
    nets = set(n.values())
    if not nets <= RAILS:
        continue
    rail = next(x for x in nets if x != 'GND')
    f, x0, y0 = POS[r]
    best = None
    for o, on in NETS.items():
        if o == r or o[0] not in 'UJ' or o not in POS or POS[o][0] != f:
            continue
        pins = sorted([p for p, nn in on.items() if nn == rail], key=lambda p: 0 if PNAME.get((o, p), '') in SUPPLY else 1)
        if not pins:
            continue
        d = math.hypot(POS[o][1] - x0, POS[o][2] - y0)
        if best is None or d < best[0]:
            best = (d, o, pins[0])
    if best:
        anchor[r] = (best[1], best[2])
json.dump({'anchor': anchor, 'cluster': cluster}, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'anchors.json'), 'w'), indent=1)
print('plan:', PLAN)
print('buck cluster:', cluster)
print('anchors:', {k: v for k, v in anchor.items() if k not in sum(cluster.values(), [])})
