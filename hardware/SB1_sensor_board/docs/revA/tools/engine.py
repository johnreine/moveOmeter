"""Tiny schematic engine (copied from TB1 for SB1, 2026-10-25): places library symbols, connects every pin via a short stub
ending in a label or power symbol, and emits KiCad 8 .kicad_sch files."""
import math
import uuid as _uuid
from symlib import q, fnt, G

NS = _uuid.UUID('2c7e1d94-5a3b-4f60-8e2d-0b9a7c41d5e3')   # SB1 (TB1 uses its own)
PROJECT = 'moveOmeter_SB1'
POWER_NETS = {'GND', '+3V3'}
LIB = 'SB1'


def uid(*parts):
    return str(_uuid.uuid5(NS, '/'.join(str(p) for p in parts)))


def snap(v, g=1.27):
    return round(round(v / g) * g, 3)


class Part:
    def __init__(self, sym, ref, value, x, y, rot, nets, fp=None, mpn='', mfr='', dnp=False, note='', sheet=None, bom=True):
        self.sym, self.ref, self.value = sym, ref, value
        self.x, self.y, self.rot = snap(x, 2.54), snap(y, 2.54), rot
        self.nets = {str(k): v for k, v in nets.items()}
        self.fp = fp if fp is not None else sym.footprint
        self.mpn, self.mfr, self.dnp, self.note, self.sheet, self.bom = mpn, mfr, dnp, note, sheet, bom
        self.datasheet = '~'      # filled by vendor.apply()
        self.fields = {}          # extra symbol fields, in order (Vendor Part #, Price, Vendor Link, ...)
        self.extras = []          # parts ordered with this one but not on the schematic: (mpn, mfr, qty)

    def xf(self, lx, ly):
        a = math.radians(self.rot)
        xr = lx * math.cos(a) - ly * math.sin(a)
        yr = lx * math.sin(a) + ly * math.cos(a)
        return snap(self.x + xr), snap(self.y - yr)

    def pin_end(self, pin):
        return self.xf(pin.x, pin.y)

    def pin_out(self, pin):
        a = math.radians(pin.ang + 180 + self.rot)
        return round(math.cos(a)), round(-math.sin(a))


class Sheet:
    def __init__(self, design, name, file, title, paper='A3', page=2):
        self.d, self.name, self.file, self.title, self.paper, self.page = design, name, file, title, paper, page
        self.parts, self.texts, self.rects = [], [], []
        self.uuid_sheetsym = uid('sheetsym', file)
        self.uuid_file = uid('file', file)

    def add(self, symname, value, x, y, nets, rot=0, ref=None, **kw):
        sym = self.d.lib[symname]
        if ref is None:
            ref = self.d.next_ref(sym.ref)
        p = Part(sym, ref, value, x, y, rot, nets, sheet=self, **kw)
        missing = [pp.num for pp in sym.pins if pp.num not in p.nets]
        extra = [k for k in p.nets if k not in {pp.num for pp in sym.pins}]
        if missing or extra:
            raise ValueError(f'{ref} {symname}: missing pins {missing}, unknown pins {extra}')
        self.parts.append(p)
        self.d.parts.append(p)
        return p

    def text(self, s, x, y, size=1.27, bold=False):
        self.texts.append((s, snap(x), snap(y), size, bold))

    def frame(self, x1, y1, x2, y2, title=None):
        self.rects.append((snap(x1), snap(y1), snap(x2), snap(y2)))
        if title:
            self.text(title, x1 + 1.27, y1 + 3.81, 2.0, True)


