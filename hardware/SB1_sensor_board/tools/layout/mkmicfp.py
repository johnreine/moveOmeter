"""Footprint for an Adafruit I2S MEMS mic breakout plugged into SB1 (2026-10-26), KiCad 10 format.

Fits both Adafruit breakouts, which share the board outline, header and port position:
  - 6049: ICS-43434 (TDK), mic on the component side, sound hole through to the other side.
  - 3421: SPH0645LM4H (Knowles), mic on the other side, sound hole through to the component side.
Source: Adafruit's EagleCAD files (github.com/adafruit/Adafruit-I2S-MEMS-Microphone-Breakout-PCB for 6049,
github.com/adafruit/Adafruit-I2S-Microphone-Breakout-PCB for 3421), read 2026-10-26:
  board 16.51 x 12.7 mm (0.65 x 0.5 in), corner radius 2.54; 1x6 0.1 in header 2.54 mm from one long edge, centred;
  pins 1 VDD (3V), 2 GND, 3 BCLK, 4 DATA (DOUT), 5 WS (LRCL), 6 SEL; sound hole centred, 5.28 mm from the header row;
  two 2.5 mm plated holes 7.62 mm from the header row, 11.43 mm apart.
Seen from the sound-hole side, pin 1 is at the right on both boards (6049: pin 1 left in top view, mic on top;
3421: header and mic on the bottom layer, pin 1 right in top view).

How it mounts on SB1 (John, 10/31): on SB1's BACK at the top edge, soldered flat, no socket. The breakout lies
directly against SB1's back with its sound-hole side toward SB1 (the 6049's parts face the wall); the 1x6 header
pins, plastic slid off, go through both boards and are soldered on the outside faces. The header row sits near SB1's
top edge and the breakout overhangs that edge, so its sound hole (past the edge) faces the room with open air in front
of it. It stands about 2.6 mm off SB1's back (1.6 mm board + ~1 mm parts), under the 3 mm limit of the back side
strips where the other board of the V comes close. (Earlier: an 8.5 mm socket on the front, then soldered on the front.)
The footprint goes on B.Cu; it is drawn mirrored (breakout toward +y) so that, flipped, the breakout points up past
the top edge and pin 1 (3V) is at the right seen from the front, as before.

Drawn as seen from SB1's front with the breakout extending up (-y) from the header row; origin = header centre.
usage: mkmicfp.py <out .pretty dir>
"""
import sys, uuid, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sx
from sx import Q

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
NAME = 'Adafruit_I2S_Mic_Breakout_1x06_Overhang_Back'
NS = uuid.UUID('5b2e9c71-0d4a-4f3e-9a86-1c7d2e4b6f19')

P = 2.54                          # header pitch
BW, BH, BR = 16.51, 12.7, 2.54    # breakout outline and corner radius
ROW_FROM_EDGE = 2.54              # header row to the near long edge
PORT_Y = -(7.822 - 2.54)          # sound hole, 5.282 mm from the row (Adafruit .brd: IC1 port pad at y 7.822)
HOLE_X, HOLE_Y, HOLE_D = 5.715, -7.62, 2.5
STACK_H = 2.6                     # height off SB1's back: 1.6 mm board + ~1 mm parts (no header plastic)


def U(*k):
    return ['uuid', Q(str(uuid.uuid5(NS, '|'.join(map(str, k)))))]


def n(v):
    v = round(float(v), 4)
    return int(v) if v == int(v) else v


body = ['footprint', Q(NAME), ['version', 20260206], ['generator', Q('sb1_gen')], ['generator_version', Q('2.0')],
        ['layer', Q('F.Cu')],
        ['descr', Q('Adafruit I2S MEMS mic breakout (6049 ICS-43434) on the BACK at the board edge, flat against the board, '
                    'header pins through both, overhanging the edge, sound-hole side toward the board.'
                    ' Place on B.Cu (drawn mirrored).'
                    ' Pins 1 3V, 2 GND, 3 BCLK, 4 DOUT, '
                    '5 LRCL, 6 SEL (from Adafruit\'s board files). F.Fab and the courtyard show the whole breakout, '
                    'which reaches 8.2 mm past the board edge when the header row is 2 mm in. ~2.6 mm off the board.')],
        ['tags', Q('Adafruit 6049 3421 ICS-43434 SPH0645 I2S MEMS microphone breakout overhang')]]
k = [0]


def key():
    k[0] += 1
    return U(NAME, k[0])


def prop(name, value, x, y, layer, hide=False, size=1.0):
    p = ['property', Q(name), Q(value), ['at', n(x), n(y), 0], ['layer', Q(layer)]]
    if hide:
        p.append(['hide', 'yes'])
    p += [key(), ['effects', ['font', ['size', size, size], ['thickness', round(size * 0.15, 3)]]]]
    body.append(p)


def text(s, x, y, layer, size=0.7):
    body.append(['fp_text', 'user', Q(s), ['at', n(x), n(y)], ['layer', Q(layer)], key(),
                 ['effects', ['font', ['size', size, size], ['thickness', round(max(0.1, size * 0.15), 3)]]]])


def line(a, b, layer, w):
    body.append(['fp_line', ['start', n(a[0]), n(a[1])], ['end', n(b[0]), n(b[1])],
                 ['stroke', ['width', w], ['type', 'solid']], ['layer', Q(layer)], key()])


