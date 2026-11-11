"""Flatten a 3MF file into world-space coloured triangles: returns list of (rgb, [(v0,v1,v2), ...])."""
import zipfile, re
import xml.etree.ElementTree as ET

NS = {'c': 'http://schemas.microsoft.com/3dmanufacturing/core/2015/02',
      'm': 'http://schemas.microsoft.com/3dmanufacturing/material/2015/02',
      'p': 'http://schemas.microsoft.com/3dmanufacturing/production/2015/06'}


def mat(s):
    if not s:
        return [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
    return [float(v) for v in s.split()]


def mul(a, b):
    """3MF 3x4 row-vector transforms: p' = p * A, then * B  -> combined a then b"""
    A = [[a[0], a[1], a[2]], [a[3], a[4], a[5]], [a[6], a[7], a[8]], [a[9], a[10], a[11]]]
    B = [[b[0], b[1], b[2]], [b[3], b[4], b[5]], [b[6], b[7], b[8]], [b[9], b[10], b[11]]]
    R = []
    for i in range(4):
        row = [sum(A[i][k] * B[k][j] for k in range(3)) + (B[3][j] if i == 3 else 0) for j in range(3)]
        R += row
    return R


def app(m, v):
    x, y, z = v
    return (x * m[0] + y * m[3] + z * m[6] + m[9], x * m[1] + y * m[4] + z * m[7] + m[10], x * m[2] + y * m[5] + z * m[8] + m[11])


def hexrgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def load(path):
    z = zipfile.ZipFile(path)
    name = [n for n in z.namelist() if n.endswith('.model')][0]
    root = ET.fromstring(z.read(name))
    res = root.find('c:resources', NS)
    colors = {}
    for cg in res.findall('m:colorgroup', NS):
        colors[cg.get('id')] = [hexrgb(c.get('color')) for c in cg.findall('m:color', NS)]
    bases = {}
    for bm in res.findall('c:basematerials', NS):
        bases[bm.get('id')] = [hexrgb(b.get('displaycolor')) for b in bm.findall('c:base', NS)]
    pal = {**colors, **bases}
    objs = {o.get('id'): o for o in res.findall('c:object', NS)}
    out = {}

    def emit(oid, M, inh=None):
        o = objs[oid]
        mesh = o.find('c:mesh', NS)
        opid, op1 = o.get('pid'), o.get('pindex')
        if mesh is not None:
            vs = [(float(v.get('x')), float(v.get('y')), float(v.get('z'))) for v in mesh.find('c:vertices', NS)]
            vs = [app(M, v) for v in vs]
            for t in mesh.find('c:triangles', NS):
                pid = t.get('pid') or opid
                p1 = t.get('p1') or op1 or '0'
                rgb = pal.get(pid, [(0.6, 0.6, 0.6)])[int(p1)] if pid in pal else (0.6, 0.6, 0.6)
                out.setdefault(rgb, []).append((vs[int(t.get('v1'))], vs[int(t.get('v2'))], vs[int(t.get('v3'))]))
        comps = o.find('c:components', NS)
        if comps is not None:
            for c in comps:
                emit(c.get('objectid'), mul(mat(c.get('transform')), M))

    for it in root.find('c:build', NS):
        emit(it.get('objectid'), mat(it.get('transform')))
    return out


def bbox(tris):
    pts = [p for ts in tris.values() for t in ts for p in t]
    return [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]
