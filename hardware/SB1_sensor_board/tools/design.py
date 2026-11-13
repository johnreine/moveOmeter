"""moveOmeter SB1 sensor board, rev B (2026-10-31): every part, net and schematic position.

Rev B is the minimal, hand-solderable sensor assembly used unchanged in the nightlight and the frame (John, 10/26-10/31).
On the front: an LD6004 (60 GHz) with its 3.3 V buck, an LD2450 (24 GHz) mounted upright, two Adafruit I2S mic
breakouts at the top edge and a VEML7700 light sensor. On the back: a 24AA256UID ID EEPROM, an LP5907 3.3 V LDO for
the mics / EEPROM / light sensor, the I2C pull-ups, series resistors on every link signal, per-radar isolation links
and one 20-way FFC ZIF connector (J7, at the left edge seen from the front). 11/8 (John): one connector per board
instead of two in parallel, so no bus and no stubs; on SB1-A it sits near the apex of the V and the cable runs out along
the back and loops round, on SB1-B it is at the outer end as before.

Power switching, current monitoring and back-power protection moved to the backboards (Mainboard-USB, Mainboard).
Rev A (USB-C + CH340C per sensor, muxes, monitors) is kept in docs/revA with the tools that built it.
"""
from engine import Design
from symlib import build_library

FP_R = 'Resistor_SMD:R_1206_3216Metric_Pad1.30x1.75mm_HandSolder'
FP_C = 'Capacitor_SMD:C_1206_3216Metric_Pad1.33x1.80mm_HandSolder'
FP_C1210 = 'Capacitor_SMD:C_1210_3225Metric_Pad1.33x2.70mm_HandSolder'
C_1210 = {'10u', '22u'}
FP_FB1206 = 'Inductor_SMD:L_1206_3216Metric_Pad1.22x1.90mm_HandSolder'
FP_L = 'Inductor_SMD:L_Bourns-SRN4018'
FP_LED = 'LED_SMD:LED_1206_3216Metric_Pad1.42x1.75mm_HandSolder'
FP_SJ = 'Jumper:SolderJumper-2_P1.3mm_Open_RoundedPad1.0x1.5mm'
FP_TVS = 'Diode_SMD:D_SMB_Handsoldering'

# FFC pinout (wire n = pin n), agreed 10/27 for the ribbon and kept for the 20-way FFC (10/31)
FFC = ['GND', '+5V', '+5V', 'GND', 'L_6004_TX', 'L_6004_RX', 'GND', 'L_2450_TX', 'L_2450_RX', 'GND',
       'L_BCLK', 'GND', 'L_WS', 'L_MIC_DATA', 'GND', 'I2C_SDA', 'I2C_SCL', 'L_6004_P20', 'SPARE1', 'SPARE2']


def r_mpn(v):
    if v == '0':
        return 'RC1206JR-070RL'
    code = {'4.7k': '4K7', '1k': '1K', '100k': '100K', '453k': '453K', '33': '33R', '100': '100R'}[v]
    return f'RC1206FR-07{code}L'


C_MPN = {'100n': ('CL31B104KBCNNNC', 'Samsung'), '10u': ('GRM32DR71E106KA12L', 'Murata'),
         '22u': ('GRM32ER61E226KE15L', 'Murata'), '1u': ('CC1206KKX7R9BB105', 'Yageo'),
         '6.8p': ('CC1206CRNPO9BN6R8', 'Yageo')}
C_VAL = {'100n': '100nF 50V X7R', '10u': '10uF 25V X7R', '22u': '22uF 25V X5R', '1u': '1uF 50V X7R',
         '6.8p': '6.8pF C0G'}


