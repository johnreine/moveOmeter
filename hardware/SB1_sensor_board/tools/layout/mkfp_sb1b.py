"""SB1 rev B footprints (2026-10-31): writes them into lib/SB1.pretty.

- Vishay_VEML7700_TopView: VEML7700-TT, window facing away from the board. Land pattern from Adafruit's VEML7700
  board files (Adafruit-VEML7700-PCB, package "VEML7700"): four 0.7 x 1.6 mm pads at 1.27 mm pitch along one long
  side, 1.1 mm off the body centre; body 6.8 x 3.0 mm. The pads reach only 0.4 mm past the body: use hot air or a
  fine iron with flux.
- MountingHole_2.7mm_M2.5_KeepOut: KiCad's MountingHole_2.7mm_M2.5 (no pad) plus a 3.0 mm-radius front courtyard
  (M2.5 screw head on the room side) and a 3.3 mm-radius back courtyard (heat-set insert boss of the printed holder),
  so KiCad's courtyard check keeps parts clear on both sides.
usage: mkfp_sb1b.py <lib/SB1.pretty>
"""
import os, re, sys, uuid

OUT = sys.argv[1]
NS = uuid.UUID('6b0c2f1e-8d4a-4e3b-a1c9-3f2e7d5b9a10')


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


# ---------------------------------------------------------------- VEML7700 top view
name = 'Vishay_VEML7700_TopView'
o = header(name, 'Vishay VEML7700-TT ambient light sensor, top view (window up), 6.8 x 3.0 mm body. Land pattern from '
           'Adafruit VEML7700 board files: 4 pads 0.7 x 1.6 mm, 1.27 mm pitch, 1.1 mm off centre', 'VEML7700 light sensor I2C', '')
o += [prop('Reference', 'REF**', 0, -3.0, 'F.SilkS', False, 'vref'), prop('Value', name, 0, 2.6, 'F.Fab', False, 'vval'),
      prop('Footprint', '', 0, 0, 'F.Fab', True, 'vfp'), prop('Datasheet', 'https://www.vishay.com/docs/84286/veml7700.pdf', 0, 0, 'F.Fab', True, 'vds'),
      prop('Description', 'VEML7700-TT top view', 0, 0, 'F.Fab', True, 'vdesc'), '\t(attr smd)']
o += rect(-3.4, -1.5, 3.4, 1.5, 'F.Fab', 0.1, 'vfab')
o += [line(-3.5, -1.6, -2.45, -1.6, 'F.SilkS', 0.12, 's1'), line(2.45, -1.6, 3.5, -1.6, 'F.SilkS', 0.12, 's2'),
      line(3.5, -1.6, 3.5, 1.6, 'F.SilkS', 0.12, 's3'), line(3.5, 1.6, -3.5, 1.6, 'F.SilkS', 0.12, 's4'),
      line(-3.5, 1.6, -3.5, -1.6, 'F.SilkS', 0.12, 's5'), circle(-2.6, -2.25, 0.15, 'F.SilkS', 0.3, 'pin1dot')]
o += rect(-3.65, -2.15, 3.65, 1.75, 'F.CrtYd', 0.05, 'vcrt')
o.append(f'\t(fp_text user "${{REFERENCE}}" (at 0 0.4 0) (unlocked yes) (layer "F.Fab") (uuid "{U("vfabref")}") '
         f'(effects (font (size 0.8 0.8) (thickness 0.12))))')
for i, (n, x) in enumerate(((1, -1.905), (2, -0.635), (3, 0.635), (4, 1.905))):
    o.append(f'\t(pad "{n}" smd roundrect (at {x:g} -1.1) (size 0.7 1.6) (layers "F.Cu" "F.Mask" "F.Paste") '
             f'(roundrect_rratio 0.15) (uuid "{U("vpad", n)}"))')
o += ['\t(embedded_fonts no)', MODEL.format('SB1_VEML7700-TT.wrl'), ')']
open(os.path.join(OUT, name + '.kicad_mod'), 'w').write('\n'.join(o) + '\n')

# ---------------------------------------------------------------- M2.5 hole with front / back keep-out courtyards
name = 'MountingHole_2.7mm_M2.5_KeepOut'
o = header(name, 'M2.5 mounting hole, 2.7 mm NPTH. Screw from the front (head r 3.0 mm courtyard on F) into a heat-set '
           'insert in the printed holder behind (boss r 3.3 mm courtyard on B)', 'mounting hole M2.5 keep-out', '')
o += [prop('Reference', 'REF**', 0, -3.8, 'F.SilkS', False, 'href'), prop('Value', name, 0, 3.8, 'F.Fab', False, 'hval'),
      prop('Footprint', '', 0, 0, 'F.Fab', True, 'hfp'), prop('Datasheet', '', 0, 0, 'F.Fab', True, 'hds'),
      prop('Description', 'M2.5 hole with keep-outs', 0, 0, 'F.Fab', True, 'hdesc'), '\t(attr exclude_from_pos_files exclude_from_bom)']
