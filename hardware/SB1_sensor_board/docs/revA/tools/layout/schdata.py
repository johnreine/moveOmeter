import sx, json, csv, glob, os
ROOT = os.environ.get('SB1_ROOT', 'moveOmeter_SB1.kicad_sch')


def _first(*cands):
    return next((c for c in cands if c and os.path.exists(c)), cands[-1])


_HERE = os.path.dirname(os.path.abspath(__file__))
_UP2 = os.path.dirname(os.path.dirname(_HERE))          # <project> when this file is <project>/tools/layout/schdata.py
# Project folder: SB1_PROJ, else the project this script sits in, else Claude's workspace copy
P = os.environ.get('SB1_PROJ') or _first(_UP2 if os.path.exists(os.path.join(_UP2, ROOT)) else None,
                                         '/home/claude/sb1/proj')
# KiCad's footprint library: SB1_FPDIR, else Claude's workspace copy, else the macOS KiCad install
FPDIR = os.environ.get('SB1_FPDIR') or _first('/mnt/user-data/uploads/footprints',
                                              '/Applications/KiCad/KiCad.app/Contents/SharedSupport/footprints')
# The moveOmeter V1 board, whose layer table and stackup the new board copies
V1 = os.environ.get('SB1_V1') or _first(
    os.path.join(P, '..', '..', 'pictureFrame', 'electrical', 'moveOmeterV1', 'moveOmeterV1.kicad_pcb'),
    '/mnt/user-data/uploads/2025_work--moveOmeter/pictureFrame/electrical/moveOmeterV1/moveOmeterV1.kicad_pcb')

def load():
    root = sx.parse(open(f'{P}/{ROOT}').read())
    root_uuid = sx.find(root, 'uuid')[1]
    sheets = {}
    for sh in sx.findall(root, 'sheet'):
        props = {p[1]: p[2] for p in sx.findall(sh, 'property')}
        sheets[props['Sheetfile']] = (sx.find(sh, 'uuid')[1], props['Sheetname'])
    syms = {}
    glabels, llabels, powers = set(), {}, set()
    for f, (suuid, sname) in sheets.items():
        e = sx.parse(open(f'{P}/{f}').read())
        for g in sx.findall(e, 'global_label'):
            glabels.add(g[1])
        for l in sx.findall(e, 'label'):
            llabels.setdefault(l[1], set()).add(sname)
        for s in sx.findall(e, 'symbol'):
            lib_id = sx.find(s, 'lib_id')[1]
            props = {}
            for p in sx.findall(s, 'property'):
                props[str(p[1])] = str(p[2])
            ref = props['Reference']
            if ref.startswith('#'):
                powers.add(props['Value'])
                continue
            ob = sx.find(s, 'on_board')
            if ob and ob[1] == 'no':
                continue
            inbom = sx.find(s, 'in_bom')
            dnp = sx.find(s, 'dnp')
            syms[ref] = dict(ref=ref, lib_id=lib_id, props=props, uuid=str(sx.find(s, 'uuid')[1]),
                             sheet_uuid=str(suuid), sheetname=str(sname), sheetfile=f,
                             in_bom=(inbom[1] == 'yes') if inbom else True, dnp=(dnp[1] == 'yes') if dnp else False)
    return syms, glabels, llabels, powers, sheets

if __name__ == '__main__':
    syms, gl, ll, pw, sheets = load()
    print(len(syms), 'symbols on board'); print(sheets); print('powers', sorted(pw))
    print('local-only labels:', sorted(k for k in ll if k not in gl and k not in pw)[:200])
    print('both local & global:', sorted(k for k in ll if k in gl))
    ex = syms['C2']; print(json.dumps(ex, indent=0)[:900])
    print(sorted({k for s in syms.values() for k in s['props']}))
