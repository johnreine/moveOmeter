"""STEP model of the Hi-Link HLK-LD6004 60 GHz radar module (2026-10-31), from Hi-Link's dimension drawing:
35 x 7 mm board, 1x5 1.27 mm headers at both ends (outer pins 1 mm from the long edges), antenna block 10 mm wide starting
8 mm from the end with the debug header (17 mm from the signal-header end).

Model frame (same as the LD2450 model): origin at the board centre, board bottom at z = 0, antenna side up (+z), seen
from the antenna side with "HLK-LD6004" readable: debug header at -x, signal header at +x, pin 1 (P20, square pad) at
the bottom (-y). That is the footprint's own orientation, so the footprint uses offset z = 5.5 mm (1x5 socket 4.5 mm +
male header plastic 1.0 mm) and no rotation; the antenna face then sits at 6.55 mm.
The headers are male 1x5 1.27 mm strips with their plastic on the component side, pins down into the sockets.
Component-side parts are placed from the drawing's front-view photo (positions approximate, mirrored end for end).

Writes plain AP214 B-rep boxes with colours, no external tools needed.
usage: mkstep_ld6004.py <out.step>
"""
import sys, math

OUT = sys.argv[1]

BLUE = (0.10, 0.36, 0.72)
DKGREEN = (0.10, 0.25, 0.15)
BLACK = (0.08, 0.08, 0.08)
GOLD = (0.85, 0.65, 0.20)
SILVER = (0.78, 0.78, 0.80)
BEIGE = (0.80, 0.70, 0.50)
WHITE = (0.92, 0.92, 0.90)
GREY = (0.30, 0.30, 0.32)

T_PCB = 0.8
boxes = []          # (name, x0, y0, z0, x1, y1, z1, rgb)


def box(name, x0, y0, z0, x1, y1, z1, rgb):
    boxes.append((name, min(x0, x1), min(y0, y1), min(z0, z1), max(x0, x1), max(y0, y1), max(z0, z1), rgb))


# board and antenna side (top)
box('PCB', -17.5, -3.5, 0, 17.5, 3.5, T_PCB, BLUE)
box('Antenna', -9.5, -2.9, T_PCB, 0.5, 2.7, T_PCB + 0.25, DKGREEN)        # 8 mm from the debug end, 10 mm wide
box('LED', -13.9, 1.9, T_PCB, -11.3, 3.0, T_PCB + 0.6, WHITE)
box('Sensor', 1.6, -3.1, T_PCB, 5.5, -1.7, T_PCB + 0.7, WHITE)
box('Part_top', 2.6, 2.25, T_PCB, 5.0, 3.45, T_PCB + 0.5, BLACK)
box('R_top', 13.8, 0.6, T_PCB, 15.2, 3.2, T_PCB + 0.45, BEIGE)
# component side (bottom), positions from the front-view photo, mirrored end for end
for name, cx, cy, w, h, t, c in (('MCU_QFN', 8.75, -1.2, 4.0, 4.0, 0.9, BLACK),
                                  ('Radar_shield', -5.4, -0.1, 3.0, 2.8, 0.6, GOLD),
                                  ('SOIC', 1.2, -0.8, 2.1, 4.4, 1.2, BLACK),
                                  ('QFN_small', -13.7, 1.0, 2.3, 2.2, 0.8, BLACK),
                                  ('Crystal_1', 11.8, 1.7, 2.0, 2.3, 0.8, SILVER),
                                  ('Crystal_2', -11.6, -1.8, 1.7, 2.1, 0.8, SILVER),
                                  ('Inductor', 3.6, -1.1, 1.4, 3.2, 1.0, GREY),
                                  ('Cap', 14.35, 2.4, 0.9, 1.2, 0.8, BEIGE)):
    box(name, cx - w / 2, cy - h / 2, -t, cx + w / 2, cy + h / 2, 0, c)
# headers: plastic on the component side, pins down (4.0 mm) and a short stub on the antenna side
for sx_, nm in ((-16.4, 'Debug'), (16.4, 'Signal')):
    box(f'{nm}_header', sx_ - 1.1, -3.2, -1.0, sx_ + 1.1, 3.2, 0, BLACK)
    for k in range(5):
        y = -2.54 + 1.27 * k
        box(f'{nm}_pin{k + 1}', sx_ - 0.2, y - 0.2, -4.0, sx_ + 0.2, y + 0.2, T_PCB + 0.2, GOLD)

# ------------------------------------------------------------------ AP214 writer
L = []
n = [0]


def e(s):
    n[0] += 1
    L.append(f'#{n[0]}={s};')
    return n[0]


def f(v):
    s = f'{v:.6f}'.rstrip('0')            # STEP reals keep the point: '1.', '-3.5'
    return '0.' if s in ('-0.', '0.') else s


ctx_app = e("APPLICATION_CONTEXT('core data for automotive mechanical design processes')")
e(f"APPLICATION_PROTOCOL_DEFINITION('international standard','automotive_design',2000,#{ctx_app})")
pctx = e(f"PRODUCT_CONTEXT('',#{ctx_app},'mechanical')")
pdctx = e(f"PRODUCT_DEFINITION_CONTEXT('part definition',#{ctx_app},'design')")
prod = e(f"PRODUCT('HLK-LD6004','HLK-LD6004 60 GHz radar module (moveOmeter model)','',(#{pctx}))")
e(f"PRODUCT_RELATED_PRODUCT_CATEGORY('part',$,(#{prod}))")
pdf = e(f"PRODUCT_DEFINITION_FORMATION('','',#{prod})")
pd = e(f"PRODUCT_DEFINITION('design','',#{pdf},#{pdctx})")
pds = e(f"PRODUCT_DEFINITION_SHAPE('','',#{pd})")
lu = e("(LENGTH_UNIT()NAMED_UNIT(*)SI_UNIT(.MILLI.,.METRE.))")
au = e("(NAMED_UNIT(*)PLANE_ANGLE_UNIT()SI_UNIT($,.RADIAN.))")
su = e("(NAMED_UNIT(*)SI_UNIT($,.STERADIAN.)SOLID_ANGLE_UNIT())")
unc = e(f"UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(1.E-07),#{lu},'distance_accuracy_value','confusion accuracy')")
gctx = e(f"(GEOMETRIC_REPRESENTATION_CONTEXT(3)GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#{unc}))"
         f"GLOBAL_UNIT_ASSIGNED_CONTEXT((#{lu},#{au},#{su}))REPRESENTATION_CONTEXT('Context #1','3D Context with UNIT and UNCERTAINTY'))")