o += [circle(0, 0, 2.7, 'Cmts.User', 0.15, 'hhead'), circle(0, 0, 3.0, 'F.CrtYd', 0.05, 'hcf'),
      circle(0, 0, 3.3, 'B.CrtYd', 0.05, 'hcb')]
o.append(f'\t(pad "" np_thru_hole circle (at 0 0) (size 2.7 2.7) (drill 2.7) (layers "*.Cu" "*.Mask") (uuid "{U("hpad")}"))')
o += ['\t(embedded_fonts no)', ')']
open(os.path.join(OUT, name + '.kicad_mod'), 'w').write('\n'.join(o) + '\n')

# ---------------------------------------------------------------- radar module models (10/31)
# The radar footprints (copied from TB1) already show their sockets; add the module itself:
# - LD6004: tools/layout/mkstep_ld6004.py (from Hi-Link's dimension drawing), board bottom 5.5 mm up (4.5 mm socket +
#   1.0 mm header plastic), same orientation as the footprint.
# - LD2450: Hi-Link's STEP (John, 10/31). Its header sits at +x, so it turns 180 deg; board bottom 6.3 mm up.
RADAR = (('HLK-LD6004_Module_2x1x05_P1.27mm', 'HLK-LD6004_module.step', (0, 0, 5.5), (0, 0, 0)),
         ('HLK-LD2450_Module_2x04_P2.00mm', 'Module_HLK-LD2450.step', (0, 0, 6.3), (0, 0, 180)))
OLD = re.compile(r'\t\(model "\$\{KIPRJMOD\}/3dmodels/[^"]*"\n(?:\t\t[^\n]*\n)*?\t\)\n')
for fp, model, off, rot in RADAR:
    path = os.path.join(OUT, fp + '.kicad_mod')
    txt = OLD.sub('', open(path).read()).rstrip()
    assert txt.endswith(')')
    block = (f'\t(model "${{KIPRJMOD}}/3dmodels/{model}"\n\t\t(offset (xyz {off[0]:g} {off[1]:g} {off[2]:g}))\n'
             f'\t\t(scale (xyz 1 1 1))\n\t\t(rotate (xyz {rot[0]:g} {rot[1]:g} {rot[2]:g}))\n\t)')
    open(path, 'w').write(txt[:-1].rstrip('\n') + '\n' + block + '\n)\n')

# ---------------------------------------------------------------- LD6004 orientation picture on the silk (John, 10/31)
# Both 1x5 sockets are the same, so the module fits either way round. Draw the module as it looks from the antenna
# side (same geometry as mkstep_ld6004.py): the antenna block, hatched, 8 mm from the debug end (the small parts in the
# STEP are only approximate, so they're left off), and an "ANTENNA" bracket outside the outline so it can still be checked once the
# module is in. Re-runnable: earlier copies of these items (tagged uuids) are removed first.
def ftext(t, x, y, k, size=0.8):
    return (f'\t(fp_text user "{t}" (at {x:g} {y:g}) (layer "F.SilkS") (uuid "{U(k)}") '
            f'(effects (font (size {size:g} {size:g}) (thickness {size * 0.15:g}))))')


def hatch(x0, y0, x1, y1, pitch, k):
    out, c, i = [], x0 - (y1 - y0), 0
    while c < x1:                                    # lines x - y = c - y0 at 45 deg, clipped to the box
        ax, ay = max(x0, c), y0 + max(x0, c) - c
        bx, by = min(x1, c + (y1 - y0)), y0 + min(x1, c + (y1 - y0)) - c
        if bx - ax > 0.2:
            out.append(line(round(ax, 3), round(ay, 3), round(bx, 3), round(by, 3), 'F.SilkS', 0.12, f'{k}{i}'))
        c, i = c + pitch, i + 1
    return out


ART = 'ld6004_orient'
# (the STEP's y is up, the footprint's y is down: y negated here)
art = (rect(-9.5, -2.7, 0.5, 2.9, 'F.SilkS', 0.15, ART + 'ant') + hatch(-9.5, -2.7, 0.5, 2.9, 1.0, ART + 'h')

       + [ftext('LD6004', 9.3, -0.7, ART + 't1'), ftext('antenna up', 9.3, 0.7, ART + 't2'),
          line(-9.5, -4.4, 0.5, -4.4, 'F.SilkS', 0.12, ART + 'b0'), line(-9.5, -4.4, -9.5, -3.9, 'F.SilkS', 0.12, ART + 'b1'),
          line(0.5, -4.4, 0.5, -3.9, 'F.SilkS', 0.12, ART + 'b2'), ftext('ANTENNA', -4.5, -5.2, ART + 't3')])
