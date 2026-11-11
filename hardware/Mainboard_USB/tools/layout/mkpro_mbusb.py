"""Write moveOmeter_MBUSB.kicad_pro from SB1's project file (same design rules and net classes), pointed at
Mainboard-USB: file name, Power net class on +5V, sheet list from the root schematic.
usage: mkpro_mbusb.py <SB1 .kicad_pro> <Mainboard-USB project dir>"""
import json, re, sys, os
src, P = sys.argv[1], sys.argv[2]
p = json.load(open(src))
p['meta']['filename'] = 'moveOmeter_MBUSB.kicad_pro'
ns = p['net_settings']
ns['netclass_patterns'] = [{'netclass': 'Power', 'pattern': '+5V'}]
# 11/6 (John): +5V carries both SB1s (~1.5 A peak) on this 2-layer board, so Power tracks are 1.0 mm; clearance
# 0.175 mm and hole clearance 0.175 mm, as John set on SB1 (a 0.2 mm track between the 1 mm-pitch ZIF pads).
for c in ns['classes']:
    if c['name'] == 'Power':
        c['track_width'] = 1.0
    if c['name'] == 'Default':
        c['clearance'] = 0.175
p['board']['design_settings']['rules']['min_hole_clearance'] = 0.175
root = open(os.path.join(P, 'moveOmeter_MBUSB.kicad_sch')).read()
sheets = re.findall(r'\(sheet \(at [^)]*\) \(size [^)]*\).*?\(uuid "([^"]+)"\) \(property "Sheetname" "([^"]+)"', root)
root_uuid = re.search(r'\(uuid "([^"]+)"\) \(paper', root).group(1)
p['sheets'] = [[root_uuid, 'Root']] + [[u, n] for u, n in sheets]
for t in p.get('schematic', {}).get('top_level_sheets', []):
    t['filename'], t['name'] = 'moveOmeter_MBUSB.kicad_sch', 'moveOmeter_MBUSB'
open(os.path.join(P, 'moveOmeter_MBUSB.kicad_pro'), 'w').write(json.dumps(p, indent=2) + '\n')
print('wrote moveOmeter_MBUSB.kicad_pro; sheets', p['sheets'])
