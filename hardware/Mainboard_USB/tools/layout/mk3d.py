"""3D models for the parts KiCad's library has no model for (2026-10-31). Writes VRML 2.0 files into <project>/3dmodels/.

Each model is in its footprint's own frame (footprint origin, rotation 0, board top at z = 0; footprint y is down, model
y is up), so the footprint references it with no offset or rotation. VRML units are 2.54 mm, as KiCad expects.
KiCad's 3D viewer shows .wrl models; a STEP export of the board leaves them out (Adafruit's own STEP files are copied to
3dmodels/vendor/ for MCAD use where they exist).

Models (simplified unless noted; dimensions from the footprints, the parts' drawings and the notes in the tracker):
- Molex_200528-0200_approx: Easy-On 1.0 mm FFC ZIF, 20-way, housing 25.2 x 3.6 x 1.9 mm, flip actuator, contacts.
  KiCad's footprint points at an official STEP that isn't in this KiCad install's 3D library.
- SB1_HLK-LD6004_module: the module's 35 x 7 mm board at 5.0-6.0 mm, AiP block to 6.5 mm (the antenna face), AiP antenna block.
  The two 1x5 1.27 mm sockets come from KiCad's own models (already in the footprint).
- SB1_HLK-LD2450_module: 44 x 15 mm board, back at 6.3 mm, face at 7.3 mm, three antenna patch rows, the 5 mm white
  4-pin socket on its back. The 2x4 2.00 mm socket is KiCad's own model.
- SB1_VEML7700-TT: 6.8 x 3.0 x 2.35 mm body, clear lens, window up.
- SB1_Adafruit_6049_Mic_on_socket: Adafruit's own 3D model of the 6049 breakout (from adafruit/Adafruit_CAD_Parts,
  3MF mesh, MIT licence) turned sound-hole side up on a 1x6 male header in an 8.5 mm 1x6 socket; top at 12.6 mm.
- MBUSB_Adafruit_4162_VEML7700_on_socket: the 4162 (STEMMA QT version) built from Adafruit's board file
  (Adafruit-VEML7700-PCB): 25.4 x 17.78 mm blue board, four holes, regulator, sensor, two STEMMA QT sockets, on a
  1x5 male header in an 8.5 mm socket; top at 12.6 mm.

usage: mk3d.py <project dir> <SB1|MBUSB> [path to Adafruit 6049 .3mf]
"""
import math, os, sys

P_DIR, WHICH = sys.argv[1], sys.argv[2]
MIC3MF = sys.argv[3] if len(sys.argv) > 3 else None
OUT = os.path.join(P_DIR, '3dmodels')
os.makedirs(OUT, exist_ok=True)
S = 1 / 2.54

BLACK = (0.08, 0.08, 0.08)
GOLD = (0.85, 0.65, 0.2)
TIN = (0.75, 0.75, 0.78)
GREEN = (0.08, 0.3, 0.15)
BLUE = (0.1, 0.25, 0.65)
BEIGE = (0.85, 0.8, 0.65)
WHITE = (0.92, 0.92, 0.9)
CLEAR = (0.85, 0.9, 0.95)
DARK = (0.2, 0.2, 0.22)


