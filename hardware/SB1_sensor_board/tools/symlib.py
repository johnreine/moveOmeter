"""Symbol library definitions for moveOmeter SB1 (copied from TB1, 2026-10-25) (KiCad 8 s-expression format).

Coordinates: library space, mm, Y up. Pin (at x y a): connection point, a = direction
from the connection point toward the body.
"""

G = 2.54


def q(s):
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'


def fnt(size=1.27, extra=''):
    return f'(effects (font (size {size} {size})){extra})'


class Pin:
    def __init__(self, num, name, x, y, ang, typ='passive', length=G, hidden=False):
        self.num, self.name, self.x, self.y, self.ang = str(num), name, x, y, ang
        self.typ, self.length, self.hidden = typ, length, hidden

    def sexpr(self):
        h = ' hide' if self.hidden else ''
        return (f'(pin {self.typ} line (at {self.x:g} {self.y:g} {self.ang}) (length {self.length:g}){h} '
                f'(name {q(self.name)} {fnt()}) (number {q(self.num)} {fnt()}))')


class Sym:
    def __init__(self, name, ref, desc='', footprint='', pins=None, graphics=None,
                 power=False, hide_pin_names=False, hide_pin_numbers=False,
                 ref_at=(0, 0, 0), val_at=(0, 0, 0), pin_name_offset=0.508, in_bom=True, on_board=True):
        self.name, self.ref, self.desc, self.footprint = name, ref, desc, footprint
        self.pins = pins or []
        self.graphics = graphics or []
        self.power = power
        self.hide_pin_names, self.hide_pin_numbers = hide_pin_names, hide_pin_numbers
        self.ref_at, self.val_at = ref_at, val_at
        self.pin_name_offset = pin_name_offset
        self.in_bom, self.on_board = in_bom, on_board

    def pin(self, num):
        for p in self.pins:
            if p.num == str(num):
                return p
        raise KeyError(f'{self.name} has no pin {num}')

    def sexpr(self, libname=None):
        full = f'{libname}:{self.name}' if libname else self.name
        out = [f'(symbol {q(full)}']
        if self.power:
            out.append('(power)')
        if self.hide_pin_numbers:
            out.append('(pin_numbers hide)')
        pn = f'(pin_names (offset {self.pin_name_offset:g})'
        pn += ' hide)' if self.hide_pin_names else ')'
        out.append(pn)
        out.append(f'(exclude_from_sim no) (in_bom {"yes" if self.in_bom else "no"}) (on_board {"yes" if self.on_board else "no"})')
        rx, ry, ra = self.ref_at
        vx, vy, va = self.val_at
        hide_ref = ' hide' if self.power else ''
        out.append(f'(property "Reference" {q(self.ref)} (at {rx:g} {ry:g} {ra}) {fnt(1.27, hide_ref)})')
        out.append(f'(property "Value" {q(self.name)} (at {vx:g} {vy:g} {va}) {fnt()})')
        out.append(f'(property "Footprint" {q(self.footprint)} (at 0 0 0) {fnt(1.27, " hide")})')
        out.append(f'(property "Datasheet" "~" (at 0 0 0) {fnt(1.27, " hide")})')
        out.append(f'(property "Description" {q(self.desc)} (at 0 0 0) {fnt(1.27, " hide")})')
        out.append(f'(symbol {q(self.name + "_0_1")} ' + ' '.join(self.graphics) + ')')
        out.append(f'(symbol {q(self.name + "_1_1")} ' + ' '.join(p.sexpr() for p in self.pins) + ')')
        out.append(')')
        return ' '.join(out)


def rect(x1, y1, x2, y2, fill='background', w=0.254):
    return f'(rectangle (start {x1:g} {y1:g}) (end {x2:g} {y2:g}) (stroke (width {w}) (type default)) (fill (type {fill})))'


def poly(pts, fill='none', w=0.254):
    s = ' '.join(f'(xy {x:g} {y:g})' for x, y in pts)
    return f'(polyline (pts {s}) (stroke (width {w}) (type default)) (fill (type {fill})))'


def circle(cx, cy, r, fill='none', w=0.254):
    return f'(circle (center {cx:g} {cy:g}) (radius {r:g}) (stroke (width {w}) (type default)) (fill (type {fill})))'


def arc(sx, sy, mx, my, ex, ey, w=0.254):
    return f'(arc (start {sx:g} {sy:g}) (mid {mx:g} {my:g}) (end {ex:g} {ey:g}) (stroke (width {w}) (type default)) (fill (type none)))'


def text(s, x, y, size=1.27, ang=0):
    return f'(text {q(s)} (at {x:g} {y:g} {ang}) {fnt(size)})'


# ---------------------------------------------------------------- generic builders

