"""Mainboard-USB project footprints (2026-10-31): writes them into lib/MBUSB.pretty.

- Adafruit_VEML7700_Breakout_Socket_1x05 (John, 10/31: the bench light sensor is Adafruit's breakout, on Mainboard-USB):
  Adafruit 4162 (STEMMA QT version, 25.4 x 17.78 mm, chamfered corners) on a 1x5 2.54 mm socket (Sullins PPTC051LFBN-RC,
  8.5 mm), component side out. From Adafruit's board files (Adafruit-VEML7700-PCB, "Adafruit VEML7700 STEMMA QT.brd"):
  header JP2 1 VIN, 2 3Vo, 3 GND, 4 SCL, 5 SDA, 6.35 mm below the board centre; VEML7700 4.83 mm above it; four 2.5 mm
  holes at +/-10.16, +/-6.35. Origin = breakout centre; seen from the front at 0 deg with the header row at the bottom,
  pin 1 is at the left.
- CP2102_Stick_Socket_1x05_P2.54mm_Horizontal (John, 11/01): a right-angle 1x5 female socket (Sullins PPTC051LGBN-RC,
  same land pattern as KiCad's PinSocket_1x05_P2.54mm_Horizontal) for John's CP2102 USB-TTL sticks (USB-A plug, right-angle
  male pins 3V3 / TXD / RXD / GND / +5V, ~15 x 21 mm PCB, 41-45 mm with the plug). The stick plugs in chip side down and
  rests on its header plastic, which puts its pins at the socket's height (1.27 mm). Stored y-mirrored so that, on the back at
  0 deg with the stick hanging toward +y (front view), pin 1 is at the left in front view (the right seen from behind), which
  is where a chip-side-down stick has its 3V3 pin. The stick's outline (PCB solid, plug dashed) is on the silk and in the
  courtyard so nothing goes under it.
usage: mkfp_mbusb.py <lib/MBUSB.pretty>
"""
import os, sys, uuid

OUT = sys.argv[1]
NS = uuid.UUID('4e7a1c2d-9b3f-4a10-8c5e-2d6f0b1a7c93')
os.makedirs(OUT, exist_ok=True)


def U(*k):
    return str(uuid.uuid5(NS, '|'.join(map(str, k))))


def line(x1, y1, x2, y2, layer, w, k):
    return (f'\t(fp_line (start {x1:g} {y1:g}) (end {x2:g} {y2:g}) (stroke (width {w:g}) (type solid)) '
            f'(layer "{layer}") (uuid "{U(k)}"))')


def rect(x1, y1, x2, y2, layer, w, k):
    return [line(x1, y1, x2, y1, layer, w, k + 'a'), line(x2, y1, x2, y2, layer, w, k + 'b'),
            line(x2, y2, x1, y2, layer, w, k + 'c'), line(x1, y2, x1, y1, layer, w, k + 'd')]


def circle(cx, cy, r, layer, w, k):
    return (f'\t(fp_circle (center {cx:g} {cy:g}) (end {cx + r:g} {cy:g}) (stroke (width {w:g}) (type solid)) '
            f'(fill no) (layer "{layer}") (uuid "{U(k)}"))')


def prop(name, val, x, y, layer, hide, k, size=1.0):
    h = ' (hide yes)' if hide else ''
    return (f'\t(property "{name}" "{val}" (at {x:g} {y:g} 0) (unlocked yes) (layer "{layer}"){h} (uuid "{U(k)}") '
            f'(effects (font (size {size:g} {size:g}) (thickness {size * 0.15:g}))))')


MODEL = '''	(model "${{KIPRJMOD}}/3dmodels/{}"
		(offset (xyz 0 0 0))
		(scale (xyz 1 1 1))
		(rotate (xyz 0 0 0))
	)'''


def header(name, descr, tags, attr):
    return [f'(footprint "{name}"', '\t(version 20260206)', '\t(generator "sb1_mkfp")', '\t(generator_version "1.0")',
            '\t(layer "F.Cu")', f'\t(descr "{descr}")', f'\t(tags "{tags}")']


# ---------------------------------------------------------------- Adafruit 4162 VEML7700 breakout on a 1x5 socket
name = 'Adafruit_VEML7700_Breakout_Socket_1x05'
BW2, BH2, CH = 12.7, 8.89, 2.54            # half width, half height, corner chamfer
ROW = 6.35                                  # header row below the centre
o = header(name, 'Adafruit 4162 VEML7700 lux sensor breakout (STEMMA QT version, 25.4 x 17.78 mm) on a 1x5 2.54 mm socket, '
           'component side facing out. Pins 1 VIN, 2 3Vo, 3 GND, 4 SCL, 5 SDA (Adafruit board files). Breakout top ~12.6 mm '
           'off the board with an 8.5 mm socket', 'Adafruit 4162 VEML7700 breakout socket', '')
