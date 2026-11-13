"""Connector pinouts on the silkscreen, in the free areas beside each connector (John, 11/11), so the board can be
probed with everything fitted. Board-level texts tagged by uuid; re-running replaces them. Fails (exit 1) if a label
would land on a pad, a part body, other silk or within 0.5 mm of the edge.
  J7 (FFC, back): pad number and signal on every row, right of the ZIF, in the LD2450 ground area (no parts there)
  J6 (spare header, back): signal beside each pin
  J5 (LD2450 header, pins seen on the back): pin names above / below its two rows
  J4 (LD6004 sockets, front): signal beside each pin, outside the module's outline
  J1 / J2 (mic breakouts, pins seen on the front): pin names under each pin
Back texts are mirrored (readable from the back); all are centred, so mirroring can't move them.
usage: pinlabels.py board.kicad_pcb"""
import math, os, sys, uuid, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sx
from sx import find, findall

PCB = sys.argv[1]
NS = uuid.UUID('6b1f3c2e-9a57-4f0e-8d2e-2c51f0a0d004')
SIZE, THICK = 0.8, 0.12
b = sx.parse(open(PCB).read())
TAGGED = lambda g: isinstance(g, list) and g[0] == 'gr_text' and find(g, 'uuid') and \
    str(find(g, 'uuid')[1]).startswith(str(uuid.uuid5(NS, 'tag'))[:8])
b[:] = [g for g in b if not TAGGED(g)]                         # drop earlier copies

# obstacle geometry: the collection part of silkrefs.py, run on the cleaned board
tmp = tempfile.NamedTemporaryFile('w', suffix='.kicad_pcb', delete=False); tmp.write(sx.dump(b) + '\n'); tmp.close()
src = open(os.path.join(HERE, 'silkrefs.py')).read()
src = src[:src.index('def justified(t):')]
ns = {'__file__': os.path.join(HERE, 'silkrefs.py')}
argv = sys.argv; sys.argv = [argv[0], tmp.name]; exec(compile(src, 'silkrefs', 'exec'), ns); sys.argv = argv
os.unlink(tmp.name)
pads, silk, bodies, INNER, text_box, over = ns['pads'], ns['silk'], ns['bodies'], ns['INNER'], ns['text_box'], ns['over']
labels = ns['labels']


def rot(x, y, r):
    a = math.radians(r); return x * math.cos(a) + y * math.sin(a), -x * math.sin(a) + y * math.cos(a)


P = {}                                                          # (ref, pad) -> (x, y, half-w, half-h, net)
for f in findall(b, 'footprint'):
    ref = [str(p[2]) for p in findall(f, 'property') if p[1] == 'Reference'][0]
    at = find(f, 'at'); X, Y = float(at[1]), float(at[2]); R = float(at[3]) if len(at) > 3 else 0
    for p in findall(f, 'pad'):
        q = find(p, 'at'); dx, dy = rot(float(q[1]), float(q[2]), R); sz = find(p, 'size'); n = find(p, 'net')
        pr = math.radians(float(q[3]) if len(q) > 3 else R); w, h = float(sz[1]), float(sz[2])
        P[(ref, str(p[1]), round(X + dx, 2), round(Y + dy, 2))] = (X + dx, Y + dy, abs(w / 2 * math.cos(pr)) + abs(h / 2 * math.sin(pr)),
                                                                  abs(w / 2 * math.sin(pr)) + abs(h / 2 * math.cos(pr)), str(n[-1]) if n else '')
pins = lambda ref: sorted([(k[1], v) for k, v in P.items() if k[0] == ref and k[1].isdigit()], key=lambda t: int(t[0]))
NAME = {'GND': 'GND', '+5V': '+5V', '/Power_IO/SPARE1': 'SPARE1', '/Power_IO/SPARE2': 'SPARE2', 'L_6004_P20': '6004 P20',
        '/Power_IO/I2C_SCL': 'SCL', '/Power_IO/I2C_SDA': 'SDA', '/Power_IO/L_MIC_DATA': 'MIC DATA', '/Power_IO/L_WS': 'I2S WS',
        '/Power_IO/L_BCLK': 'I2S BCLK', 'L_2450_RX': '2450 RX', 'L_2450_TX': '2450 TX', 'L_6004_RX': '6004 RX',
        'L_6004_TX': '6004 TX'}
