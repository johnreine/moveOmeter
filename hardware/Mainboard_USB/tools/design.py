"""moveOmeter Mainboard-USB rev A (2026-10-31): every part, net and schematic position.

A passive desk backboard that lets a PC run two SB1 rev B sensor boards with no MCU: 5 V in on a power-only USB-C
(5.1k CC), straight through to both 20-way FFC links; each radar UART to a 1x5 header for a CP2102 USB-TTL module;
each SB1's I2C to a header for its own MCP2221A breakout (no mux; pull-ups are on SB1, DNP here); mic and status lines
to headers for a logic analyser. A reset is an unplug.

The board stands upright behind the two SB1s, parallel to the wall, with the same holder and FFC positions as the
full Mainboard will use. J2 takes SB1-A (left board of the V seen from the room) and J3 takes SB1-B.
"""
from engine import Design
from symlib import build_library

FP_R = 'Resistor_SMD:R_1206_3216Metric_Pad1.30x1.75mm_HandSolder'
FP_C = 'Capacitor_SMD:C_1206_3216Metric_Pad1.33x1.80mm_HandSolder'
FP_C1210 = 'Capacitor_SMD:C_1210_3225Metric_Pad1.33x2.70mm_HandSolder'
FP_CP8 = 'Capacitor_THT:CP_Radial_D8.0mm_P3.50mm'
FP_LED = 'LED_SMD:LED_1206_3216Metric_Pad1.42x1.75mm_HandSolder'
FP_TVS = 'Diode_SMD:D_SMB_Handsoldering'

# FFC pinout (same as SB1, wire n = pin n); {k} = A or B
FFC = ['GND', '+5V', '+5V', 'GND', '{k}_6004_TXO', '{k}_6004_RXI', 'GND', '{k}_2450_TXO', '{k}_2450_RXI', 'GND',
       '{k}_BCLK', 'GND', '{k}_WS', '{k}_DATA', 'GND', '{k}_SDA', '{k}_SCL', '{k}_P20', '{k}_S1', '{k}_S2']


def r_mpn(v):
    return 'RC1206FR-07' + {'5.1k': '5K1', '1k': '1K', '4.7k': '4K7'}[v] + 'L'


C_MPN = {'100n': ('CL31B104KBCNNNC', 'Samsung'), '10u': ('GRM32DR71E106KA12L', 'Murata')}
C_VAL = {'100n': '100nF 50V X7R', '10u': '10uF 25V X7R'}