o += [prop('Reference', 'REF**', -BW2 + 2.0, ROW + 1.7, 'F.SilkS', False, 'bref'),
      prop('Value', name, 0, -BH2 - 1.0, 'F.Fab', False, 'bval', 0.8),
      prop('Footprint', '', 0, 0, 'F.Fab', True, 'bfp'),
      prop('Datasheet', 'https://learn.adafruit.com/adafruit-veml7700', 0, 0, 'F.Fab', True, 'bds'),
      prop('Description', 'Adafruit 4162 VEML7700 breakout on a 1x5 socket', 0, 0, 'F.Fab', True, 'bdesc'),
      '\t(attr through_hole)']
pts = [(-BW2 + CH, -BH2), (BW2 - CH, -BH2), (BW2, -BH2 + CH), (BW2, BH2 - CH), (BW2 - CH, BH2), (-BW2 + CH, BH2),
       (-BW2, BH2 - CH), (-BW2, -BH2 + CH)]
for i in range(8):
    a, b = pts[i], pts[(i + 1) % 8]
    o.append(line(a[0], a[1], b[0], b[1], 'F.Fab', 0.1, f'bo{i}'))
for i, (hx, hy) in enumerate(((-10.16, -6.35), (10.16, -6.35), (-10.16, 6.35), (10.16, 6.35))):
    o.append(circle(hx, hy, 1.25, 'F.Fab', 0.1, f'bh{i}'))
o += rect(-3.4, -4.83 - 1.5, 3.4, -4.83 + 1.5, 'F.Fab', 0.1, 'bic')
o.append(f'\t(fp_text user "VEML7700 faces out" (at 0 -1.2 0) (unlocked yes) (layer "F.Fab") (uuid "{U("btx1")}") '
         f'(effects (font (size 0.6 0.6) (thickness 0.09))))')
o.append(f'\t(fp_text user "1 VIN 2 3Vo 3 GND 4 SCL 5 SDA" (at 0 {ROW - 2.2:g} 0) (unlocked yes) (layer "F.Fab") '
         f'(uuid "{U("btx2")}") (effects (font (size 0.5 0.5) (thickness 0.08))))')
o += rect(-6.41, ROW - 1.33, 6.41, ROW + 1.33, 'F.SilkS', 0.12, 'bsk')
o.append(line(-6.9, ROW - 1.33, -6.9, ROW + 1.33, 'F.SilkS', 0.12, 'bp1'))
o.append(f'\t(fp_text user "LUX" (at 8.2 {ROW:g} 0) (unlocked yes) (layer "F.SilkS") (uuid "{U("btx3")}") '
         f'(effects (font (size 0.8 0.8) (thickness 0.12))))')
# 11/13: courtyard round the socket row only (as TB1 does for the socketed DevKit). The breakout sits ~11 mm up, so the
# back sockets' pin stubs under it are fine; a whole-breakout courtyard made DRC flag them. Outline stays on F.Fab.
o += rect(-6.66, ROW - 1.58, 6.66, ROW + 1.58, 'F.CrtYd', 0.05, 'bcy')
for i in range(5):
    shape = 'rect' if i == 0 else 'circle'
    o.append(f'\t(pad "{i + 1}" thru_hole {shape} (at {-5.08 + 2.54 * i:g} {ROW:g}) (size 1.7 1.7) (drill 1) '
             f'(layers "*.Cu" "*.Mask") (remove_unused_layers no) (uuid "{U("bpad", i)}"))')
o += ['\t(embedded_fonts no)', MODEL.format('MBUSB_Adafruit_4162_VEML7700_on_socket.wrl'), ')']
open(os.path.join(OUT, name + '.kicad_mod'), 'w').write('\n'.join(o) + '\n')
print('wrote', name, 'to', OUT)


# ---------------------------------------------------------------- right-angle socket + CP2102 stick (John, 11/01)
name = 'CP2102_Stick_Socket_1x05_P2.54mm_Horizontal'
FACE, SW, SL, PLUG = 9.97, 16.0, 21.0, 22.0       # socket mouth; stick PCB width / length; plug beyond the PCB
XC = 5.08                                         # stick centred on pin 3
o = header(name, 'Right-angle 1x5 2.54 mm female socket (Sullins PPTC051LGBN-RC) for a CP2102 USB-TTL stick (USB-A, right-'
           'angle pins 3V3, TXD, RXD, GND, +5V) plugged in chip side down, lying on the board; outline of the stick on silk',
           'CP2102 USB TTL socket right angle', '')