CW = 0.84
width = lambda t: len(t) * SIZE * CW + THICK
out = []                                                         # (side, text, cx, cy, vertical, key)


def put(side, txt, cx, cy, vertical=False, key=None):
    out.append((side, txt, cx, cy, vertical, key or f'{side}{txt}{cx:.2f}{cy:.2f}'))


# J7: number column next to the ZIF, name column beyond it, one row per pad
J7X = max(bx[2] for r, bx in bodies['B'] if r == 'J7') + 0.9
for n, (x, y, hw, hh, net) in pins('J7'):
    put('B', n, J7X + width('20') / 2, y, key=f'J7n{n}')
    nm = NAME.get(net, net.split('/')[-1])
    put('B', nm, J7X + width('20') + 0.6 + width(nm) / 2, y, key=f'J7s{n}')
put('B', 'J7 FFC: pad, signal (wire = 21 - pad)', J7X + width('J7 FFC: pad, signal (wire = 21 - pad)') / 2,
    min(v[1] for k, v in pins('J7')) - 1.6, key='J7h')
# J6: beside each pin
for n, (x, y, hw, hh, net) in pins('J6'):
    nm = NAME.get(net, net.split('/')[-1])
    put('B', nm, x + hw + 0.9 + width(nm) / 2, y, key=f'J6{n}')
# J5 (LD2450 2x4, front part, pins through): names from the module's own pin labels, seen on the back
J5N = {}
for L in labels:                                                 # its front pin labels: the text nearest each pad
    if L['ref'] == 'J5' and not L['is_ref'] and len(L['txt']) <= 3:
        cx, cy = (L['cur'][0] + L['cur'][2]) / 2, (L['cur'][1] + L['cur'][3]) / 2
        k = min((k for k in P if k[0] == 'J5'), key=lambda k: math.hypot(P[k][0] - cx, P[k][1] - cy))
        J5N[k] = L['txt']
rows = sorted({round(v[1], 2) for k, v in P.items() if k[0] == 'J5'})
for k, nm in J5N.items():
    x, y, hw, hh, net = P[k]
    if round(y, 2) == rows[0]:                                   # top row: vertical, above
        put('B', nm, x, y - hh - 0.35 - width(nm) / 2, vertical=True, key=f'J5{k[2]}{k[3]}')
    else:                                                        # bottom row: horizontal, below
        put('B', nm, x, y + hh + 0.3 + (SIZE + THICK) / 2, key=f'J5{k[2]}{k[3]}')
# J4 (LD6004, front): beside each signal pin, outside the module
J4X = max(bx[2] for r, bx in bodies['F'] if r == 'J4') + 0.25
J4N = {'L_6004_P20': 'P20', 'A_TXO': 'TX', 'A_RXI': 'RX', 'GND': 'GND', 'A_3V3': '3V3'}
for n, (x, y, hw, hh, net) in pins('J4'):
    nm = J4N.get(net.split('/')[-1])
    if nm == 'P20':                                              # pin 1: J4's pin-1 mark is beside it, so under it
        put('F', nm, x, max(bx[3] for r, bx in bodies['F'] if r == 'J4') + 0.45 + (SIZE + THICK) / 2, key=f'J4{n}')
    elif nm:
        put('F', nm, max(J4X, x + hw + 0.25) + width(nm) / 2, y, key=f'J4{n}')
# J1 / J2 mics: under each pin on the front, in two staggered rows (2.54 mm pitch is too tight for 4 letters)
MIC = {'+3V3': '3V3', 'GND': 'GND', '/Power_IO/MIC_BCLK': 'BCLK', '/Power_IO/MIC_DOUT': 'DOUT', '/Power_IO/MIC_WS': 'WS'}
for ref in ('J1', 'J2'):
    for n, (x, y, hw, hh, net) in pins(ref):
        nm = 'SEL' if n == '6' else MIC.get(net, net)
        row = 0 if int(n) % 2 else 1
        put('F', nm, x, y + hh + 0.25 + (SIZE + THICK) / 2 + row * (SIZE + THICK + 0.1), key=f'{ref}{n}')

# ---------------------------------------------------------------- reference designators in the way move aside
def unrot(dx, dy, r):
    a = math.radians(r); return dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a)