class Model:
    def __init__(self):
        self.parts = {}                       # rgb -> (points, faces)

    def _add(self, rgb, pts, faces):
        P, F = self.parts.setdefault(rgb, ([], []))
        o = len(P)
        P += pts
        F += [[i + o for i in f] for f in faces]

    def prism(self, poly, z0, z1, rgb):
        """poly: [(x, y_footprint), ...] counter-clockwise or not; extruded from z0 to z1"""
        n = len(poly)
        pts = [(x, -y, z0) for x, y in poly] + [(x, -y, z1) for x, y in poly]
        faces = [list(range(n))[::-1], list(range(n, 2 * n))]
        faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
        self._add(rgb, pts, faces)

    def box(self, x0, y0, x1, y1, z0, z1, rgb):
        self.prism([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z0, z1, rgb)

    def cyl(self, cx, cy, r, z0, z1, rgb, n=16):
        self.prism([(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)],
                   z0, z1, rgb)

    def mesh(self, rgb, tris):
        pts, faces = [], []
        for t in tris:
            faces.append([len(pts), len(pts) + 1, len(pts) + 2])
            pts += t
        self._add(rgb, pts, faces)

    def write(self, name):
        L = ['#VRML V2.0 utf8', f'# {name}: moveOmeter generated model, footprint frame, 1 unit = 2.54 mm']
        for rgb, (P, F) in self.parts.items():
            L.append('Shape { appearance Appearance { material Material { diffuseColor %.3f %.3f %.3f '
                     'specularColor 0.2 0.2 0.2 shininess 0.3 } }' % rgb)
            L.append(' geometry IndexedFaceSet { solid FALSE creaseAngle 0.5 coord Coordinate { point [')
            L.append(','.join('%.4f %.4f %.4f' % (x * S, y * S, z * S) for x, y, z in P))
            L.append('] } coordIndex [')
            L.append(','.join(' '.join(str(i) for i in f) + ' -1' for f in F))
            L.append('] } }')
        p = os.path.join(OUT, name + '.wrl')
        open(p, 'w').write('\n'.join(L) + '\n')
        print('wrote', p)


def header_on_socket(m, xs, y, sock_h=8.5, plastic=2.5):
    """1xN female socket (sock_h tall) with a male header plugged in (plastic 2.5 mm) at pin x positions xs, row y"""
    x0, x1 = min(xs) - 1.27, max(xs) + 1.27
    m.box(x0, y - 1.27, x1, y + 1.27, 0, sock_h, BLACK)
    m.box(x0, y - 1.27, x1, y + 1.27, sock_h, sock_h + plastic, (0.12, 0.12, 0.12))
    for x in xs:
        m.box(x - 0.32, y - 0.32, x + 0.32, y + 0.32, -3.0, 0, TIN)          # socket tails through the board
        m.box(x - 0.32, y - 0.32, x + 0.32, y + 0.32, sock_h + plastic, sock_h + plastic + 1.6 + 1.0, TIN)


def molex_200528():
    m = Model()
    m.box(-12.6, -1.06, 12.6, 2.89, 0, 1.9, BLACK)                         # housing
    m.box(-11.8, 0.19, 11.8, 4.19, 1.2, 1.9, DARK)                         # flip actuator
    for i in range(20):
        x = -9.5 + i
        m.box(x - 0.15, -1.41, x + 0.15, -0.6, 0, 0.15, GOLD)              # contact tails
    for sx_ in (-1, 1):
        m.box(sx_ * 12.3 - 1.0, 1.14, sx_ * 12.3 + 1.0, 2.44, 0, 0.2, TIN)  # solder tabs
    m.write('Molex_200528-0200_approx')


def ld6004():
    m = Model()
    m.box(-17.5, -3.5, 17.5, 3.5, 5.0, 6.0, GREEN)                         # module board
    m.box(-9.4, -2.6, 1.0, 2.6, 6.0, 6.5, (0.15, 0.15, 0.18))              # AiP antenna-in-package: face at 6.5 mm
    m.box(3.0, -2.0, 7.0, 2.0, 6.0, 6.4, BLACK)                            # radar SoC area
    for sx_ in (-16.4, 16.4):                                              # male header plastic on the sockets
        m.box(sx_ - 0.6, -3.175, sx_ + 0.6, 3.175, 4.5, 5.0, BLACK)
    m.write('SB1_HLK-LD6004_module')


def ld2450():
    m = Model()
    outline = [(-20.0, -7.5), (21.0, -7.5), (22.0, -6.5), (22.0, 5.8), (20.0, 5.8), (20.0, 7.5), (-21.0, 7.5),
               (-22.0, 6.5), (-22.0, -5.8), (-20.0, -5.8)]
    m.prism(outline, 6.3, 7.3, GREEN)                                      # back at 6.3, face at 7.3 mm
    for row in (-4.0, 0.0, 4.0):                                           # antenna patch rows (illustrative)
        for k in range(6):
            x = -8.0 + k * 4.2
            m.box(x - 1.4, row - 1.2, x + 1.4, row + 1.2, 7.3, 7.33, GOLD)
    m.box(-12.5, -3.0, -10.0, 3.0, 7.3, 8.1, BLACK)                        # radar chip area
    m.box(17.0, -4.0, 21.0, 4.0, 1.3, 6.3, WHITE)                          # 4-pin 1.5 mm socket on the back, 5 mm
    m.box(-19.0, -4.46, -15.0, 3.54, 4.3, 6.3, BLACK)                      # SMD 2x4 male header on the back
    m.write('SB1_HLK-LD2450_module')


def veml_bare():
    m = Model()
    m.box(-3.4, -1.5, 3.4, 1.5, 0, 2.35, CLEAR)
    m.box(-0.6, -0.4, 0.6, 0.4, 2.35, 2.4, DARK)                           # sensor die under the lens
    for x in (-1.905, -0.635, 0.635, 1.905):
        m.box(x - 0.3, -1.6, x + 0.3, -0.6, 0, 0.1, TIN)
    m.write('SB1_VEML7700-TT')


def mic_6049():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import mf3
    tris = mf3.load(MIC3MF)
    m = Model()
    xs = [3 * 2.54 - 2.54 / 2 - i * 2.54 for i in range(6)]               # footprint pads, pin 1 at +6.35
    header_on_socket(m, xs, 0.0)
    # Adafruit frame (board 16.51 x 12.7, header row y 2.54, pin 1 x 1.905, parts on top) -> turned over (port side
    # up, 12.6 mm off the board): turned 180 deg about y: model x = 8.255 - x, model y = y - 2.54, z = 12.6 - z
    for rgb, ts in tris.items():
        conv = [tuple((8.255 - x, y - 2.54, 12.6 - z) for x, y, z in t) for t in ts]
        m.mesh(rgb, conv)
    m.write('SB1_Adafruit_6049_Mic_on_socket')


def veml_4162():
    m = Model()
    BW, BH, CH, ROW = 12.7, 8.89, 2.54, 6.35
    xs = [-5.08 + 2.54 * i for i in range(5)]
    header_on_socket(m, xs, ROW)
    z0, z1 = 11.0, 12.6
    oct_ = [(-BW + CH, -BH), (BW - CH, -BH), (BW, -BH + CH), (BW, BH - CH), (BW - CH, BH), (-BW + CH, BH), (-BW, BH - CH),
            (-BW, -BH + CH)]
    m.prism(oct_, z0, z1, BLUE)
    for hx in (-10.16, 10.16):
        for hy in (-6.35, 6.35):
            m.cyl(hx, hy, 1.6, z1, z1 + 0.04, GOLD)
            m.cyl(hx, hy, 1.25, z1, z1 + 0.06, BLACK)
    # Adafruit board file (x 0..25.4, y 0..17.78, header y 2.54) -> footprint: x - 12.7, y = 8.89 - y
    def at(x, y):
        return x - 12.7, 8.89 - y
    cx, cy = at(12.7, 13.716)
    m.box(cx - 3.4, cy - 1.5, cx + 3.4, cy + 1.5, z1, z1 + 2.35, CLEAR)    # VEML7700
    for (x, y, w, h, hh, c) in ((10.16, 9.017, 1.7, 3.0, 1.1, BLACK),      # AP2112 regulator
                                (7.112, 8.89, 1.3, 2.0, 1.0, BEIGE), (13.208, 9.017, 1.3, 2.0, 1.0, BEIGE),
                                (17.018, 6.731, 2.1, 1.3, 1.0, BLACK),     # BSS138 pair
                                (16.891, 10.414, 3.2, 1.6, 0.5, BLACK)):   # pull-up resistor pack
        px, py = at(x, y)
        m.box(px - w / 2, py - h / 2, px + w / 2, py + h / 2, z1, z1 + hh, c)
    for x in (2.667, 22.733):                                              # STEMMA QT sockets (JST SH 4)
        px, py = at(x, 8.89)
        m.box(px - 2.25, py - 3.0, px + 2.25, py + 3.0, z1, z1 + 2.9, WHITE)
    m.write('MBUSB_Adafruit_4162_VEML7700_on_socket')


if WHICH == 'SB1':
    molex_200528(); ld6004(); ld2450(); veml_bare()
    if MIC3MF:
        mic_6049()
else:
    molex_200528(); veml_4162()