def build():
    d = Design(build_library())

    def R(sh, v, x, y, a, b, **kw):
        return sh.add('R', v, x, y, {1: a, 2: b}, fp=FP_R, mpn=r_mpn(v), mfr='Yageo', **kw)

    def C(sh, v, x, y, a, b='GND', **kw):
        mpn, mfr = C_MPN[v]
        return sh.add('C', C_VAL[v], x, y, {1: a, 2: b}, fp=FP_C1210 if v in C_1210 else FP_C, mpn=mpn, mfr=mfr, **kw)

    def FB(sh, x, y, a, b):
        return sh.add('FB', '220R@100MHz 4A', x, y, {1: a, 2: b}, fp=FP_FB1206, mpn='LSMGA321616T221NG', mfr='Taiyo Yuden')

    def link(sh, x, y, a, b, k, jp):
        """Per-radar isolation: a fitted 0 ohm 1206 with an open solder jumper beside it. Remove the resistor to run
        the other radar alone; bridge the jumper to put this one back without a resistor."""
        R(sh, '0', x, y, a, b, note=f'Isolation link for the {k}: fitted. Remove it to run the other radar alone')
        sh.add('SolderJumper_2', f'{k} link', x + 12.7, y, {1: a, 2: b}, ref=jp, fp=FP_SJ, bom=False,
               note='Open by default; bridge it instead of refitting the 0 ohm link')

    # =================================================================== POWER, LINK, MICS, I2C
    P = d.sheet('Power_IO', 'power_io.kicad_sch', 'FFC link, 5 V in, 3.3 V, mics, EEPROM, light sensor')

    P.frame(15.24, 15.24, 203.2, 139.7, 'Link to the mainboard: one 20-way FFC ZIF (J7, left edge)')
    for ref, x in (('J7', 101.6),):
        # 11/7: J7 is wired in reverse (pad n = wire 21 - n). J3 and J7 stand on end turned 180 deg to each other (both open
        # toward the board centre), so with straight wiring their pin orders ran in opposite directions and every net
        # between them had to cross. Reversed, both carry GND at the bottom and the bus between them can lie flat.
        rev = ref == 'J7'
        nets = {(20 - i if rev else i + 1): n for i, n in enumerate(FFC)}
        nets['MP'] = 'GND'
        P.add('FFC_ZIF_20_REV' if rev else 'FFC_ZIF_20', '200528-0200', x, 71.12, nets, ref=ref, mpn='200528-0200', mfr='Molex',
              note='Molex Easy-On 1.00 mm, back flip, ear-tab lock: use eared 20-way 0.3 mm FFC, 51 mm, Type A')
    P.text('J7: wire n = pin 21 - n (reversed, 11/7). +5 V on wires 2-3. TX = radar out, RX = radar in (3.3 V).', 22.86, 127.0)
    P.text('Series resistors sit at the radars / mics (outputs) and at the ZIF (inputs). J3 removed 11/8.', 22.86, 132.08)

    P.frame(215.9, 15.24, 403.86, 139.7, '+5 V in, 3.3 V rail for the mics, EEPROM and light sensor, 5 V LED')
    P.add('D_TVS', 'SMBJ5.0A', 228.6, 50.8, {1: '+5V', 2: 'GND'}, fp=FP_TVS, mpn='SMBJ5.0A', mfr='Littelfuse',
          note='Clamps up to 9.2 V: bench protection only; the Mainboard input has the over-voltage switch')
    C(P, '10u', 241.3, 50.8, '+5V')
    C(P, '100n', 254.0, 50.8, '+5V')
    P.add('LP5907MFX-3.3', 'LP5907MFX-3.3', 309.88, 48.26, {1: '+5V', 3: '+5V', 2: 'GND', 5: '+3V3', 4: 'NC'}, ref='U2',
          mpn='LP5907MFX-3.3/NOPB', mfr='TI', note='Feeds only the mics, EEPROM, VEML7700 and I2C pull-ups (~5 mA)')
    C(P, '1u', 294.64, 86.36, '+5V')
    C(P, '1u', 325.12, 86.36, '+3V3')
    P.add('SolderJumper_2', 'LED', 241.3, 109.22, {1: '+5V', 2: 'LED_EN'}, ref='JP3', fp=FP_SJ, bom=False,
          note='Open by default: bridge to light the red 5 V LED')
    R(P, '1k', 254.0, 109.22, 'LED_EN', 'LED_A')
    P.add('LED', 'red', 266.7, 109.22, {2: 'LED_A', 1: 'GND'}, fp=FP_LED, mpn='LTST-C150KRKT', mfr='Lite-On')
    for i, n in enumerate(['+5V', 'GND', '+5V_6004']):
        P.add('PWR_FLAG', 'PWR_FLAG', 350.52 + i * 15.24, 114.3, {1: n})
    P.text('LP5907 from the ribbon 5 V only: never from the LD6004 buck or the LD2450 3.3Vout.', 220.98, 132.08)

    P.frame(15.24, 152.4, 203.2, 284.48, 'Two I2S mics (Adafruit 6049 / 3421 soldered at the top edge, overhanging it), one shared data line')
    for ref, x, sel, side in (('J1', 60.96, 'GND', 'left'), ('J2', 142.24, '+3V3', 'right')):
        P.add('I2S_Mic_Breakout', f'mic {side}', x, 190.5,
              {1: '+3V3', 2: 'GND', 3: 'MIC_BCLK', 4: 'MIC_DOUT', 5: 'MIC_WS', 6: sel}, ref=ref,
              mpn='6049', mfr='Adafruit Industries',
              note=f'SEL {"low" if sel == "GND" else "high"} = {side} channel. Breakout lies flat, sound hole to the room')
    R(P, '33', 38.1, 246.38, 'L_BCLK', 'MIC_BCLK', note='At J7')
    R(P, '33', 53.34, 246.38, 'L_WS', 'MIC_WS', note='At J7')
    R(P, '33', 68.58, 246.38, 'MIC_DOUT', 'L_MIC_DATA', note='At the mics')
    C(P, '1u', 96.52, 246.38, '+3V3', note='At J1')
    C(P, '1u', 111.76, 246.38, '+3V3', note='At J2')
    P.text('Both mics drive one DATA line: J1 on the left I2S slot (SEL low), J2 on the right (SEL high).', 22.86, 271.78)

    P.frame(215.9, 152.4, 403.86, 284.48, 'ID EEPROM, light sensor, I2C pull-ups, spare wires, mounting')
    P.add('24AA256UID', '24AA256UID-I/SN', 254.0, 190.5,
          {1: 'GND', 2: 'GND', 3: 'GND', 7: 'NC', 8: '+3V3', 5: 'I2C_SDA', 6: 'I2C_SCL', 4: 'GND'}, ref='U3',
          mpn='24AA256UID-I/SN', mfr='Microchip',
          note='0x50. Holds rev, serial, build date, bench result, radar firmware versions, hours run, resets per radar, fault log')
    C(P, '100n', 236.22, 228.6, '+3V3', note='At U3')
    P.add('VEML7700', 'VEML7700-TT', 327.66, 190.5, {2: '+3V3', 3: 'GND', 4: 'I2C_SDA', 1: 'I2C_SCL'}, ref='U4',
          mpn='VEML7700-TT', mfr='Vishay', dnp=True,
          note='0x10. Front, on the centreline just below the LD2450. DNP for now (John, 10/31): the bench light sensor is '
               'an Adafruit 4162 breakout on Mainboard-USB, which would clash at 0x10')
    C(P, '100n', 312.42, 228.6, '+3V3', dnp=True, note='At U4 (DNP with it)')
    R(P, '4.7k', 340.36, 228.6, '+3V3', 'I2C_SDA', note='I2C pull-ups live on SB1, from its own 3.3 V (backboards: DNP)')
    R(P, '4.7k', 353.06, 228.6, '+3V3', 'I2C_SCL')
    P.add('Spare_3', 'spare wires', 386.08, 254.0, {1: 'SPARE1', 2: 'SPARE2', 3: 'GND'}, ref='J6',
          mpn='1x3 2.54 mm header', mfr='Sullins')
    for i in range(4):
        P.add('MountingHole_M2.5', 'M2.5', 236.22 + i * 15.24, 266.7, {}, ref=f'H{i + 1}', bom=False)
    P.text('EEPROM and VEML7700 sit on the same bus with different addresses; both SB1s are identical, the backboard separates them.',
           220.98, 279.4)

    # =================================================================== LD6004
    A = d.sheet('LD6004', 'ld6004.kicad_sch', 'LD6004: isolation link, 3.3 V buck, UART resistors')
    A.frame(15.24, 15.24, 403.86, 284.48, 'LD6004 (60 GHz): 3.3 V from the 5 V link through a TLV62569; UART 115200 8N1')
    link(A, 30.48, 50.8, '+5V', '+5V_6004', 'LD6004', 'JP1')
    A.add('TLV62569DBV', 'TLV62569DBVR', 101.6, 50.8, {4: '+5V_6004', 1: '+5V_6004', 2: 'GND', 3: 'A_SW', 5: 'A_FB'}, ref='U1',
          mpn='TLV62569DBVR', mfr='TI', note='EN tied to VIN: always on while the link is fitted')
    y1, x0 = 106.68, 30.48
    C(A, '10u', x0, y1, '+5V_6004')
    C(A, '100n', x0 + 12.7, y1, '+5V_6004')
    A.add('L', '2.2uH Isat>2A', x0 + 25.4, y1, {1: 'A_SW', 2: 'A_3V3R'}, fp=FP_L, mpn='SRN4018-2R2M', mfr='Bourns')
    R(A, '453k', x0 + 38.1, y1, 'A_3V3R', 'A_FB')
    R(A, '100k', x0 + 50.8, y1, 'A_FB', 'GND')
    C(A, '6.8p', x0 + 63.5, y1, 'A_3V3R', 'A_FB', note='Feed-forward cap: TLV62569 datasheet value for R2 = 100k')
    C(A, '22u', x0 + 76.2, y1, 'A_3V3R')
    FB(A, x0 + 88.9, y1, 'A_3V3R', 'A_3V3')
    C(A, '22u', x0 + 101.6, y1, 'A_3V3')
    C(A, '100n', x0 + 114.3, y1, 'A_3V3')
    A.text('Vout = 0.6 x (1 + 453k/100k) = 3.32 V. TLV62569 is specified for 10-47 uF output: 22 uF at the buck, '
           '22 uF after the ferrite.', 22.86, 33.02)
    A.add('LD6004_Module', 'HLK-LD6004 on board', 254.0, 165.1, {1: 'L_6004_P20', 2: 'A_TXO', 3: 'A_RXI', 4: 'GND', 5: 'A_3V3'},
          ref='J4', mpn='2x LPPB051NFFN-RC sockets + 2x GRPB051VWVN-RC module pins', mfr='Sullins',
          note='Module plugs in antenna side up. Solder 1x5 1.27 mm male headers into both module rows, pins out of the back. Pin n = LD6004 header pin n')
    R(A, '100', 203.2, 213.36, 'A_TXO', 'L_6004_TX', note='At J4 (radar TX out)')
    R(A, '100', 218.44, 213.36, 'L_6004_RX', 'A_RXI', note='At J7 (radar RX in)')
    A.text('P20 goes straight to FFC wire 18. No LED on P20 (removed 10/29).', 22.86, 254.0)
    A.text('Power-cycle (from the backboard): 5 V off 500 ms, on, wait 2.5 s, flush RX.', 22.86, 259.08)

    # =================================================================== LD2450
    B = d.sheet('LD2450', 'ld2450.kicad_sch', 'LD2450: isolation link, filtering, UART resistors')
    B.frame(15.24, 15.24, 403.86, 284.48, 'LD2450 (24 GHz), mounted upright (patches at the top): 5 V; UART 256000 8N1')
    link(B, 30.48, 50.8, '+5V', '+5V_2450', 'LD2450', 'JP2')
    y1, x0 = 106.68, 30.48
    C(B, '10u', x0, y1, '+5V_2450')
    FB(B, x0 + 12.7, y1, '+5V_2450', 'B_5V')
    C(B, '22u', x0 + 25.4, y1, 'B_5V')
    C(B, '10u', x0 + 38.1, y1, 'B_5V')
    C(B, '100n', x0 + 50.8, y1, 'B_5V')
    B.text('LD2450 is powered at 5 V (>200 mA); its UART is 3.3 V logic. Never tie its 3.3Vout (module pin 6) to a rail.', 22.86, 33.02)
    B.add('LD2450_Module', 'HLK-LD2450 on board', 254.0, 165.1, {1: 'B_5V', 2: 'GND', 3: 'B_TXO', 4: 'B_RXI'},
          ref='J5', mpn='NPPN042AFCN-RC', mfr='Sullins',
          note='Module plugs in antenna side up on its own 2x4 2.00 mm header. Board-mounted upright: footprint at +90 deg, '
               'patch group at the top, 2x4 header at the bottom')
    R(B, '100', 203.2, 213.36, 'B_TXO', 'L_2450_TX', note='At J5 (radar TX out)')
    R(B, '100', 218.44, 213.36, 'L_2450_RX', 'B_RXI', note='At J7 (radar RX in)')
    B.text('Upright on the board, LD2450 x is mirrored against the bench mount: firmware LD2450_X_SIGN should be +1. '
           'Recheck at bring-up.', 22.86, 254.0)

    import vendor
    vendor.apply(d)
    return d