new_boxes = {'F': [], 'B': []}
for side, txt, cx, cy, vert, key in out:
    new_boxes[side].append(text_box(cx, cy, txt, SIZE, THICK, vert))


def clean(bx, side, skip=None, own=None):
    if not (INNER[0] <= bx[0] and INNER[1] <= bx[1] and bx[2] <= INNER[2] and bx[3] <= INNER[3]):
        return False
    if any(over(bx, p, 0.2) for p in pads[side]) or any(over(bx, o, 0.1) for r, o in silk[side]):
        return False
    if any(over(bx, o) for r, o in bodies[side]) or any(over(bx, o, 0.15) for o in new_boxes[side]):
        return False
    return not any(over(bx, L['cur'], 0.15) for L in labels if L['side'] == side and L is not skip)


moved = []
for L in labels:
    if not L['is_ref'] or not any(over(L['cur'], o, 0.1) for o in new_boxes[L['side']]):
        continue
    w, h = L['cur'][2] - L['cur'][0], L['cur'][3] - L['cur'][1]
    c0 = ((L['cur'][0] + L['cur'][2]) / 2, (L['cur'][1] + L['cur'][3]) / 2)
    body = L['body'] or L['cur']
    cands = [(c0[0] + i * 0.25, c0[1] + j * 0.25) for i in range(-24, 25) for j in range(-24, 25)]
    cands.sort(key=lambda c: math.hypot(c[0] - c0[0], c[1] - c0[1]))
    for cx, cy in cands:
        bx = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        if ns['rdist'](bx, body) > 2.5 or not clean(bx, L['side'], skip=L):
            continue
        lx, ly = unrot(cx - L['X'], cy - L['Y'], L['R'])
        for f in findall(b, 'footprint'):                        # the same text in this script's own copy of the board
            for t in findall(f, 'property'):
                if t[1] == 'Reference' and str(t[2]) == L['ref']:
                    ta = find(t, 'at'); ta[1], ta[2] = round(lx, 3), round(ly, 3)
        L['cur'] = bx; moved.append((L['ref'], round(cx, 2), round(cy, 2)))
        break
    else:
        print('could not move', L['ref'])

# ---------------------------------------------------------------- check, then write
bad, placed = [], {'F': [], 'B': []}
for side, txt, cx, cy, vert, key in out:
    bx = text_box(cx, cy, txt, SIZE, THICK, vert)
    why = []
    if not (INNER[0] <= bx[0] and INNER[1] <= bx[1] and bx[2] <= INNER[2] and bx[3] <= INNER[3]):
        why.append('edge')
    if any(over(bx, p, 0.2) for p in pads[side]):
        why.append('pad')
    if any(over(bx, o) for r, o in bodies[side]):
        why.append('body ' + ','.join(r for r, o in bodies[side] if over(bx, o)))
    if any(over(bx, o, 0.1) for r, o in silk[side]):
        why.append('silk')
    if any(over(bx, L['cur'], 0.1) for L in labels if L['side'] == side):
        why.append('text ' + ','.join(L['txt'] for L in labels if L['side'] == side and over(bx, L['cur'], 0.1))[:30])
    if any(over(bx, o, 0.05) for o in placed[side]):
        why.append('own')
    placed[side].append(bx)
    if why:
        bad.append((txt, side, round(cx, 2), round(cy, 2), why))
    eff = ['effects', ['font', ['size', SIZE, SIZE], ['thickness', THICK]]] + ([['justify', 'mirror']] if side == 'B' else [])
    b.append(['gr_text', sx.Q(txt), ['at', round(cx, 3), round(cy, 3)] + ([90] if vert else []), ['layer', sx.Q(f'{side}.SilkS')],
              ['uuid', sx.Q(str(uuid.uuid5(NS, 'tag'))[:8] + str(uuid.uuid5(NS, key))[8:])], eff])
tail = [g for g in b if isinstance(g, list) and g[0] == 'embedded_fonts']
for g in tail:
    b.remove(g); b.append(g)
if bad:
    for x in bad:
        print('pin label clash:', x)
    sys.exit(1)
open(PCB, 'w').write(sx.dump(b) + '\n')
print(f'pin labels: {len(out)} texts (J7, J6, J5 on the back; J4, J1, J2 on the front); refs moved aside: {moved or "none"}')
