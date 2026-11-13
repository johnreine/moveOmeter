"""Ordering files for SB1 rev B (11/10), from bom.json (build.py) and the board (mount type and side per part).
usage: python3 tools/mkorders.py <project dir>
Writes
  fab/SB1_revB_assembly_BOM.csv     one line per part type, for an assembly quote: designators, qty, description,
                                    package, manufacturer + MPN, vendor + vendor PN, qty-1 price, SMT/THT, side, fit
  purchase/SB1_revB_digikey_upload.csv   DigiKey BOM Manager upload, quantities per board (set the build quantity
                                    there): every fitted part, J4's second socket and the LD6004's pins, the FFC cable
  purchase/SB1_revB_other_parts.csv parts DigiKey doesn't sell (the two radar modules), with links
Prices are DigiKey qty-1 (see vendor.PRICE_NOTE)."""
import csv, json, os, re, sys
P = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(P, 'tools')); sys.path.insert(0, os.path.join(P, 'tools', 'layout'))
import vendor, sx
from sx import find, findall

MFR = {'TI': 'Texas Instruments', 'Samsung': 'Samsung Electro-Mechanics', 'Yageo': 'YAGEO', 'Murata': 'Murata Electronics',
       'Sullins': 'Sullins Connector Solutions', 'Lite-On': 'Lite-On Inc.', 'Microchip': 'Microchip Technology',
       'Vishay': 'Vishay Semiconductor Opto Division', 'Bourns': 'Bourns Inc.', 'Littelfuse': 'Littelfuse Inc.'}
DESC = {
    'GRM32DR71E106KA12L': 'Capacitor, ceramic, 10 uF 25 V X7R, 1210',
    'CL31B104KBCNNNC': 'Capacitor, ceramic, 100 nF 50 V X7R, 1206',
    'CC1206KKX7R9BB105': 'Capacitor, ceramic, 1 uF 50 V X7R, 1206',
    'CC1206CRNPO9BN6R8': 'Capacitor, ceramic, 6.8 pF 50 V C0G, 1206',
    'GRM32ER61E226KE15L': 'Capacitor, ceramic, 22 uF 25 V X5R, 1210',
    'SMBJ5.0A': 'TVS diode, 5.0 V standoff, unidirectional, SMB',
    'LTST-C150KRKT': 'LED, red, 1206',
    'LSMGA321616T221NG': 'Ferrite bead, 220 ohm @ 100 MHz, 4 A, 1206',
    '6049': 'Adafruit I2S MEMS microphone breakout (ICS-43434), with its 1x6 header',
    'LPPB051NFFN-RC': 'Socket, 1x5, 1.27 mm, through-hole (LD6004 module)',
    'NPPN042AFCN-RC': 'Socket, 2x4, 2.00 mm, through-hole (LD2450 module)',
    'PEC03SAAN': 'Pin header, 1x3, 2.54 mm, through-hole',
    '200528-0200': 'FFC/FPC connector, 20-way, 1.00 mm, bottom contact, ZIF, right angle, SMT',
    'SRN4018-2R2M': 'Inductor, 2.2 uH, shielded, 4.0 x 4.0 mm',
    'RC1206FR-071KL': 'Resistor, 1 k 1%, 1206', 'RC1206FR-0733RL': 'Resistor, 33 ohm 1%, 1206',
    'RC1206FR-074K7L': 'Resistor, 4.7 k 1%, 1206', 'RC1206JR-070RL': 'Resistor, 0 ohm jumper, 1206',
    'RC1206FR-07453KL': 'Resistor, 453 k 1%, 1206', 'RC1206FR-07100KL': 'Resistor, 100 k 1%, 1206',
    'RC1206FR-07100RL': 'Resistor, 100 ohm 1%, 1206',
    'TLV62569DBVR': 'Buck converter, 2 A, SOT-23-5', 'LP5907MFX-3.3/NOPB': 'LDO, 3.3 V 250 mA, SOT-23-5',
    'VEML7700-TT': 'Ambient light sensor, I2C', '24AA256UID-I/SN': 'EEPROM, 256 Kbit I2C, unique ID, SOIC-8',
    'GRPB051VWVN-RC': 'Pin header, 1x5, 1.27 mm (soldered onto the LD6004 module, not the board)',
    '0150390357': 'FFC jumper, 20-way, 1.00 mm, 51 mm, same-side contacts (Type A)',
}
PKG = [('C_1206', '1206'), ('R_1206', '1206'), ('LED_1206', '1206'), ('L_1206', '1206'), ('C_1210', '1210'),
       ('D_SMB', 'SMB (DO-214AA)'), ('L_Bourns-SRN4018', 'SRN4018 (4.0 x 4.0 mm)'), ('SOT-23-5', 'SOT-23-5'),
       ('SOIC-8', 'SOIC-8'), ('Molex_200528', '20-pin 1.00 mm FFC ZIF'), ('VEML7700', 'VEML7700 (6.8 x 2.35 mm)'),
       ('HLK-LD6004', '2x 1x5 1.27 mm sockets'), ('HLK-LD2450', '2x4 2.00 mm socket'), ('PinHeader_1x03', '1x3 2.54 mm'),
       ('Adafruit_I2S_Mic', 'breakout, 1x6 2.54 mm')]