def cp(p):
    return e(f"CARTESIAN_POINT('',({f(p[0])},{f(p[1])},{f(p[2])}))")


def dr(d):
    return e(f"DIRECTION('',({f(d[0])},{f(d[1])},{f(d[2])}))")


o = cp((0, 0, 0))
origin_ax = e(f"AXIS2_PLACEMENT_3D('',#{o},#{dr((0, 0, 1))},#{dr((1, 0, 0))})")


def sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(a):
    l = math.sqrt(sum(c * c for c in a))
    return tuple(c / l for c in a)


FACES = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def solid(name, x0, y0, z0, x1, y1, z1):
    P = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    V = [e(f"VERTEX_POINT('',#{cp(p)})") for p in P]
    edges = {}

    def edge(a, b):
        k = (min(a, b), max(a, b))
        if k not in edges:
            lo, hi = k
            d = sub(P[hi], P[lo])
            ln = math.sqrt(sum(c * c for c in d))
            pt0, dd = cp(P[lo]), dr(unit(d))
            vec = e("VECTOR('',#%d,%s)" % (dd, f(ln)))
            line = e("LINE('',#%d,#%d)" % (pt0, vec))
            edges[k] = e(f"EDGE_CURVE('',#{V[lo]},#{V[hi]},#{line},.T.)")
        return edges[k], (a, b) == (min(a, b), max(a, b))

    faces = []
    for fc in FACES:
        oes = []
        for i in range(4):
            a, b = fc[i], fc[(i + 1) % 4]
            ec, same = edge(a, b)
            oes.append(e(f"ORIENTED_EDGE('',*,*,#{ec},{'.T.' if same else '.F.'})"))
        loop = e(f"EDGE_LOOP('',({','.join('#%d' % x for x in oes)}))")
        bound = e(f"FACE_OUTER_BOUND('',#{loop},.T.)")
        nrm = unit(cross(sub(P[fc[1]], P[fc[0]]), sub(P[fc[2]], P[fc[0]])))
        ref = unit(sub(P[fc[1]], P[fc[0]]))
        ax = e(f"AXIS2_PLACEMENT_3D('',#{cp(P[fc[0]])},#{dr(nrm)},#{dr(ref)})")
        pl = e(f"PLANE('',#{ax})")
        faces.append(e(f"ADVANCED_FACE('',(#{bound}),#{pl},.T.)"))
    shell = e(f"CLOSED_SHELL('',({','.join('#%d' % x for x in faces)}))")
    return e(f"MANIFOLD_SOLID_BREP('{name}',#{shell})")


solids, styles = [], []
colour_cache = {}
for (name, x0, y0, z0, x1, y1, z1, rgb) in boxes:
    s = solid(name, x0, y0, z0, x1, y1, z1)
    solids.append(s)
    if rgb not in colour_cache:
        c = e(f"COLOUR_RGB('',{f(rgb[0])},{f(rgb[1])},{f(rgb[2])})")
        fac = e("FILL_AREA_STYLE_COLOUR('',#%d)" % c)
        fa = e("FILL_AREA_STYLE('',(#%d))" % fac)
        sfa = e("SURFACE_STYLE_FILL_AREA(#%d)" % fa)
        sss = e("SURFACE_SIDE_STYLE('',(#%d))" % sfa)
        ssu = e("SURFACE_STYLE_USAGE(.BOTH.,#%d)" % sss)
        colour_cache[rgb] = e(f"PRESENTATION_STYLE_ASSIGNMENT((#{ssu}))")
    styles.append(e(f"STYLED_ITEM('color',(#{colour_cache[rgb]}),#{s})"))
rep = e(f"ADVANCED_BREP_SHAPE_REPRESENTATION('HLK-LD6004',(#{origin_ax},{','.join('#%d' % x for x in solids)}),#{gctx})")
e(f"SHAPE_DEFINITION_REPRESENTATION(#{pds},#{rep})")
e(f"MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION('',({','.join('#%d' % x for x in styles)}),#{gctx})")

hdr = ["ISO-10303-21;", "HEADER;",
       "FILE_DESCRIPTION(('HLK-LD6004 60 GHz radar module, simplified, from Hi-Link dimension drawing'),'2;1');",
       "FILE_NAME('HLK-LD6004_module.step','2026-10-31T10:30:00',('moveOmeter'),('moveOmeter'),'mkstep_ld6004.py','mkstep_ld6004.py','');",
       "FILE_SCHEMA(('AUTOMOTIVE_DESIGN { 1 0 10303 214 1 1 1 1 }'));", "ENDSEC;", "DATA;"]
open(OUT, 'w').write('\n'.join(hdr + L + ['ENDSEC;', 'END-ISO-10303-21;']) + '\n')
print('wrote', OUT, len(boxes), 'solids,', n[0], 'entities')