def arc(s, m, e, layer, w):
    body.append(['fp_arc', ['start', n(s[0]), n(s[1])], ['mid', n(m[0]), n(m[1])], ['end', n(e[0]), n(e[1])],
                 ['stroke', ['width', w], ['type', 'solid']], ['layer', Q(layer)], key()])


def circle(c, r, layer, w):
    body.append(['fp_circle', ['center', n(c[0]), n(c[1])], ['end', n(c[0] + r), n(c[1])],
                 ['stroke', ['width', w], ['type', 'solid']], ['fill', 'no'], ['layer', Q(layer)], key()])


def rect(x0, y0, x1, y1, layer, w):
    body.append(['fp_rect', ['start', n(x0), n(y0)], ['end', n(x1), n(y1)],
                 ['stroke', ['width', w], ['type', 'solid']], ['fill', 'no'], ['layer', Q(layer)], key()])


def rounded(x0, y0, x1, y1, r, layer, w):
    c = 0.70710678 * r
    line((x0 + r, y0), (x1 - r, y0), layer, w)
    arc((x1 - r, y0), (x1 - r + c, y0 + r - c), (x1, y0 + r), layer, w)
    line((x1, y0 + r), (x1, y1 - r), layer, w)
    arc((x1, y1 - r), (x1 - r + c, y1 - r + c), (x1 - r, y1), layer, w)
    line((x1 - r, y1), (x0 + r, y1), layer, w)
    arc((x0 + r, y1), (x0 + r - c, y1 - r + c), (x0, y1 - r), layer, w)
    line((x0, y1 - r), (x0, y0 + r), layer, w)
    arc((x0, y0 + r), (x0 + r - c, y0 + r - c), (x0 + r, y0), layer, w)


x0, x1 = -BW / 2, BW / 2
y0, y1 = ROW_FROM_EDGE - BH, ROW_FROM_EDGE         # -10.16 .. 2.54
prop('Reference', 'REF**', 0, y1 + 1.4, 'F.SilkS')
prop('Value', NAME, 0, y0 - 1.2, 'F.Fab', size=0.8)
prop('Datasheet', 'https://learn.adafruit.com/adafruit-i2s-mems-microphone-breakout/', 0, 0, 'F.Fab', hide=True)
prop('Description', 'Adafruit 6049 / 3421 I2S mic breakout soldered flat at the board edge, sound hole facing out', 0, 0, 'F.Fab',
     hide=True)
body.append(['attr', 'through_hole'])
body.append(['duplicate_pad_numbers_are_jumpers', 'no'])

# header plastic on silk, pin-1 bar at the right end
rect(-3 * P - 0.06, -1.33, 3 * P + 0.06, 1.33, 'F.SilkS', 0.12)
line((3 * P + 0.5, -1.33), (3 * P + 0.5, 1.33), 'F.SilkS', 0.12)
text('MIC', -3 * P - 1.6, 0, 'F.SilkS', 0.8)
# breakout outline, sound hole and its holes on fab
rounded(x0, y0, x1, y1, BR, 'F.Fab', 0.1)
circle((0, PORT_Y), 0.5, 'F.Fab', 0.1)
line((-1.0, PORT_Y), (1.0, PORT_Y), 'F.Fab', 0.05)
line((0, PORT_Y - 1.0), (0, PORT_Y + 1.0), 'F.Fab', 0.05)
for sx_ in (-1, 1):
    circle((sx_ * HOLE_X, HOLE_Y), HOLE_D / 2, 'F.Fab', 0.1)
rect(-3 * P, -1.27, 3 * P, 1.27, 'F.Fab', 0.1)
text('sound hole faces out', 0, PORT_Y - 1.6, 'F.Fab', 0.6)
text('1 3V  2 GND  3 BCLK  4 DOUT  5 LRCL  6 SEL', 0, -2.4, 'F.Fab', 0.5)
text(f'breakout ~{STACK_H:g} mm off the board', 0, y0 + 0.9, 'F.Fab', 0.5)
# courtyard: the whole breakout outline (part of it hangs past the board edge)
rect(x0 - 0.25, y0 - 0.25, x1 + 0.25, y1 + 0.25, 'F.CrtYd', 0.05)
# pads: pin 1 at the right as seen from the front (= from the breakout's sound-hole side)
for i in range(6):
    num = i + 1
    x = 3 * P - P / 2 - i * P
    body.append(['pad', Q(str(num)), 'thru_hole', 'rect' if num == 1 else 'circle', ['at', n(x), 0], ['size', 1.7, 1.7],
                 ['drill', 1.0], ['layers', Q('*.Cu'), Q('*.Mask')], ['remove_unused_layers', 'no'], key()])
body.append(['embedded_fonts', 'no'])
# 3D: the header pins and Adafruit's 6049 model, sound-hole side down onto the board (tools/layout/mk3d.py), 10/31
body.append(['model', Q('${KIPRJMOD}/3dmodels/SB1_Adafruit_6049_Mic_back.wrl'), ['offset', ['xyz', 0, 0, 0]],
             ['scale', ['xyz', 1, 1, 1]], ['rotate', ['xyz', 0, 0, 0]]])


def mirror_y(node):
    """draw the footprint mirrored in y (it goes on the back, where KiCad mirrors y again)"""
    for c in node:
        if isinstance(c, list):
            if c and c[0] in ('at', 'start', 'end', 'center', 'mid') and len(c) >= 3:
                c[2] = n(-float(c[2]))
            else:
                mirror_y(c)


mirror_y(body)
p = f'{OUT}/{NAME}.kicad_mod'
open(p, 'w').write(sx.dump(body) + '\n')
print('wrote', p)
