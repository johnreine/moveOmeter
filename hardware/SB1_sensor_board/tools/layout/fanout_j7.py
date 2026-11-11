"""J7 signal fan-out (11/8): every non-GND pad of the ZIF gets a short stub to its own via just inside the pad's inner end,
in the same column as the GND fan-out vias, so each signal is on both layers right at the connector. Around J7 the
back is crowded (ZIF body, cable lane, parts on the edge side) and the LD2450 ground area allows no tracks or vias; the
front strip beside it (x 0.5-13.5 on SB1) is open. Freerouting left most J7 nets unrouted without this. Locked.
Signals at 0.2 mm, power rows at 0.5 mm, vias 0.6 / 0.3. Run after fanout_gnd.py. usage: fanout_j7.py board.kicad_pcb"""
import math, os, sys, uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall

PCB = sys.argv[1]
REF = 'J7'
POWER = ('+5V',)
NS = uuid.UUID('6b1f3c2e-9a57-4f0e-8d2e-2c51f0a0d003')
b = sx.parse(open(PCB).read())


def rot(x, y, r):
    a = math.radians(r)
    return x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a)


def U(*k):
    return str(uuid.uuid5(NS, '/'.join(map(str, k))))


n = 0
for f in findall(b, 'footprint'):
    ref = [str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference'][0]
    if ref != REF:
        continue
    at = find(f, 'at'); X, Y = float(at[1]), float(at[2]); R = float(at[3]) if len(at) > 3 else 0.0
    for p in findall(f, 'pad'):
        net = find(p, 'net'); net = str(net[-1]) if net else ''
        if not str(p[1]).isdigit() or net in ('', 'GND'):
            continue
        q = find(p, 'at'); dx, dy = rot(float(q[1]), float(q[2]), R); x, y = X + dx, Y + dy
        sz = find(p, 'size'); a = math.radians(float(q[3]) if len(q) > 3 else R)
        hw = abs(float(sz[1]) / 2 * math.cos(a)) + abs(float(sz[2]) / 2 * math.sin(a))
        vx = x + hw + 0.38 if X > x else x - hw - 0.38          # inner end = toward the footprint origin
        w = 0.5 if net in POWER else 0.2
        b.append(['segment', ['start', round(x, 4), round(y, 4)], ['end', round(vx, 4), round(y, 4)], ['width', w], ['locked', 'yes'],
                  ['layer', sx.Q('B.Cu')], ['net', sx.Q(net)], ['uuid', sx.Q(U('j7s', p[1]))]])
        b.append(['via', ['at', round(vx, 4), round(y, 4)], ['size', 0.6], ['drill', 0.3], ['layers', sx.Q('F.Cu'), sx.Q('B.Cu')],
                  ['locked', 'yes'], ['net', sx.Q(net)], ['uuid', sx.Q(U('j7v', p[1]))]])
        n += 1
tail = [g for g in b if isinstance(g, list) and g[0] == 'embedded_fonts']
for g in tail:
    b.remove(g); b.append(g)
open(PCB, 'w').write(sx.dump(b) + '\n')
print(f'{REF} signal fan-out: {n} vias')
