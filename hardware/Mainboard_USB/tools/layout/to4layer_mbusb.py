"""Make Mainboard-USB a 4-layer board (John, 2026-11-13: the 2-layer board wouldn't finish routing; four layers cost
little more). usage: to4layer_mbusb.py moveOmeter_MBUSB.kicad_pcb   (rebuild.sh runs it after mkpcb_mbusb.py)

Stackup as on SB1 and TB1 (JLC04161H-7628, 1.6 mm): F.Cu signals + GND pour / In1.Cu GND plane / In2.Cu +5V plane /
B.Cu signals + GND pour. +5V no longer needs routing: every +5V pad reaches In2 by a via (fanout_mbusb.py) or its
own through-hole pin, so the 1 mm +5V tracks that walled off the signals are gone. In1 / In2 are layer type "power",
so Freerouting doesn't route on them, and moveOmeter_MBUSB.kicad_dru bans tracks there for KiCad's DRC. No rule area
covers the inner layers: on SB1 a board-wide one went into the DSN as a keep-out that also stopped Freerouting placing
vias."""
import sys, re, uuid, os
path = sys.argv[1]
t = open(path).read()
if '"In1.Cu"' in t:
    print('to4layer_mbusb: already 4 layers'); sys.exit(0)
NS = uuid.UUID('6b1f3c2e-1d4a-4c8e-9a51-3f0e2b7d9c10')
def U(*k): return str(uuid.uuid5(NS, '/'.join(map(str, k))))
# layer table
old = '\t\t(0 "F.Cu" signal)\n\t\t(2 "B.Cu" signal)\n'
assert t.count(old) == 1
t = t.replace(old, '\t\t(0 "F.Cu" signal)\n\t\t(4 "In1.Cu" power)\n\t\t(6 "In2.Cu" power)\n\t\t(2 "B.Cu" signal)\n')
# stackup (SB1's, kept in stackup4.txt)
stack = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stackup4.txt')).read().rstrip('\n')
i = t.find('\t\t(stackup'); depth = 0; j = i
while True:
    c = t[j]
    if c == '(': depth += 1
    elif c == ')':
        depth -= 1
        if depth == 0: break
    j += 1
t = t[:i] + stack + t[j + 1:]          # both start at the tabs before '(stackup'
t = t.replace('(comment 2 "2-layer: F.Cu sig+GND / B.Cu sig+GND; 5 V as Power tracks. Fill zones (B) after routing.")',
              '(comment 2 "4-layer: F.Cu sig+GND / In1 GND / In2 +5V / B.Cu sig+GND. Fill zones (B) after routing.")')
# board outline for the planes
m = re.search(r'\(gr_rect\s*\(start ([\d.]+) ([\d.]+)\)\s*\(end ([\d.]+) ([\d.]+)\)', t)
x0, y0, x1, y1 = m.groups()
def plane(net, layer, name):
    return (f'\t(zone\n\t\t(net "{net}")\n\t\t(layer "{layer}")\n\t\t(uuid "{U("plane", layer)}")\n\t\t(name "{name}")\n'
            f'\t\t(hatch edge 0.5)\n\t\t(connect_pads (clearance 0.3))\n\t\t(min_thickness 0.2)\n'
            f'\t\t(fill (thermal_gap 0.3) (thermal_bridge_width 0.4) (island_removal_mode 0))\n'
            f'\t\t(polygon (pts (xy {x0} {y0}) (xy {x1} {y0}) (xy {x1} {y1}) (xy {x0} {y1})))\n\t)')
end = t.rfind('\t(embedded_fonts')
t = t[:end] + plane('GND', 'In1.Cu', 'GND plane In1') + '\n' + plane('/Mainboard_USB/+5V', 'In2.Cu', '+5V plane In2') + '\n' + t[end:]
open(path, 'w').write(t)
print('to4layer_mbusb: 4 layers, In1 GND plane, In2 +5V plane')
