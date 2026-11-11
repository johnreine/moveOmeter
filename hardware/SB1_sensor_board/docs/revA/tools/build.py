import os, sys, json, csv, collections
from design import build
from engine import uid, snap, PROJECT, POWER_NETS
from symlib import G

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out'
os.makedirs(OUT, exist_ok=True)
d = build()

# ------------------------------------------------------------------ checks
nets = d.netlist()
problems = []
singles = [n for n, c in nets.items() if len(c) < 2]
for n in singles:
    problems.append(f'net {n} has one connection: {nets[n]}')

# geometric collision check per sheet: every stub endpoint / pin endpoint belongs to one net
for sh in d.sheets:
    pts = {}
    segs = []
    for p in sh.parts:
        for pin in p.sym.pins:
            net = p.nets[pin.num]
            ex, ey = p.pin_end(pin)
            key = (ex, ey)
            tag = net if net != 'NC' else f'NC:{p.ref}.{pin.num}'
            pts.setdefault(key, set()).add(tag)
            if net != 'NC':
                dx, dy = p.pin_out(pin)
                sx, sy = snap(ex + dx * G), snap(ey + dy * G)
                pts.setdefault((sx, sy), set()).add(tag)
                segs.append(((ex, ey), (sx, sy), tag))
    for k, v in pts.items():
        if len(v) > 1:
            problems.append(f'{sh.name}: point {k} shared by {v}')
    # point lying on another net's segment interior
    for (a, b, tag) in segs:
        for k, v in pts.items():
            if tag in v:
                continue
            (x1, y1), (x2, y2) = a, b
            if min(x1, x2) - 1e-6 <= k[0] <= max(x1, x2) + 1e-6 and min(y1, y2) - 1e-6 <= k[1] <= max(y1, y2) + 1e-6:
                if (x1 == x2 and abs(k[0] - x1) < 1e-6) or (y1 == y2 and abs(k[1] - y1) < 1e-6):
                    problems.append(f'{sh.name}: point {k} {v} touches segment of {tag}')
    # bounding check vs paper
    W, H = {'A3': (420, 297), 'A2': (594, 420)}[sh.paper]
    for k in pts:
        if not (5 < k[0] < W - 5 and 5 < k[1] < H - 5):
            problems.append(f'{sh.name}: point {k} outside paper')

refs = [p.ref for p in d.parts]
dups = [r for r, c in collections.Counter(refs).items() if c > 1]
if dups:
    problems.append(f'duplicate refs {dups}')

print(f'{len(d.parts)} parts, {len(nets)} nets, {len(d.sheets)} sheets')
for pr in problems:
    print('PROBLEM', pr)

# ------------------------------------------------------------------ emit schematics
for sh in d.sheets:
    with open(os.path.join(OUT, sh.file), 'w') as f:
        f.write(d.emit_sheet(sh))
with open(os.path.join(OUT, f'{PROJECT}.kicad_sch'), 'w') as f:
    f.write(d.emit_root('moveOmeter sensor board SB1'))

# symbol library
os.makedirs(os.path.join(OUT, 'lib'), exist_ok=True)
with open(os.path.join(OUT, 'lib', 'SB1.kicad_sym'), 'w') as f:
    f.write('(kicad_symbol_lib (version 20231120) (generator "sb1_gen") (generator_version "1.0")\n')
    for name in sorted(d.lib):
        f.write(d.lib[name].sexpr() + '\n')
    f.write(')\n')

# netlist report
with open(os.path.join(OUT, 'netlist_report.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['Net', 'Ref', 'Pin', 'Pin name', 'Sheet'])
    for n in sorted(nets):
        for c in sorted(nets[n]):
            w.writerow([n, *c])

# BOM
groups = collections.OrderedDict()
first = {}
for p in d.parts:
    if p.sym.power or not p.bom:
        continue
    key = (p.value, p.fp, p.mpn, p.mfr, p.dnp)
    groups.setdefault(key, []).append(p.ref)
    first.setdefault(key, p)


def natkey(r):
    import re
    m = re.match(r'([A-Z#]+)(\d+)', r)
    return (m.group(1), int(m.group(2))) if m else (r, 0)


def money(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


rows = []
for (val, fp, mpn, mfr, dnp), rs in groups.items():
    rs = sorted(rs, key=natkey)
    p = first[(val, fp, mpn, mfr, dnp)]
    f = p.fields
    unit = money(f.get('Price'))
    ext = round(unit * len(rs), 2) if (unit is not None and not dnp) else ''
    rows.append([', '.join(rs), len(rs), val, mfr, mpn, fp.split(':')[-1], 'DNP' if dnp else '',
                 f.get('Vendor Part #', ''), f.get('Price', ''), ext, f.get('Vendor Link', ''), p.datasheet if p.datasheet != '~' else ''])
rows.sort(key=lambda r: natkey(r[0].split(',')[0]))

# parts that are ordered with a schematic part but are not symbols (module sockets, jumper shunts)
import vendor
extra = collections.OrderedDict()
for p in d.parts:
    for (xmpn, xmfr, xqty) in p.extras:
        e = extra.setdefault(xmpn, {'mfr': xmfr, 'qty': 0, 'refs': []})
        e['qty'] += xqty
        e['refs'].append(p.ref)
for xmpn, e in extra.items():
    info = vendor.DK.get(xmpn, {})
    unit = money(info.get('price'))
    ext = round(unit * e['qty'], 2) if unit is not None else ''
    rows.append([f'(with {", ".join(sorted(e["refs"], key=natkey))})', e['qty'], info.get('desc', ''), e['mfr'], xmpn, '', '',
                 info.get('pn', ''), info.get('price', ''), ext, info.get('link', ''), info.get('ds', '')])

total = round(sum(r[9] for r in rows if isinstance(r[9], (int, float))), 2)
missing = [r[4] for r in rows if r[6] != 'DNP' and r[8] in ('', None)]
with open(os.path.join(OUT, 'bom_board.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['Refs', 'Qty per board', 'Value', 'Manufacturer', 'MPN', 'Footprint', 'Fit',
                'Vendor Part #', 'Price (qty 1, USD)', 'Ext price per board (USD)', 'Vendor Link', 'Datasheet'])
    w.writerows(rows)
    w.writerow([])
    w.writerow(['Total per board at qty-1 prices (fitted parts, sockets and shunts included)', '', '', '', '', '', '', '', '', total, '', ''])
    w.writerow([f'Prices: {vendor.PRICE_NOTE}', '', '', '', '', '', '', '', '', '', '', ''])
print(f'BOM: {len(rows)} lines, board total ${total} at qty-1 prices; lines without a price: {missing}')
json.dump({'rows': rows}, open(os.path.join(OUT, 'bom.json'), 'w'), indent=1)

print('written to', OUT)