NOTE = {
    'J1': 'Breakout soldered flat on the back with its own header pins through both boards, overhanging the top edge '
          '8.2 mm, sound hole facing the room. Quote as hand-solder, or leave it for us (customer-fit)',
    'J4': 'Two identical 1x5 sockets per board (both rows of J4): quantity is 2 per board',
    'J7': 'Back side, opening toward the board centre; actuator must be free',
}


def pkg(fp):
    return next((v for k, v in PKG if k in fp), fp)


def natkey(r):
    m = re.match(r'([A-Z]+)(\d+)', r)
    return (m.group(1), int(m.group(2))) if m else (r, 0)


rows = json.load(open(os.path.join(P, 'bom.json')))['rows']
pcb = os.path.join(P, 'moveOmeter_SB1.kicad_pcb')
b = sx.parse(open(pcb).read())
fpinfo = {}
for fp in findall(b, 'footprint'):
    ref = [str(p[2]) for p in findall(fp, 'property') if p[1] == 'Reference'][0]
    at = find(fp, 'attr'); a = [str(x) for x in at[1:]] if at else []
    fpinfo[ref] = ('THT' if 'through_hole' in a else 'SMT', 'Top' if str(find(fp, 'layer')[1]) == 'F.Cu' else 'Bottom')
os.makedirs(os.path.join(P, 'fab'), exist_ok=True); os.makedirs(os.path.join(P, 'purchase'), exist_ok=True)

# ---------------------------------------------------------------- assembly-quote BOM
H = ['Line', 'Designators', 'Qty per board', 'Value', 'Description', 'Package', 'Footprint', 'Manufacturer',
     'Manufacturer Part Number', 'Vendor', 'Vendor Part Number', 'Unit Price (qty 1, USD)', 'Ext Price per board (USD)',
     'Mount', 'Side', 'Assemble', 'Vendor Link', 'Notes']
out, total, smt, tht = [], 0.0, 0, 0
for r in rows:
    refs, qty, val, mfr, mpn, fp, fit, vend, vpn, price, ext, link, ds = r
    if refs.startswith('(with'):
        continue
    rl = [x.strip() for x in refs.split(',')]
    mount, side = fpinfo[rl[0]]
    if rl == ['J4']:
        qty = 2
    unit = float(price) if price else None
    e = f'{unit * qty:.2f}' if (unit is not None and fit != 'DNP') else ''
    if e != '':
        total += float(e)
    assemble = 'DNP (do not place)' if fit == 'DNP' else ('Yes, SMT' if mount == 'SMT' else 'Yes, THT')
    if fit != 'DNP':
        smt += qty if mount == 'SMT' else 0; tht += qty if mount == 'THT' else 0
    note = NOTE.get(rl[0], NOTE.get('J1') if rl[0] == 'J2' else '')
    out.append([len(out) + 1, refs, qty, val, DESC.get(mpn, val), pkg(fp), fp, MFR.get(mfr, mfr), mpn, vend, vpn,
                price, e, mount, side, assemble, link, note])