class Design:
    def __init__(self, lib):
        self.lib = lib
        self.sheets, self.parts = [], []
        self.counters = {}
        self.root_uuid = uid('root')
        self.pwr_count = 0

    def sheet(self, name, file, title, paper='A3'):
        s = Sheet(self, name, file, title, paper, page=len(self.sheets) + 2)
        self.sheets.append(s)
        return s

    def next_ref(self, prefix):
        self.counters[prefix] = self.counters.get(prefix, 0) + 1
        return f'{prefix}{self.counters[prefix]}'

    # ------------------------------------------------------------------ netlist
    def netlist(self):
        nets = {}
        for p in self.parts:
            for pin in p.sym.pins:
                n = p.nets[pin.num]
                if n == 'NC':
                    continue
                nets.setdefault(n, []).append((p.ref, pin.num, pin.name, p.sheet.name))
        return nets

    def net_sheets(self):
        out = {}
        for n, conns in self.netlist().items():
            out[n] = {c[3] for c in conns}
        return out

    # ------------------------------------------------------------------ emit
    def lib_symbols(self, names):
        return '(lib_symbols ' + ' '.join(self.lib[n].sexpr(LIB) for n in sorted(names)) + ')'

    def title_block(self, title, sheetname):
        return (f'(title_block (title {q(title)}) (date "2026-10-25") (rev "A") (company "Still Kicking / moveOmeter") '
                f'(comment 1 {q("Sensor board SB1 - " + sheetname)}) (comment 2 "Generated draft: verify pinouts marked VERIFY before ordering"))')

    def emit_sheet(self, sh):
        gl = self.net_sheets()
        path = f'/{self.root_uuid}/{sh.uuid_sheetsym}'
        out = [f'(kicad_sch (version 20231120) (generator "eeschema") (generator_version "8.0") (uuid {q(sh.uuid_file)}) (paper {q(sh.paper)})',
               self.title_block(sh.title, sh.name)]
        used = {p.sym.name for p in sh.parts}
        extra_syms = set()
        body = []
        for p in sh.parts:
            body.append(self.emit_part(p, path))
            for pin in p.sym.pins:
                net = p.nets[pin.num]
                ex, ey = p.pin_end(pin)
                if net == 'NC':
                    body.append(f'(no_connect (at {ex:g} {ey:g}) (uuid {q(uid("nc", p.ref, pin.num))}))')
                    continue
                dx, dy = p.pin_out(pin)
                sx, sy = snap(ex + dx * G), snap(ey + dy * G)
                body.append(f'(wire (pts (xy {ex:g} {ey:g}) (xy {sx:g} {sy:g})) (stroke (width 0) (type default)) (uuid {q(uid("w", p.ref, pin.num))}))')
                if net in POWER_NETS:
                    extra_syms.add(net)
                    body.append(self.emit_power(net, sx, sy, dx, dy, path, f'{p.ref}.{pin.num}'))
                else:
                    body.append(self.emit_label(net, sx, sy, dx, dy, len(gl.get(net, ())) > 1, f'{p.ref}.{pin.num}'))
        for (s, x, y, size, bold) in sh.texts:
            b = ' (bold yes)' if bold else ''
            body.append(f'(text {q(s)} (exclude_from_sim no) (at {x:g} {y:g} 0) (effects (font (size {size} {size}){b}) (justify left bottom)) (uuid {q(uid("t", sh.file, s, x, y))}))')
        for (x1, y1, x2, y2) in sh.rects:
            body.append(f'(rectangle (start {x1:g} {y1:g}) (end {x2:g} {y2:g}) (stroke (width 0.254) (type dash)) (fill (type none)) (uuid {q(uid("r", sh.file, x1, y1))}))')
        out.append(self.lib_symbols(used | extra_syms))
        out.extend(body)
        out.append(')')
        return '\n'.join(out)

    def emit_part(self, p, path):
        s = p.sym
        # field placement
        if len(s.pins) == 2 and not s.power and abs(s.pins[0].x) < 0.01:
            if p.rot % 180 == 0:
                rx, ry, vx, vy, just = p.x + 2.54, p.y - 0.635, p.x + 2.54, p.y + 1.905, 'left'
            else:
                rx, ry, vx, vy, just = p.x, p.y - 3.175, p.x, p.y + 4.445, ''
        else:
            lrx, lry, _ = s.ref_at
            lvx, lvy, _ = s.val_at
            rx, ry = p.xf(lrx, lry)
            vx, vy = p.xf(lvx, lvy)
            just = 'left'
        j = f' (justify {just})' if just else ''
        hide_ref = ' hide' if s.power else ''
        props = [
            f'(property "Reference" {q(p.ref)} (at {rx:g} {ry:g} 0) (effects (font (size 1.27 1.27)){j}{hide_ref}))',
            f'(property "Value" {q(p.value)} (at {vx:g} {vy:g} 0) (effects (font (size 1.27 1.27)){j}))',
            f'(property "Footprint" {q(p.fp)} (at {p.x:g} {p.y:g} 0) {fnt(1.27, " hide")})',
            f'(property "Datasheet" {q(p.datasheet)} (at {p.x:g} {p.y:g} 0) {fnt(1.27, " hide")})',
            f'(property "Description" {q(s.desc)} (at {p.x:g} {p.y:g} 0) {fnt(1.27, " hide")})',
        ]
        if not s.power:
            props.append(f'(property "MPN" {q(p.mpn)} (at {p.x:g} {p.y:g} 0) {fnt(1.27, " hide")})')
            props.append(f'(property "Manufacturer" {q(p.mfr)} (at {p.x:g} {p.y:g} 0) {fnt(1.27, " hide")})')
            for fk, fv in p.fields.items():
                props.append(f'(property {q(fk)} {q(fv)} (at {p.x:g} {p.y:g} 0) {fnt(1.27, " hide")})')
            if p.note:
                props.append(f'(property "Note" {q(p.note)} (at {p.x:g} {p.y:g} 0) {fnt(1.27, " hide")})')
        pins = ' '.join(f'(pin {q(pp.num)} (uuid {q(uid("pin", p.ref, pp.num))}))' for pp in s.pins)
        inbom = 'yes' if (s.in_bom and p.bom) else 'no'
        return (f'(symbol (lib_id {q(LIB + ":" + s.name)}) (at {p.x:g} {p.y:g} {p.rot}) (unit 1) '
                f'(exclude_from_sim no) (in_bom {inbom}) (on_board {"yes" if s.on_board else "no"}) (dnp {"yes" if p.dnp else "no"}) '
                f'(uuid {q(uid("sym", p.ref))}) ' + ' '.join(props) + f' {pins} '
                f'(instances (project {q(PROJECT)} (path {q(path)} (reference {q(p.ref)}) (unit 1)))))')

    def emit_power(self, net, x, y, dx, dy, path, key):
        self.pwr_count += 1
        ref = f'#PWR{self.pwr_count:03d}'
        if net == 'GND':
            rot = {(0, 1): 0, (0, -1): 180, (1, 0): 90, (-1, 0): 270}[(dx, dy)]
        else:
            rot = {(0, -1): 0, (0, 1): 180, (-1, 0): 90, (1, 0): 270}[(dx, dy)]
        s = self.lib[net]
        vx, vy = x + (3.81 if net != 'GND' else 0) * 0, y
        # value text offset along the outward direction
        off = 4.445 if net != 'GND' else 4.445
        vx, vy = snap(x + dx * off), snap(y + dy * off)
        return (f'(symbol (lib_id {q(LIB + ":" + net)}) (at {x:g} {y:g} {rot}) (unit 1) (exclude_from_sim no) (in_bom no) (on_board no) (dnp no) '
                f'(uuid {q(uid("pwr", key))}) '
                f'(property "Reference" {q(ref)} (at {x:g} {y:g} 0) {fnt(1.27, " hide")}) '
                f'(property "Value" {q(net)} (at {vx:g} {vy:g} 0) {fnt(1.0)}) '
                f'(property "Footprint" "" (at {x:g} {y:g} 0) {fnt(1.27, " hide")}) '
                f'(property "Datasheet" "" (at {x:g} {y:g} 0) {fnt(1.27, " hide")}) '
                f'(property "Description" "" (at {x:g} {y:g} 0) {fnt(1.27, " hide")}) '
                f'(pin "1" (uuid {q(uid("pwrpin", key))})) '
                f'(instances (project {q(PROJECT)} (path {q(path)} (reference {q(ref)}) (unit 1)))))')

    def emit_label(self, net, x, y, dx, dy, is_global, key):
        ang = {(1, 0): 0, (0, -1): 0, (-1, 0): 180, (0, 1): 0}[(dx, dy)]
        just = 'left' if ang == 0 else 'right'
        if is_global:
            return (f'(global_label {q(net)} (shape bidirectional) (at {x:g} {y:g} {ang}) (fields_autoplaced yes) '
                    f'(effects (font (size 1.27 1.27)) (justify {just})) (uuid {q(uid("gl", key))}) '
                    f'(property "Intersheetrefs" "${{INTERSHEET_REFS}}" (at {x:g} {y:g} 0) (effects (font (size 1.27 1.27)) (justify {just}) hide)))')
        return (f'(label {q(net)} (at {x:g} {y:g} {ang}) (fields_autoplaced yes) '
                f'(effects (font (size 1.27 1.27)) (justify {just} bottom)) (uuid {q(uid("lb", key))}))')

    def emit_root(self, title):
        out = [f'(kicad_sch (version 20231120) (generator "eeschema") (generator_version "8.0") (uuid {q(self.root_uuid)}) (paper "A3")',
               self.title_block(title, 'Top'), '(lib_symbols)']
        x0, y0 = 30.48, 40.64
        for i, sh in enumerate(self.sheets):
            col, row = i % 3, i // 3
            x = x0 + col * 127
            y = y0 + row * 76.2
            w, h = 101.6, 50.8
            out.append(f'(sheet (at {x:g} {y:g}) (size {w:g} {h:g}) (fields_autoplaced yes) (stroke (width 0.1524) (type solid)) '
                       f'(fill (color 0 0 0 0.0000)) (uuid {q(sh.uuid_sheetsym)}) '
                       f'(property "Sheetname" {q(sh.name)} (at {x:g} {y - 0.7112:g} 0) (effects (font (size 1.524 1.524)) (justify left bottom))) '
                       f'(property "Sheetfile" {q(sh.file)} (at {x:g} {y + h + 0.5888:g} 0) (effects (font (size 1.27 1.27)) (justify left top))) '
                       f'(instances (project {q(PROJECT)} (path {q("/" + self.root_uuid)} (page {q(str(sh.page))})))))')
        notes = ['moveOmeter sensor board SB1: LD6004 + LD2450, USB-C per sensor, ribbon to the mainboard (rev A, generated 2026-10-25)',
                 'Sub-sheets connect through global labels; power rails through power symbols.',
                 'Everything marked VERIFY in field "Note" or in the plan doc must be checked before ordering.']
        for i, n in enumerate(notes):
            out.append(f'(text {q(n)} (exclude_from_sim no) (at 30.48 {200 + i * 6:g} 0) (effects (font (size {2.0 if i == 0 else 1.5} {2.0 if i == 0 else 1.5})) (justify left bottom)) (uuid {q(uid("roottext", i))}))')
        out.append('(sheet_instances (path "/" (page "1")))')
        out.append(')')
        return '\n'.join(out)