path = os.path.join(OUT, 'HLK-LD6004_Module_2x1x05_P1.27mm.kicad_mod')
txt = open(path).read()
tags = set(re.findall(r'uuid "([^"]+)"', '\n'.join(art + rect(0, 0, 1, 1, 'F.SilkS', 0.12, ART + 'led') + rect(0, 0, 1, 1, 'F.SilkS', 0.12, ART + 's1') + rect(0, 0, 1, 1, 'F.SilkS', 0.12, ART + 's2'))))  # incl. retired items
tags |= {U(f'{ART}h{i}') for i in range(200)}
txt = '\n'.join(l for l in txt.split('\n') if not any(t in l for t in tags))
txt = re.sub(r'\t\(fp_text user "LD6004  antenna up"\n(?:\t\t[^\n]*\n)*?\t\)\n', '', txt)  # replaced by the picture
txt = txt.replace('(property "Reference" "REF**"\n\t\t(at 0 -5.1 0)', '(property "Reference" "REF**"\n\t\t(at 9 -5.1 0)')
txt = txt.replace('(start -9.4 -2.6)\n\t\t(end 1 2.6)', '(start -9.5 -2.7)\n\t\t(end 0.5 2.9)')   # Fab antenna = drawing
txt = txt.replace('(fp_text user "AiP antenna"\n\t\t(at -4.2 0)', '(fp_text user "AiP antenna"\n\t\t(at -4.5 0)')
# 11/9 (John, option A): tracks allowed on F.Cu under the LD6004. The footprint's keep-out ("solid GND under module")
# dates from before In1 / In2 became unbroken GND planes; In1 now sits right under the module, and the strip behind the
# LD6004 (buck, LDO, TVS) had only B.Cu to route on. Removed here, re-runnably.
txt = re.sub(r'\t\(zone\n\t\t\(layer "F\.Cu"\)\n\t\t\(uuid "[^"]+"\)\n\t\t\(name "LD6004: solid GND under module"\)\n(?:\t\t[^\n]*\n)*?\t\)\n', '', txt)
txt = txt.replace('F.Cu keep-out keeps the GND pour solid under the module.', 'Tracks allowed under the module (11/9): In1 is a solid GND plane right under it.')
i = txt.index('\t(pad ')
open(path, 'w').write(txt[:i] + '\n'.join(art) + '\n' + txt[i:])

# ---------------------------------------------------------------- LD2450 orientation picture (John, 10/31)
# Same idea. Its 2x4 socket is symmetric too. Seen from the antenna side the header is at the left end and the
# antenna group at the other (white 4-pin socket) end (bench check 10/30). Hi-Link's STEP (3dmodels/, turned 180 deg
# by the footprint: footprint x = -model x, y = model y) puts the antenna-side artwork there at x 0.9-16.0,
# y -1.9-5.3 (drawn from y -1.2 so it clears the chip), and the radar chip at x -1.4-2.6, y -5.45 to -1.46. The outline with its two corner notches was already
# on the silk.
ART2 = 'ld2450_orient'
art2 = (rect(0.9, -1.2, 16.0, 5.3, 'F.SilkS', 0.15, ART2 + 'ant') + hatch(0.9, -1.2, 16.0, 5.3, 1.0, ART2 + 'h')
        + rect(-1.4, -5.45, 2.6, -1.46, 'F.SilkS', 0.12, ART2 + 'chip')
        + [ftext('LD2450', -7.5, -0.9, ART2 + 't1'), ftext('antenna up', -7.5, 0.9, ART2 + 't2'),
           line(0.9, 8.3, 16.0, 8.3, 'F.SilkS', 0.12, ART2 + 'b0'), line(0.9, 8.3, 0.9, 7.8, 'F.SilkS', 0.12, ART2 + 'b1'),
           line(16.0, 8.3, 16.0, 7.8, 'F.SilkS', 0.12, ART2 + 'b2'), ftext('ANTENNA', 8.45, 9.2, ART2 + 't3')])
path = os.path.join(OUT, 'HLK-LD2450_Module_2x04_P2.00mm.kicad_mod')
txt = open(path).read()
tags = set(re.findall(r'uuid "([^"]+)"', '\n'.join(art2)))
tags |= {U(f'{ART2}h{i}') for i in range(200)}      # every hatch line an earlier run may have left
txt = '\n'.join(l for l in txt.split('\n') if not any(t in l for t in tags))
txt = re.sub(r'\t\(fp_text user "LD2450  antenna up"\n(?:\t\t[^\n]*\n)*?\t\)\n', '', txt)
i = txt.index('\t(pad ')
open(path, 'w').write(txt[:i] + '\n'.join(art2) + '\n' + txt[i:])
print('wrote Vishay_VEML7700_TopView, MountingHole_2.7mm_M2.5_KeepOut, radar module models to', OUT)