def ic(name, left, right, width=15.24, ref='U', desc='', footprint='', top_pad=1, bottom_pad=1):
    """Rectangular IC. left/right: lists of (num, name, type) or None for a gap.
    Pins on 2.54 grid; body width multiple of 5.08."""
    n = max(len(left), len(right))
    h_rows = n + top_pad + bottom_pad - 1
    ytop = round((h_rows // 2) * G, 3)
    pins = []
    hw = width / 2
    for side, lst in (('L', left), ('R', right)):
        for i, p in enumerate(lst):
            if p is None:
                continue
            num, pname, typ = (p + ('passive',))[:3] if len(p) == 2 else p
            y = ytop - (i + top_pad) * G
            if side == 'L':
                pins.append(Pin(num, pname, -hw - G, y, 0, typ))
            else:
                pins.append(Pin(num, pname, hw + G, y, 180, typ))
    yb = ytop - (h_rows + 1) * G + G
    body = rect(-hw, ytop + G * 0.5, hw, yb - G * 0.5)
    return Sym(name, ref, desc, footprint, pins, [body],
               ref_at=(-hw, ytop + G * 0.5 + 1.27, 0), val_at=(-hw, yb - G * 0.5 - 1.27, 0))


def two_pin(name, ref, graphics, desc='', footprint='', n1='1', n2='2', names=('~', '~'), hide_names=True):
    pins = [Pin(n1, names[0], 0, 3.81, 270, 'passive', 1.27), Pin(n2, names[1], 0, -3.81, 90, 'passive', 1.27)]
    return Sym(name, ref, desc, footprint, pins, graphics, hide_pin_names=hide_names, hide_pin_numbers=True,
               ref_at=(2.54, 1.27, 0), val_at=(2.54, -1.27, 0))


def connector(name, pinnames, ref='J', desc='', footprint='', width=10.16, side='L'):
    """Single-row connector, pins on one side with names."""
    pins = []
    n = len(pinnames)
    ytop = round(((n - 1) // 2) * G, 3) if n > 1 else 0
    hw = width / 2
    for i, pn in enumerate(pinnames):
        y = ytop - i * G
        if side == 'L':
            pins.append(Pin(i + 1, pn, -hw - G, y, 0))
        else:
            pins.append(Pin(i + 1, pn, hw + G, y, 180))
    yb = ytop - (n - 1) * G
    body = rect(-hw, ytop + G * 0.5 + 0.5, hw, yb - G * 0.5 - 0.5)
    return Sym(name, ref, desc, footprint, pins, [body],
               ref_at=(-hw, ytop + G * 0.5 + 1.8, 0), val_at=(-hw, yb - G * 0.5 - 1.8, 0))


def dual_row(name, pinnames, ref='J', desc='', footprint='', width=15.24):
    """2xN header, odd pins left, even right (pinnames indexed by pin-1)."""
    n = len(pinnames) // 2
    left = [(2 * i + 1, pinnames[2 * i]) for i in range(n)]
    right = [(2 * i + 2, pinnames[2 * i + 1]) for i in range(n)]
    return ic(name, left, right, width, ref, desc, footprint, top_pad=0, bottom_pad=0)


# ---------------------------------------------------------------- library

def build_library():
    L = {}

    def add(s):
        L[s.name] = s
        return s

    # passives -----------------------------------------------------------
    add(two_pin('R', 'R', [rect(-1.016, -2.54, 1.016, 2.54, 'none')], 'Resistor'))
    add(two_pin('C', 'C', [poly([(-2.032, 0.762), (2.032, 0.762)], w=0.508),
                           poly([(-2.032, -0.762), (2.032, -0.762)], w=0.508),
                           poly([(0, 2.54), (0, 0.762)]), poly([(0, -2.54), (0, -0.762)])],
                'Unpolarized capacitor'))
    add(two_pin('CP', 'C', [rect(-2.286, 0.508, 2.286, 1.016, 'none'),
                            rect(-2.286, -0.508, 2.286, -1.016, 'outline'),
                            poly([(-1.778, 2.286), (-0.762, 2.286)]), poly([(-1.27, 2.794), (-1.27, 1.778)]),
                            poly([(0, 2.54), (0, 1.016)]), poly([(0, -2.54), (0, -1.016)])],
                'Polarized capacitor (polymer)', names=('+', '-')))
    add(two_pin('L', 'L', [arc(0, 2.54, 0.635, 1.905, 0, 1.27), arc(0, 1.27, 0.635, 0.635, 0, 0),
                           arc(0, 0, 0.635, -0.635, 0, -1.27), arc(0, -1.27, 0.635, -1.905, 0, -2.54)],
                'Inductor'))
    add(two_pin('FB', 'FB', [poly([(-1.778, -0.635), (-0.635, 1.778), (1.778, 0.635), (0.635, -1.778), (-1.778, -0.635)]),
                             poly([(0, 2.54), (0, 1.2)]), poly([(0, -2.54), (0, -1.2)])],
                'Ferrite bead'))
    add(two_pin('Fuse_PTC', 'F', [rect(-0.762, -2.54, 0.762, 2.54, 'none'), poly([(-1.524, -2.032), (-1.524, -1.27), (1.524, 1.27), (1.524, 2.032)])],
                'Resettable PTC fuse'))
    add(two_pin('Crystal', 'Y', [rect(-1.524, -0.762, 1.524, 0.762, 'none'), poly([(-1.778, 1.27), (1.778, 1.27)], w=0.508),
                                 poly([(-1.778, -1.27), (1.778, -1.27)], w=0.508), poly([(0, 2.54), (0, 1.27)]), poly([(0, -2.54), (0, -1.27)])],
                'Crystal'))
    # diodes: pin1 = K (top), pin2 = A (bottom); current flows bottom->top
    tri = [poly([(-1.27, -1.016), (1.27, -1.016), (0, 1.016), (-1.27, -1.016)], 'none'),
           poly([(-1.27, 1.016), (1.27, 1.016)]), poly([(0, 2.54), (0, -2.54)])]
    add(two_pin('D_Schottky', 'D', tri + [poly([(-1.27, 1.016), (-1.27, 0.508)]), poly([(1.27, 1.016), (1.27, 1.524)])],
                'Schottky diode', names=('K', 'A')))
    add(two_pin('D_TVS', 'D', [poly([(-1.27, 1.016), (1.27, 1.016), (0, 0), (-1.27, 1.016)]),
                               poly([(-1.27, -1.016), (1.27, -1.016), (0, 0), (-1.27, -1.016)]),
                               poly([(-1.524, 0), (1.524, 0)]), poly([(0, 2.54), (0, -2.54)])],
                'Unidirectional TVS diode', names=('K', 'A')))
    # LED: pin1 K bottom, pin2 A top (KiCad LED footprint pad1 = K)
    led_tri = [poly([(-1.27, 1.016), (1.27, 1.016), (0, -1.016), (-1.27, 1.016)], 'none'), poly([(-1.27, -1.016), (1.27, -1.016)])]
    add(two_pin('LED', 'D', led_tri + [poly([(0, 2.54), (0, -2.54)]),
                                       poly([(1.778, 0), (3.048, 0.762)]), poly([(1.778, -0.762), (3.048, 0)])],
                'LED', n1='2', n2='1', names=('A', 'K')))
    add(two_pin('SolderJumper_2', 'JP', [arc(-0.508, 0.762, 0, 1.27, 0.508, 0.762), arc(0.508, -0.762, 0, -1.27, -0.508, -0.762),
                                         poly([(-0.508, 0.762), (0.508, 0.762)]), poly([(-0.508, -0.762), (0.508, -0.762)]),
                                         poly([(0, 2.54), (0, 1.27)]), poly([(0, -2.54), (0, -1.27)])],
                'Solder jumper, open by default'))
    add(two_pin('Jumper_2', 'JP', [circle(0, 1.27, 0.508), circle(0, -1.27, 0.508),
                                   arc(1.016, 1.27, 1.524, 0, 1.016, -1.27), poly([(0, 2.54), (0, 1.778)]), poly([(0, -2.54), (0, -1.778)])],
                '2-pin header with shunt'))

    # 3-pin jumper (center = common)
    s = Sym('Jumper_3', 'JP', '3-pin header with shunt: 1-2 or 2-3', '',
            [Pin(1, 'A', -5.08, 0, 0, 'passive', 2.54), Pin(2, 'C', 0, -5.08, 90, 'passive', 2.54), Pin(3, 'B', 5.08, 0, 180, 'passive', 2.54)],
            [circle(-2.032, 0, 0.508), circle(0, 0, 0.508), circle(2.032, 0, 0.508), poly([(0, -2.54), (0, -0.508)]),
             arc(-2.54, 1.016, -1.016, 1.778, 0.508, 1.016)],
            hide_pin_names=True, hide_pin_numbers=False, ref_at=(-5.08, 3.81, 0), val_at=(-5.08, -7.62, 0))
    add(s)

    # NMOS SOT-23: 1 G, 2 S, 3 D
    add(Sym('Q_NMOS_GSD', 'Q', 'N-MOSFET, SOT-23 (G=1 S=2 D=3)', 'Package_TO_SOT_SMD:SOT-23',
            [Pin(1, 'G', -5.08, 0, 0, 'input'), Pin(3, 'D', 2.54, 5.08, 270, 'passive'), Pin(2, 'S', 2.54, -5.08, 90, 'passive')],
            [poly([(-2.54, 0), (-1.27, 0)]), poly([(-1.27, 1.905), (-1.27, -1.905)], w=0.254),
             poly([(-0.508, 2.286), (-0.508, 1.27)], w=0.3), poly([(-0.508, 0.508), (-0.508, -0.508)], w=0.3),
             poly([(-0.508, -1.27), (-0.508, -2.286)], w=0.3),
             poly([(-0.508, 1.778), (2.54, 1.778), (2.54, 2.54)]), poly([(-0.508, -1.778), (2.54, -1.778), (2.54, -2.54)]),
             poly([(-0.508, 0), (2.54, 0), (2.54, -1.778)]), circle(0.635, 0, 3.0)],
            hide_pin_names=True, hide_pin_numbers=True, ref_at=(5.08, 1.27, 0), val_at=(5.08, -1.27, 0)))

    add(Sym('TestPoint', 'TP', 'Test point loop', 'TestPoint:TestPoint_Keystone_5000-5004_Miniature',
            [Pin(1, '1', 0, 0, 90, 'passive', 0)],
            [circle(0, 1.524, 0.762), poly([(0, 0), (0, 0.762)])], hide_pin_names=True, hide_pin_numbers=True,
            ref_at=(1.524, 2.54, 0), val_at=(1.524, 0.762, 0)))
    add(Sym('MountingHole', 'H', 'M3 mounting hole, grounded', 'SB1:MountingHole_3.2mm_M3_DIN965_Pad_TopOnly_FrontMount',
            [Pin(1, '1', 0, -3.81, 90, 'passive', 1.27)], [circle(0, 0, 1.27), circle(0, 0, 2.54)],
            hide_pin_names=True, hide_pin_numbers=True, ref_at=(3.81, 1.27, 0), val_at=(3.81, -1.27, 0)))

    # power symbols -------------------------------------------------------
    def pwr_rail(name):
        return Sym(name, '#PWR', f'Power rail {name}', '',
                   [Pin(1, name, 0, 0, 90, 'power_in', 0, hidden=True)],
                   [poly([(0, 0), (0, 1.27)]), poly([(-0.762, 1.27), (0, 2.54), (0.762, 1.27), (-0.762, 1.27)], 'outline')],
                   power=True, ref_at=(0, -3.81, 0), val_at=(0, 3.556, 0), in_bom=False, on_board=False)
    for r in ['+3V3']:
        add(pwr_rail(r))
    add(Sym('GND', '#PWR', 'Ground', '', [Pin(1, 'GND', 0, 0, 270, 'power_in', 0, hidden=True)],
            [poly([(0, 0), (0, -1.27), (1.27, -1.27), (0, -2.54), (-1.27, -1.27), (0, -1.27)])],
            power=True, ref_at=(0, -6.35, 0), val_at=(0, -3.81, 0), in_bom=False, on_board=False))
    add(Sym('PWR_FLAG', '#FLG', 'Marks a net as driven (ERC)', '', [Pin(1, 'pwr', 0, 0, 90, 'power_out', 0, hidden=True)],
            [poly([(0, 0), (0, 1.27), (-1.016, 1.905), (0, 2.54), (1.016, 1.905), (0, 1.27)])],
            power=True, ref_at=(0, 1.905, 0), val_at=(0, 3.81, 0), in_bom=False, on_board=False))

    # ICs ----------------------------------------------------------------------
    add(ic('TLV62569DBV', [(4, 'VIN', 'power_in'), (1, 'EN', 'input'), None, (2, 'GND', 'power_in')],
           [(3, 'SW', 'power_out'), None, (5, 'FB', 'input')], 12.7, 'U',
           '2 A synchronous buck, SOT-23-5', 'Package_TO_SOT_SMD:SOT-23-5'))
    add(ic('TPS2051CDBV', [(5, 'IN', 'power_in'), (4, 'EN', 'input'), None, (2, 'GND', 'power_in')],
           [(1, 'OUT', 'power_out'), None, (3, '~{FLT}', 'open_collector')], 12.7, 'U',
           '0.5 A current-limited USB power switch, active-high EN, SOT-23-5', 'Package_TO_SOT_SMD:SOT-23-5'))
    add(ic('LP5907MFX-3.3', [(1, 'VIN', 'power_in'), (3, 'EN', 'input'), None, (2, 'GND', 'power_in')],
           [(5, 'VOUT', 'power_out'), None, (4, 'NC', 'no_connect')], 12.7, 'U',
           '250 mA ultra-low-noise LDO, 3.3 V, SOT-23-5', 'Package_TO_SOT_SMD:SOT-23-5'))
    add(ic('INA219AxD', [(8, 'IN+', 'input'), (7, 'IN-', 'input'), None, (1, 'A1', 'input'), (2, 'A0', 'input')],
           [(5, 'VS', 'power_in'), (3, 'SDA', 'bidirectional'), (4, 'SCL', 'input'), None, (6, 'GND', 'power_in')],
           12.7, 'U', 'I2C current/voltage monitor, SOIC-8', 'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm'))
    add(ic('74LVC1G126', [(2, 'A', 'input'), (1, 'OE', 'input')], [(5, 'VCC', 'power_in'), (4, 'Y', 'tri_state'), (3, 'GND', 'power_in')],
           10.16, 'U', 'Single buffer, 3-state, active-high OE, SOT-23-5', 'Package_TO_SOT_SMD:SOT-23-5'))
    add(ic('74LVC1G04', [(2, 'A', 'input'), (1, 'NC', 'no_connect')], [(5, 'VCC', 'power_in'), (4, 'Y', 'output'), (3, 'GND', 'power_in')],
           10.16, 'U', 'Single inverter, SOT-23-5', 'Package_TO_SOT_SMD:SOT-23-5'))
    add(ic('PMOS_SO8', [(1, 'S', 'passive'), (2, 'S', 'passive'), (3, 'S', 'passive'), None, (4, 'G', 'input')],
           [(5, 'D', 'passive'), (6, 'D', 'passive'), (7, 'D', 'passive'), (8, 'D', 'passive')], 12.7, 'Q',
           'P-channel MOSFET, SO-8 (S=1-3, G=4, D=5-8)', 'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm'))
    add(ic('SRV05-4', [(1, 'IO1', 'passive'), (3, 'IO2', 'passive'), (4, 'IO3', 'passive'), (6, 'IO4', 'passive')],
           [(5, 'VP', 'passive'), None, None, (2, 'GND', 'passive')], 10.16, 'U',
           '4-line ESD/TVS array, SOT-23-6', 'Package_TO_SOT_SMD:SOT-23-6'))
    add(ic('USBLC6-2SC6', [(1, 'IO1', 'passive'), (6, 'IO1', 'passive'), (3, 'IO2', 'passive'), (4, 'IO2', 'passive')],
           [(5, 'VBUS', 'passive'), None, None, (2, 'GND', 'passive')], 10.16, 'U',
           'USB ESD protection, SOT-23-6 (1/6 and 3/4 are flow-through pairs)', 'Package_TO_SOT_SMD:SOT-23-6'))
    add(ic('SC16IS752IPW',
           [(14, 'SDA', 'bidirectional'), (13, 'SCL', 'input'), (15, '~{IRQ}', 'open_collector'), (5, '~{RESET}', 'input'),
            (9, 'I2C/~{SPI}', 'input'), (10, 'A0/~{CS}', 'input'), (11, 'A1/SI', 'input'), (12, 'SO', 'output'), None,
            (6, 'XTAL1', 'input'), (7, 'XTAL2', 'output'), None, (8, 'VDD', 'power_in'), (22, 'VSS', 'power_in')],
           [(3, 'TXA', 'output'), (4, 'RXA', 'input'), (1, '~{RTSA}', 'output'), (2, '~{CTSA}', 'input'), None,
            (23, 'TXB', 'output'), (24, 'RXB', 'input'), (17, '~{RTSB}', 'output'), (16, '~{CTSB}', 'input'), None,
            (18, 'GPIO0', 'bidirectional'), (19, 'GPIO1', 'bidirectional'), (20, 'GPIO2', 'bidirectional'),
            (21, 'GPIO3', 'bidirectional'), (25, 'GPIO4', 'bidirectional'), (26, 'GPIO5', 'bidirectional'),
            (27, 'GPIO6', 'bidirectional'), (28, 'GPIO7', 'bidirectional')],
           22.86, 'U', 'Dual UART with I2C/SPI and 8 GPIO, TSSOP-28', 'Package_SO:TSSOP-28_4.4x9.7mm_P0.65mm'))

    # USB-C receptacle (GCT USB4105) ------------------------------------------
    usb = ic('USB_C_USB2.0',
             [('A4', 'VBUS'), ('A9', 'VBUS'), ('B4', 'VBUS'), ('B9', 'VBUS'), None, ('A5', 'CC1'), ('B5', 'CC2'), None,
              ('A6', 'D+'), ('B6', 'D+'), ('A7', 'D-'), ('B7', 'D-'), None, ('A8', 'SBU1'), ('B8', 'SBU2')],
             [('A1', 'GND'), ('A12', 'GND'), ('B1', 'GND'), ('B12', 'GND'), None, ('SH', 'SHIELD')],
             15.24, 'J', 'USB 2.0 Type-C receptacle (GCT USB4105-GF-A)',
             'Connector_USB:USB_C_Receptacle_GCT_USB4105-xx-A_16P_TopMnt_Horizontal')
    add(usb)

    # modules / sockets ---------------------------------------------------------
    j1 = ['3V3', '3V3', 'RST(EN)', 'GPIO4', 'GPIO5', 'GPIO6', 'GPIO7', 'GPIO15', 'GPIO16', 'GPIO17', 'GPIO18', 'GPIO8',
          'GPIO3', 'GPIO46', 'GPIO9', 'GPIO10', 'GPIO11', 'GPIO12', 'GPIO13', 'GPIO14', '5V', 'GND']
    j3 = ['GND', 'GPIO43/TX', 'GPIO44/RX', 'GPIO1', 'GPIO2', 'GPIO42', 'GPIO41', 'GPIO40', 'GPIO39', 'GPIO38', 'GPIO37',
          'GPIO36', 'GPIO35', 'GPIO0', 'GPIO45', 'GPIO48', 'GPIO47', 'GPIO21', 'GPIO20', 'GPIO19', 'GND', 'GND']
    dk = ic('ESP32-S3-DevKitC-1', [(i + 1, n) for i, n in enumerate(j1)], [(23 + i, n) for i, n in enumerate(j3)],
            25.4, 'A', 'Espressif ESP32-S3-DevKitC-1-N8R8 (PCB antenna) on 2x22 sockets, rows 22.86 mm apart (Espressif v1.1 DXF). Pins 1-22 = J1 (pin 1 = 3V3, antenna end), 23-44 = J3.',
            'SB1:ESP32-S3-DevKitC-1_Socket', top_pad=1, bottom_pad=1)
    add(dk)

    p2 = ['GND', 'AUX_TX', 'AUX_RX', 'AUX_EN', 'AUX4', 'AUX3', 'AUX2', 'AUX1', 'ATTN', 'CTX', 'RTX', 'TX', 'RX', 'SCL', 'SDA', 'GND']
    p1r = ['GND', 'ALT_DFU_RX', 'ALT_DFU_TX', 'ALT_DFU_BOOT', 'ALT_DFU_NRST', 'ALT_DFU_IDLE', 'VGPS_IN', 'VGPS_OUT',
           'EN(VIO_EN)', 'NCHG', 'NRST', 'BOOT', 'VIO', 'VMAIN', 'VUSB', 'VBAT']
    nc = ic('Blues_Notecarrier_X', [(i + 1, n) for i, n in enumerate(p2)], [(17 + i, n) for i, n in enumerate(p1r)],
            25.4, 'M', 'Blues Notecarrier X v1.2 on 2x16 sockets, rows 33.02 mm apart. Pins 1-16 = P2 (signals), 17-32 = P1 pin 16..1 (power).',
            'SB1:Blues_Notecarrier-X_Socket')
    add(nc)

    sock = 'Connector_PinSocket_2.54mm:PinSocket_1x{:02d}_P2.54mm_Vertical'
    hdr = 'Connector_PinHeader_2.54mm:PinHeader_1x{:02d}_P2.54mm_Vertical'
    add(connector('LD6004_Port', ['P20(out)', 'TX(out)', 'RX(in)', 'GND', 'VCC_3V3'], 'J',
                  'HLK-LD6004 port, 2.54 mm socket. Pin n = LD6004 signal-header pin n (1.27 mm at the module; pin 1 = square pad, P20): straight 1:1 pigtail', sock.format(5)))
    add(connector('LD6004_Port_XH', ['P20(out)', 'TX(out)', 'RX(in)', 'GND', 'VCC_3V3'], 'J',
                  'HLK-LD6004 port, JST-XH locking (parallel to the socket). Pin n = LD6004 signal-header pin n', 'Connector_JST:JST_XH_B5B-XH-A_1x05_P2.50mm_Vertical'))
    add(connector('LD2450_Port', ['5V', 'GND', 'TX(out)', 'RX(in)'], 'J', 'HLK-LD2450 port, 2.54 mm socket', sock.format(4)))
    add(connector('LD6004_Module', ['P20(out)', 'TX(out)', 'RX(in)', 'GND', 'VCC_3V3'], 'J',
                  'HLK-LD6004 mounted on the board, antenna side up, on two 1x5 1.27 mm sockets (signal row + debug row). '
                  'Pin n = LD6004 signal-header pin n (pin 1 = square pad, P20); debug-row pads are mechanical only',
                  'SB1:HLK-LD6004_Module_2x1x05_P1.27mm'))
    add(connector('LD2450_Module', ['5V', 'GND', 'TX(out)', 'RX(in)'], 'J',
                  'HLK-LD2450 mounted on the board, antenna side up, on a 2x4 2.00 mm socket that takes the module\'s own header. '
                  'Uses module pins 5 (5V), 8 (GND), 3 (TX), 4 (RX); DM, DP, 3V3out and PA9 are left unconnected',
                  'SB1:HLK-LD2450_Module_2x04_P2.00mm'))
    add(connector('LD2450_Port_XH', ['5V', 'GND', 'TX(out)', 'RX(in)'], 'J', 'HLK-LD2450 port, JST-XH locking',
                  'Connector_JST:JST_XH_B4B-XH-A_1x04_P2.50mm_Vertical'))
    add(connector('Sniff_3', ['GND', 'SENSOR_TX', 'HOST_TX'], 'J', 'UART sniff header for a USB-UART (listen only)', hdr.format(3)))
    add(connector('SPH0645_Socket', ['3V', 'GND', 'BCLK', 'DOUT', 'LRCL', 'SEL'], 'J',
                  'Adafruit I2S MEMS mic breakout (SPH0645LM4H, PID 3421) socket: verify pin order against the breakout silk', sock.format(6)))
    add(connector('MAX98357A_Socket', ['LRC', 'BCLK', 'DIN', 'GAIN', 'SD', 'GND', 'Vin'], 'J',
                  'Adafruit MAX98357A I2S amp breakout (PID 3006) socket: verify pin order against the breakout silk', sock.format(7)))
    add(connector('NFC_Header', ['5V', '3V3', 'GND', 'SDA', 'SCL', 'IRQ', 'RSTPDN'], 'J',
                  'NFC reader header (PN532 breakout in I2C mode, wired with jumpers)', sock.format(7)))
    add(connector('PN532_V3_Module', ['SCL', 'SDA', 'VCC', 'GND', 'SCK', 'MISO', 'MOSI', 'SS', 'VCC', 'GND', 'IRQ', 'RSTO'], 'J',
                  'PN532 NFC module V3 (Elechouse layout, red 40.4 x 42.7 mm) plugged face-out onto the front of TB1 by its own '
                  'pins: 1-4 = its 4-pin I2C/HSU header (SCL SDA VCC GND), 5-12 = its 8-pin header (SCK MISO MOSI SS VCC GND IRQ RSTO). '
                  'DIP switch: 1 ON, 2 OFF = I2C',
                  'SB1:PN532_NFC_Module_V3_Sockets'))
    add(connector('Expansion_8', ['+3V3', 'GND', 'GPIO3', 'GPIO38', 'GPIO48', 'I2C0_SDA', 'I2C0_SCL', '+5V'], 'J',
                  'Expansion header', hdr.format(8)))
    add(connector('NC_AUX_5', ['AUX1', 'AUX2', 'AUX3', 'AUX4', 'GND'], 'J', 'Notecard AUX GPIO breakout', hdr.format(5)))
    add(connector('NC_UART_3', ['NC_TX', 'NC_RX', 'GND'], 'J', 'Notecard UART monitor', hdr.format(3)))
    add(connector('Qwiic', ['GND', '3V3', 'SDA', 'SCL'], 'J', 'Qwiic / STEMMA QT (JST-SH 4)',
                  'Connector_JST:JST_SH_SM04B-SRSS-TB_1x04-1MP_P1.00mm_Horizontal'))
    add(dual_row('XVF3800_Header', ['+5V', '+5V', 'GND', 'GND', 'SDA', 'SCL', 'BCLK', 'WS', 'DATA_OUT', 'DATA_IN', 'MCLK', '~{RST}'],
                 'J', 'Audio front-end header for ReSpeaker XVF3800 (jumper-wired to its XIAO pads)',
                 'Connector_PinHeader_2.54mm:PinHeader_2x06_P2.54mm_Vertical'))
    add(dual_row('ODFU_Jumpers', ['ALT_DFU_RX', 'U0TXD', 'ALT_DFU_TX', 'U0RXD', 'ALT_DFU_BOOT', 'BOOT', 'ALT_DFU_NRST', 'EN'],
                 'JP', 'Notecard outboard-DFU jumpers (all open by default)',
                 'Connector_PinHeader_2.54mm:PinHeader_2x04_P2.54mm_Vertical'))

    # ---- SB1 additions (2026-10-25) ------------------------------------------------------------
    add(connector('I2S_Mic_Breakout', ['3V', 'GND', 'BCLK', 'DOUT', 'LRCL', 'SEL'], 'J',
                  'Adafruit I2S MEMS mic breakout, 6049 (ICS-43434) or 3421 (SPH0645), soldered flat on its 1x6 header at the board edge, sound hole facing out. '
                  'Pin order from Adafruit\'s board files. SEL low = left channel, high = right',
                  'SB1:Adafruit_I2S_Mic_Breakout_1x06_Overhang_Back'))
    # WCH CH340C USB-UART, SOIC-16, internal oscillator. 3.3 V operation: V3 tied to VCC.
    add(ic('CH340C', [(5, 'UD+', 'bidirectional'), (6, 'UD-', 'bidirectional'), None,
                      (16, 'VCC', 'power_in'), (4, 'V3', 'power_in'), (1, 'GND', 'power_in'), None,
                      (7, 'NC', 'no_connect'), (15, 'R232', 'input')],
           [(2, 'TXD', 'output'), (3, 'RXD', 'input'), None, (13, '~{DTR}', 'output'), (14, '~{RTS}', 'output'), None,
            (9, '~{CTS}', 'input'), (10, '~{DSR}', 'input'), (11, '~{RI}', 'input'), (12, '~{DCD}', 'input'), (8, '~{OUT}', 'output')],
           17.78, 'U', 'WCH CH340C USB to UART, internal oscillator, SOP-16 (WCH CH340DS1: pin 7 NC, 8 OUT#, 15 R232; V3 to VCC for 3.3 V)', 'Package_SO:SOIC-16_3.9x9.9mm_P1.27mm'))
    add(ic('74LVC1G11', [(1, 'A', 'input'), (3, 'B', 'input'), (6, 'C', 'input')],
           [(5, 'VCC', 'power_in'), (4, 'Y', 'output'), (2, 'GND', 'power_in')],
           10.16, 'U', 'Single 3-input AND gate, SOT-23-6 (inputs 5 V tolerant)', 'Package_TO_SOT_SMD:SOT-23-6'))
    add(ic('D_Schottky_x2_KCommon', [(1, 'A1', 'passive'), (2, 'A2', 'passive')], [(3, 'K', 'passive')],
           10.16, 'D', 'Dual Schottky, common cathode, SOT-23 (1 = anode 1, 2 = anode 2, 3 = cathode)', 'Package_TO_SOT_SMD:SOT-23'))
    add(ic('TPS2113APW', [(8, 'IN1', 'power_in'), (6, 'IN2', 'power_in'), None, (3, 'VSNS', 'input'), (2, '~{EN}', 'input'),
                          (4, 'ILIM', 'passive')],
           [(7, 'OUT', 'power_out'), None, (1, '~{STAT}', 'open_collector'), None, None, (5, 'GND', 'power_in')],
           12.7, 'U', 'TI TPS2113A autoswitching power mux, TSSOP-8 (PW): IN1 has priority while VSNS > 0.8 V; no reverse current',
           'Package_SO:TSSOP-8_4.4x3mm_P0.65mm'))
    add(dual_row('Ribbon_2x10', ['GND', '+5V', '+5V', 'GND', 'A_TX_IN', 'GND', 'A_RX_OUT', 'GND', 'B_TX_IN', 'GND',
                                 'B_RX_OUT', 'GND', 'SDA', 'GND', 'SCL', 'GND', 'A_EN', 'B_EN', 'A_P20', 'B_FLT'],
                 'J', 'Link to the mainboard: 2x10 2.54 mm shrouded IDC header, flat ribbon (wire n = pin n). The +5V pair and each UART / I2C line sit between ground wires; the four slow enable / status lines are grouped at the end',
                 'Connector_IDC:IDC-Header_2x10_P2.54mm_Vertical', width=22.86))

    # ---- SB1 rev B additions (2026-10-31) ------------------------------------------------------
    ffc20 = ['GND', '+5V', '+5V', 'GND', '6004_TX(out)', '6004_RX(in)', 'GND', '2450_TX(out)', '2450_RX(in)', 'GND',
             'MIC_BCLK', 'GND', 'MIC_WS', 'MIC_DATA', 'GND', 'SDA', 'SCL', '6004_P20', 'SPARE1', 'SPARE2']
    s = connector('FFC_ZIF_20', ffc20, 'J',
                  'Link to the mainboard: Molex Easy-On 200528-0200, 20-way 1.00 mm FFC ZIF, back flip, bottom contacts, '
                  'ear-tab cable lock. Wire n = pin n. MP = the two solder tabs (tied to GND)',
                  'Connector_FFC-FPC:Molex_200528-0200_1x20-1MP_P1.00mm_Horizontal', width=17.78)
    s.pins.append(Pin('MP', 'MP', -17.78 / 2 - G, round(((20 - 1) // 2) * G, 3) - 21 * G, 0))
    add(s)
    # 11/7: the same ZIF wired in reverse (pad n carries the signal of wire 21 - n; pin names show what each pad carries).
    # Used for SB1's J7 and Mainboard-USB's J3, so the pin-1 signal (GND) sits at the bottom of every ZIF on both boards.
    s = connector('FFC_ZIF_20_REV', list(reversed(ffc20)), 'J',
                  'Molex Easy-On 200528-0200, 20-way 1.00 mm FFC ZIF wired in reverse: pad n carries the signal of FFC wire '
                  '21 - n (pad 20 = GND). MP = the two solder tabs (GND)',
                  'Connector_FFC-FPC:Molex_200528-0200_1x20-1MP_P1.00mm_Horizontal', width=17.78)
    s.pins.append(Pin('MP', 'MP', -17.78 / 2 - G, round(((20 - 1) // 2) * G, 3) - 21 * G, 0))
    add(s)
    add(ic('24AA256UID', [(1, 'A0', 'input'), (2, 'A1', 'input'), (3, 'A2', 'input'), None, (7, 'NC', 'no_connect')],
           [(8, 'VCC', 'power_in'), (5, 'SDA', 'bidirectional'), (6, 'SCL', 'input'), None, (4, 'VSS', 'power_in')],
           15.24, 'U', 'Microchip 24AA256UID 256 Kbit I2C EEPROM with factory 32-bit serial number, SOIC-8. '
           'A0-A2 to VSS: address 0x50. Pin 7 is NC on this part (no WP)', 'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm'))
    add(ic('VEML7700', [(2, 'VDD', 'power_in'), None, (3, 'GND', 'power_in')],
           [(4, 'SDA', 'bidirectional'), None, (1, 'SCL', 'input')],
           12.7, 'U', 'Vishay VEML7700-TT ambient light sensor, I2C 0x10, top-view package (window faces away from the board)',
           'SB1:Vishay_VEML7700_TopView'))
    add(Sym('MountingHole_M2.5', 'H', 'M2.5 mounting hole, not plated; screw from the front into a heat-set insert in the holder',
            'SB1:MountingHole_2.7mm_M2.5_KeepOut', [], [circle(0, 0, 1.27), circle(0, 0, 2.54)],
            hide_pin_names=True, hide_pin_numbers=True, ref_at=(3.81, 1.27, 0), val_at=(3.81, -1.27, 0)))
    add(connector('Spare_3', ['SPARE1', 'SPARE2', 'GND'], 'J', 'Spare FFC wires 19 and 20 to a 1x3 header (with GND)', hdr.format(3)))
    return L