o += [prop('Reference', 'REF**', XC, FACE + 3.0, 'F.SilkS', False, 'sref'),
      prop('Value', name, XC, FACE + SL + 2.0, 'F.Fab', False, 'sval', 0.8),
      prop('Footprint', '', 0, 0, 'F.Fab', True, 'sfp'),
      prop('Datasheet', 'https://www.digikey.com/en/products/detail/sullins-connector-solutions/PPTC051LGBN-RC/775899', 0, 0, 'F.Fab', True, 'sds'),
      prop('Description', 'Right-angle 1x5 socket for a CP2102 stick', 0, 0, 'F.Fab', True, 'sdesc'),
      '\t(attr through_hole)']
o += rect(-1.27, 1.46, 11.43, FACE, 'F.Fab', 0.1, 'sbody') + rect(-1.38, 1.35, 11.54, FACE + 0.11, 'F.SilkS', 0.12, 'sbsk')
o.append(line(-1.9, -1.0, -1.9, 1.0, 'F.SilkS', 0.12, 'sp1'))                      # pin-1 tick
# stick PCB: its sides only, stopped 0.3 mm inside Mainboard-USB's bottom edge (the stick and its plug hang past it;
# 11/13, silk past the edge drew DRC warnings). The full outline stays on F.Fab.
EDGE = 26.67                                       # socket row (y 94) to the board edge (y 121), less 0.33 mm
o += rect(XC - SW / 2, FACE, XC + SW / 2, FACE + SL, 'F.Fab', 0.1, 'stkf')
o += [line(XC - SW / 2, FACE, XC + SW / 2, FACE, 'F.SilkS', 0.12, 'stk0'),
      line(XC - SW / 2, FACE, XC - SW / 2, EDGE, 'F.SilkS', 0.12, 'stk1'),
      line(XC + SW / 2, FACE, XC + SW / 2, EDGE, 'F.SilkS', 0.12, 'stk2')]
for i in range(int(PLUG // 2)):                                                    # plug, dashed
    y0 = FACE + SL + 2 * i
    o.append(line(XC - 6.0, y0, XC - 6.0, y0 + 1.0, 'F.Fab', 0.1, f'pl{i}'))
    o.append(line(XC + 6.0, y0, XC + 6.0, y0 + 1.0, 'F.Fab', 0.1, f'pr{i}'))
o.append(f'\t(fp_text user "CHIP SIDE DOWN" (at {XC:g} {FACE + 8:g} 0) (unlocked yes) (layer "F.SilkS") '   # fits the 16 mm stick (11/13)
         f'(uuid "{U("stx1")}") (effects (font (size 0.9 0.9) (thickness 0.14))))')
o.append(f'\t(fp_text user "USB plug past the edge" (at {XC:g} {FACE + SL + 4:g} 0) (unlocked yes) (layer "F.Fab") '
         f'(uuid "{U("stx2")}") (effects (font (size 0.7 0.7) (thickness 0.1))))')
o += rect(-1.8, -1.8, 11.96, FACE + 0.5, 'F.CrtYd', 0.05, 'scy1') + rect(XC - SW / 2 - 0.25, FACE + 0.5, XC + SW / 2 + 0.25, FACE + SL + 0.25, 'F.CrtYd', 0.05, 'scy2')
for i in range(5):
    shape = 'rect' if i == 0 else 'oval'
    o.append(f'\t(pad "{i + 1}" thru_hole {shape} (at {2.54 * i:g} 0) (size 1.7 1.7) (drill 1) '
             f'(layers "*.Cu" "*.Mask") (remove_unused_layers no) (uuid "{U("spad", i)}"))')
o += ['\t(embedded_fonts no)', '''	(model "${KICAD10_3DMODEL_DIR}/Connector_PinSocket_2.54mm.3dshapes/PinSocket_1x05_P2.54mm_Horizontal.step"
		(offset (xyz 0 0 0))
		(scale (xyz 1 1 1))
		(rotate (xyz 0 0 90))
	)''', ')']
# KiCad's socket model has its pins along -y (model frame) and the body toward -x. Turned +90 deg its pins lie on our
# pad row (pin 1 at 0) with the body on the stick side. (Until 11/13 it was -90 deg + 10.16 mm, which John found in the
# 3D viewer put the body 180 deg off, over the board instead of toward the stick.)
# drawn above with the stick at +y; the footprint is only used on the back, where flipping mirrors local y, so store it
# mirrored: on the back at 0 deg the stick then hangs toward +y (front view) with pin 1 at the left.
import re as _re
o = [_re.sub(r'\((at|start|end) ([-\d.]+) ([-\d.]+)', lambda m: f'({m.group(1)} {m.group(2)} {-float(m.group(3)) + 0.0:g}', l) for l in o]
open(os.path.join(OUT, name + '.kicad_mod'), 'w').write('\n'.join(o) + '\n')
print('wrote', name, 'to', OUT)
