"""Pre-route the J3 <-> J7 bus (John, 11/8). Since 11/7 J7 is wired in reverse, so every net sits at the same height on
both ZIFs: J3 pad n and J7 pad 21-n. The back between them is the LD2450 solid-ground area (no tracks, no vias), which
made both autorouters send the bus round the board edges and run out of room. Instead each non-GND row goes straight:
pad (B.Cu) -> short stub -> via just inside the pad's inner end (same column as the GND fan-out vias) -> F.Cu straight
across -> via -> stub -> pad. Power rows at the Power width, signals at 0.2 mm. Locked; run after fanout_gnd.py.
The taps (pull-ups, mic, sensors) are left to the router: they join the bus near either ZIF.
usage: bus_route.py board.kicad_pcb"""
import math, os, sys, uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import find, findall

PCB = sys.argv[1]
POWER = {'+5V'}
W_SIG, W_PWR, VIA_D, VIA_DR = 0.2, 0.5, 0.6, 0.3
NS = uuid.UUID('6b1f3c2e-9a57-4f0e-8d2e-2c51f0a0d002')
b = sx.parse(open(PCB).read())


def rot(x, y, r):
    a = math.radians(r)
    return x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a)


pads, fpc = {}, {}
for f in findall(b, 'footprint'):
    ref = [str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference'][0]
    if ref not in ('J3', 'J7'):
        continue
    at = find(f, 'at'); X, Y = float(at[1]), float(at[2]); R = float(at[3]) if len(at) > 3 else 0.0
    fpc[ref] = X
    for p in findall(f, 'pad'):
        q = find(p, 'at'); dx, dy = rot(float(q[1]), float(q[2]), R); sz = find(p, 'size'); n = find(p, 'net')
        a = math.radians(float(q[3]) if len(q) > 3 else R)
        hw = abs(float(sz[1]) / 2 * math.cos(a)) + abs(float(sz[2]) / 2 * math.sin(a))
        pads[(ref, str(p[1]))] = (X + dx, Y + dy, hw, str(n[-1]) if n else '')


def U(*k):
    return str(uuid.uuid5(NS, '/'.join(map(str, k))))


def seg(a, c, w, layer, net, key):
    return ['segment', ['start', round(a[0], 4), round(a[1], 4)], ['end', round(c[0], 4), round(c[1], 4)], ['width', w],
            ['locked', 'yes'], ['layer', sx.Q(layer)], ['net', sx.Q(net)], ['uuid', sx.Q(U('bus', *key))]]


rows = 0
for k in range(1, 21):
    if ('J3', str(k)) not in pads:
        continue
    x3, y3, hw3, n3 = pads[('J3', str(k))]
    x7, y7, hw7, n7 = pads[('J7', str(21 - k))]
    assert n3 == n7 and abs(y3 - y7) < 1e-3, (k, n3, n7)
    if n3 in ('GND', ''):
        continue
    w = W_PWR if n3 in POWER else W_SIG
    # via just inside each pad's inner end (toward the footprint origin), like the GND fan-out vias
    v3 = (x3 - hw3 - VIA_D / 2 - 0.08 if x3 > fpc['J3'] else x3 + hw3 + VIA_D / 2 + 0.08, y3)
    v7 = (x7 - hw7 - VIA_D / 2 - 0.08 if x7 > fpc['J7'] else x7 + hw7 + VIA_D / 2 + 0.08, y7)
    # J3's inner end faces -x and J7's faces +x only if the origins sit that way; otherwise use the side facing the other ZIF
    if not (v7[0] < v3[0]):
        v3 = (x3 - hw3 - VIA_D / 2 - 0.08, y3); v7 = (x7 + hw7 + VIA_D / 2 + 0.08, y7)
    b.append(seg((x3, y3), v3, w, 'B.Cu', n3, (k, 's3')))
    b.append(seg((x7, y7), v7, w, 'B.Cu', n3, (k, 's7')))
    b.append(seg(v7, v3, w, 'F.Cu', n3, (k, 'x')))
    for v, t in ((v3, 'v3'), (v7, 'v7')):
        b.append(['via', ['at', round(v[0], 4), round(v[1], 4)], ['size', VIA_D], ['drill', VIA_DR],
                  ['layers', sx.Q('F.Cu'), sx.Q('B.Cu')], ['locked', 'yes'], ['net', sx.Q(n3)], ['uuid', sx.Q(U('bus', k, t))]])
    rows += 1
tail = [g for g in b if isinstance(g, list) and g[0] == 'embedded_fonts']
for g in tail:
    b.remove(g); b.append(g)
open(PCB, 'w').write(sx.dump(b) + '\n')
print(f'J3-J7 bus pre-routed: {rows} rows straight across on F.Cu')