def build():
    d = Design(build_library())

    def R(sh, v, x, y, a, b, **kw):
        return sh.add('R', v, x, y, {1: a, 2: b}, fp=FP_R, mpn=r_mpn(v), mfr='Yageo', **kw)

    def C(sh, v, x, y, a, b='GND', **kw):
        mpn, mfr = C_MPN[v]
        return sh.add('C', C_VAL[v], x, y, {1: a, 2: b}, fp=FP_C1210 if v == '10u' else FP_C, mpn=mpn, mfr=mfr, **kw)

    S = d.sheet('Mainboard_USB', 'mainboard_usb.kicad_sch', 'USB-C 5 V in, two FFC links, adapter headers')

    # ---- power in
    S.frame(15.24, 15.24, 203.2, 139.7, 'USB-C 5 V in (power only, 5.1k CC: a 5 V 3 A supply gives up to 3 A), straight to both FFCs')
    S.add('USB_C_Power_6P', 'USB4125-GF-A', 50.8, 60.96,
          {'A9': '+5V', 'B9': '+5V', 'A5': 'CC1', 'B5': 'CC2', 'A12': 'GND', 'B12': 'GND', 'SH': 'GND'}, ref='J1',
          mpn='USB4125-GF-A', mfr='GCT', note='Shell legs to GND (desk board)')
    R(S, '5.1k', 101.6, 60.96, 'CC1', 'GND', note='Rd: advertises a sink, so a USB-C source turns on 5 V')
    R(S, '5.1k', 114.3, 60.96, 'CC2', 'GND')
    S.add('D_TVS', 'SMBJ5.0A', 127.0, 60.96, {1: '+5V', 2: 'GND'}, fp=FP_TVS, mpn='SMBJ5.0A', mfr='Littelfuse',
          note='Bench protection only: clamps up to 9.2 V. The full Mainboard gets an over-voltage switch')
    S.add('CP', '470uF 10V polymer', 139.7, 60.96, {1: '+5V', 2: 'GND'}, fp=FP_CP8, mpn='A759KS477M1AAAE014', mfr='KEMET',
          note='Bulk for two SB1s (radar start-up surges) at the end of a USB cable')
    C(S, '10u', 152.4, 60.96, '+5V')
    C(S, '100n', 165.1, 60.96, '+5V')
    R(S, '1k', 101.6, 101.6, '+5V', 'LED_A')
    S.add('LED', 'green', 114.3, 101.6, {2: 'LED_A', 1: 'GND'}, fp=FP_LED, mpn='LTST-C150GKT', mfr='Lite-On', note='Power on')
    for i, n in enumerate(['+5V', 'GND']):
        S.add('PWR_FLAG', 'PWR_FLAG', 139.7 + i * 15.24, 109.22, {1: n})
    S.text('A reset is an unplug: there is no switching here. Each SB1 draws up to ~1 A.', 22.86, 132.08)

    # ---- FFC links
    S.frame(215.9, 15.24, 403.86, 139.7, 'FFC links: J2 to SB1-A, J3 to SB1-B, both to SB1 J7; both reversed, pad n = wire 21 - n')
    for ref, x, k in (('J2', 256.54, 'A'), ('J3', 347.98, 'B')):
        # 11/7: J3 is wired in reverse (pad n = FFC wire 21 - n) to match SB1's J7, which was reversed so that SB1's two
        # ZIFs carry each signal at the same height. Pad heights still match pad for pad through the flat, untwisted
        # Type A cable: GND sits at the bottom of all four ZIFs. See SB1 README, FFC link.
        # 11/8: SB1 has one ZIF now (J7). J2 is turned round to open toward -X (SB1-A's cable swings in from the left), which
        # flips its pin order, so it is reversed too, exactly like J3.
        rev = True
        nets = {(20 - i if rev else i + 1): n.format(k=k) for i, n in enumerate(FFC)}
        nets['MP'] = 'GND'
        S.add('FFC_ZIF_20_REV' if rev else 'FFC_ZIF_20', '200528-0200', x, 71.12, nets, ref=ref, mpn='200528-0200', mfr='Molex',
              note=f'Molex Easy-On 1.00 mm, bottom contact, 20-way. Stands on end on the front face, inside the V; both open toward '
                   f'-X (11/8). GND at the bottom. ' + ('Pad n = FFC wire 21 - n (reversed, as SB1 J7)' if rev else 'Pad n = FFC wire n'))
    S.text('TXO = radar out (to the adapter RXD), RXI = radar in (from the adapter TXD). 3.3 V logic.', 220.98, 132.08)

    # ---- UART headers
    S.frame(15.24, 152.4, 203.2, 284.48, 'Radar UARTs to four CP2102 USB-TTL sticks, plugged into right-angle sockets (3V3 / TXD / RXD / GND / 5V; 3V3 and 5V not connected)')
    for ref, x, k, r, baud in (('J4', 45.72, 'A', '6004', 115200), ('J5', 91.44, 'A', '2450', 256000),
                               ('J6', 137.16, 'B', '2450', 256000), ('J7', 182.88, 'B', '6004', 115200)):
        S.add('CP2102_Header', f'LD{r}-{k}', x, 195.58, {1: 'NC', 2: f'{k}_{r}_TXD', 3: f'{k}_{r}_TXO', 4: 'GND', 5: 'NC'},
              ref=ref, fp='MBUSB:CP2102_Stick_Socket_1x05_P2.54mm_Horizontal', mpn='PPTC051LGBN-RC', mfr='Sullins',
              note=f'SB1-{k} LD{r}: {baud} 8N1. Right-angle socket: the CP2102 stick (John\'s, 3V3 / TXD / RXD / GND / +5V) '
                   f'plugs in chip side down and lies flat, USB plug past the bottom edge')
    S.text('1k in series with each adapter TXD (R8-R11, John 10/31): a powered adapter can no longer hold an unpowered radar up through its RX clamp.', 22.86, 279.4)
    S.text('CP2102 standard baud table includes 256000 (actual 255319, -0.27 %), so it runs the LD2450.', 22.86, 271.78)

    # ---- I2C, mic, status, holes
    S.frame(215.9, 152.4, 403.86, 284.48, 'I2C to an MCP2221A per SB1 (no mux), mic and status headers, mounting')
    for ref, x, k in (('J8', 256.54, 'A'), ('J9', 304.8, 'B')):
        S.add('I2C_Header', f'I2C-{k}', x, 182.88, {1: 'GND', 2: f'{k}_3V3', 3: f'{k}_SDA', 4: f'{k}_SCL'}, ref=ref,
              mpn='1x4 2.54 mm header', mfr='Sullins', note=f'SB1-{k}: EEPROM 0x50, VEML7700 0x10')
        R(S, '4.7k', x - 22.86, 215.9, f'{k}_3V3', f'{k}_SDA', dnp=True, note='DNP: SB1 has its own pull-ups')
        R(S, '4.7k', x - 10.16, 215.9, f'{k}_3V3', f'{k}_SCL', dnp=True)
    for ref, x, k in (('J10', 350.52, 'A'), ('J11', 396.24, 'B')):
        S.add('Mic_Header', f'mics-{k}', x, 182.88, {1: f'{k}_BCLK', 2: f'{k}_WS', 3: f'{k}_DATA', 4: 'GND'}, ref=ref,
              mpn='1x4 2.54 mm header', mfr='Sullins', note=f'SB1-{k} mics: BCLK and WS in, one DATA line (left + right slots)')
    for ref, x, k in (('J12', 350.52, 'A'), ('J13', 396.24, 'B')):
        S.add('Status_Header', f'status-{k}', x, 228.6, {1: f'{k}_P20', 2: f'{k}_S1', 3: f'{k}_S2', 4: 'GND'}, ref=ref,
              mpn='1x4 2.54 mm header', mfr='Sullins')
    # 1k in series with each adapter TXD (John, 10/31). Added after the I2C pull-ups so existing refs keep their numbers.
    for x, k, r in ((45.72, 'A', '6004'), (91.44, 'A', '2450'), (137.16, 'B', '2450'), (182.88, 'B', '6004')):
        R(S, '1k', x, 238.76, f'{k}_{r}_TXD', f'{k}_{r}_RXI',
          note='Adapter TXD to radar RX: limits the current into an unpowered radar\'s RX clamp' if (k, r) == ('A', '6004') else '')
    S.add('VEML7700_Breakout', 'Adafruit 4162 VEML7700', 271.78, 241.3,
          {1: 'A_3V3', 2: 'NC', 3: 'GND', 4: 'A_SCL', 5: 'A_SDA'}, ref='J14',
          mpn='1x PPTC051LFBN-RC socket + Adafruit 4162 breakout', mfr='Sullins',
          note='Bench light sensor (John, 10/31): VEML7700 at 0x10 on I2C-A, powered from the I2C-A adapter\'s 3.3 V. '
               'Front of the wing, below the V, facing the room. SB1-A\'s own VEML7700 (U4) is DNP: same address')
    for i in range(10):
        S.add('MountingHole_M3', 'M3', 228.6 + i * 15.24, 266.7, {}, ref=f'H{i + 1}', bom=False,
              note=('Corner' if i < 4 else 'SB1 holder' if i < 8 else 'Desk stand (wing)'))
    S.text('The I2C, mic and status lines are on SB1\'s side of 100 ohm / 33 ohm series resistors; nothing to add here.', 220.98, 279.4)

    import vendor
    vendor.apply(d)
    return d