with open(os.path.join(P, 'fab', 'SB1_revB_assembly_BOM.csv'), 'w', newline='') as f:
    w = csv.writer(f); w.writerow(H); w.writerows(out); w.writerow([])
    w.writerow(['', f'Total per board at qty-1 prices: ${total:.2f} (DNP lines excluded)'])
    w.writerow(['', f'Fitted placements per board: {smt} SMT (all on the bottom side), {tht} THT; '
                    f'DNP: C8, U4 (front). Not parts: JP1-JP3 (solder jumpers), H1-H4 (holes)'])
    w.writerow(['', f'Prices: {vendor.PRICE_NOTE}'])

# ---------------------------------------------------------------- DigiKey upload (per board)
dk = {}
def add(pn, mpn, mfr, qty, ref, desc):
    e = dk.setdefault(pn, {'mpn': mpn, 'mfr': MFR.get(mfr, mfr), 'qty': 0, 'refs': [], 'desc': desc})
    e['qty'] += qty; e['refs'].append(ref)
for r in rows:
    refs, qty, val, mfr, mpn, fp, fit, vend, vpn, price, ext, link, ds = r
    if fit == 'DNP' or vend != 'DigiKey':
        continue
    ref = refs.replace('(with ', '').replace(')', '')
    if refs.startswith('(with') and mpn == 'GRPB051VWVN-RC':
        ref = 'LD6004 module pins'
    add(vpn, mpn, mfr, int(qty), ref, DESC.get(mpn, val))
for mpn, mfr, q, note in vendor.ORDER_EXTRAS:
    i = vendor.DK[mpn]
    add(i['pn'], mpn, mfr, q, 'FFC to Mainboard', DESC.get(mpn, i['desc']))
with open(os.path.join(P, 'purchase', 'SB1_revB_digikey_upload.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['Quantity', 'Digi-Key Part Number', 'Manufacturer Part Number', 'Manufacturer', 'Customer Reference', 'Description'])
    for pn, e in dk.items():
        refs = sorted(set(', '.join(e['refs']).split(', ')), key=natkey)
        w.writerow([e['qty'], pn, e['mpn'], e['mfr'], ('SB1 ' + ', '.join(refs))[:48], e['desc']])
dk_total = sum(e['qty'] * float(vendor.DK.get(e['mpn'], vendor.DK.get(e['mpn'], {'price': 0}))['price']) for e in dk.values())

# ---------------------------------------------------------------- not at DigiKey
OTHER = [
    ['HLK-LD6004', 'Hi-Link', 1, 'J4', '60 GHz radar module (plugs into J4; solder the two 1x5 1.27 mm headers onto it)',
     'OpenELAB', 'https://openelab.com/products/hlk-ld6004-60g-radar-module-multi', '14.16',
     'Ships from China; Hi-Link store: https://www.hlktech.cn/en/Goods-347.html'],
    ['HLK-LD2450', 'Hi-Link', 1, 'J5', '24 GHz radar module, comes with its 2x4 2.00 mm header (plugs into J5)',
     'OpenELAB', 'https://openelab.com/products/hilink-ld2450-motion-tracking-radar', '8.89',
     'US warehouse; Hi-Link sample price on Alibaba ~$6'],
]
with open(os.path.join(P, 'purchase', 'SB1_revB_other_parts.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['Part', 'Manufacturer', 'Qty per board', 'For', 'Description', 'Vendor', 'Link', 'Unit price (USD)', 'Notes'])
    w.writerows(OTHER)
print(f'orders: assembly BOM {len(out)} lines (${total:.2f}/board), DigiKey upload {len(dk)} lines '
      f'(${dk_total:.2f}/board incl. FFC and module pins), other parts {len(OTHER)}')
