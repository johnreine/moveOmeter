"""moveOmeter SB1 sensor board: every part, net and position (2026-10-25).

One LD6004 and one LD2450 on the front, TB1's per-sensor power stage, a USB-C + CH340C per sensor for bench use
from a PC, and a 20-pin ribbon to the mainboard (5 V in, both UARTs, enables, I2C, P20, fault; 26 pins until 10/26).
Two SB1s at right angles give each frame / nightlight ~210 deg of coverage per radar type.
"""
from engine import Design
from symlib import build_library

FP_R = 'Resistor_SMD:R_1206_3216Metric_Pad1.30x1.75mm_HandSolder'
FP_R1206 = FP_R
FP_C = 'Capacitor_SMD:C_1206_3216Metric_Pad1.33x1.80mm_HandSolder'
FP_C1210 = 'Capacitor_SMD:C_1210_3225Metric_Pad1.33x2.70mm_HandSolder'
C_1210 = {'10u', '22u'}
FP_CP63 = 'Capacitor_THT:CP_Radial_D6.3mm_P2.50mm'
FP_FB1206 = 'Inductor_SMD:L_1206_3216Metric_Pad1.22x1.90mm_HandSolder'
FP_L = 'Inductor_SMD:L_Bourns-SRN4018'
FP_LED = 'LED_SMD:LED_1206_3216Metric_Pad1.42x1.75mm_HandSolder'
FP_SJ = 'Jumper:SolderJumper-2_P1.3mm_Open_RoundedPad1.0x1.5mm'


def r_mpn(v):
    code = {'5.1k': '5K1', '1M': '1M', '100k': '100K', '453k': '453K', '2.2k': '2K2', '4.7k': '4K7', '1k': '1K',
            '10k': '10K', '220': '220R', '33': '33R', '22k': '22K', '10': '10R', '27k': '27K', '499': '499R'}[v]
    return f'RC1206FR-07{code}L'


C_MPN = {'100n': ('CL31B104KBCNNNC', 'Samsung'), '10u': ('GRM32DR71E106KA12L', 'Murata'),
         '22u': ('GRM32ER61E226KE15L', 'Murata'), '1u': ('CC1206KKX7R9BB105', 'Yageo'),
         '10n': ('C1206C103K5RACTU', 'KEMET'), '6.8p': ('CC1206CRNPO9BN6R8', 'Yageo')}
C_VAL = {'100n': '100nF 50V X7R', '10u': '10uF 25V X7R', '22u': '22uF 25V X5R', '1u': '1uF 50V X7R',
         '10n': '10nF 50V X7R', '6.8p': '6.8pF C0G'}


def build():
    d = Design(build_library())

    def R(sh, v, x, y, a, b, **kw):
        fp = kw.pop('fp', FP_R)
        mpn = kw.pop('mpn') if 'mpn' in kw else r_mpn(v)
        mfr = kw.pop('mfr') if 'mfr' in kw else 'Yageo'
        return sh.add('R', v, x, y, {1: a, 2: b}, fp=fp, mpn=mpn, mfr=mfr, **kw)

    def C(sh, v, x, y, a, b='GND', **kw):
        mpn, mfr = C_MPN[v]
        return sh.add('C', C_VAL[v], x, y, {1: a, 2: b}, fp=FP_C1210 if v in C_1210 else FP_C, mpn=mpn, mfr=mfr, **kw)

    def CP100(sh, x, y, a, **kw):
        return sh.add('CP', '100uF 16V polymer', x, y, {1: a, 2: 'GND'}, fp=FP_CP63, mpn='A759EK107M1CAAE018', mfr='KEMET', **kw)

    def FB(sh, x, y, a, b):
        return sh.add('FB', '220R@100MHz 4A', x, y, {1: a, 2: b}, fp=FP_FB1206, mpn='LSMGA321616T221NG', mfr='Taiyo Yuden')

    def LED(sh, x, y, a, k='GND'):
        return sh.add('LED', 'green', x, y, {2: a, 1: k}, fp=FP_LED, mpn='LTST-C150GKT', mfr='Lite-On')

    def TP(sh, x, y, net, label):
        return sh.add('TestPoint', label, x, y, {1: net}, mpn='5000 (red) / 5001 (black)', mfr='Keystone')

    def row(x0, i, dx=12.7):
        return x0 + i * dx

    def MUX(sh, x, y, ch):
        return MUX_IMPL(sh, x, y, ch, R, C)

    # =================================================================== POWER, USB, MAINBOARD LINK
    P = d.sheet('Power_USB', 'power_usb.kicad_sch', 'USB-C + CH340C per sensor, 5 V selection, 3.3 V logic, ribbon')
    for k, ox, s in (('A', 15.24, 'LD6004'), ('B', 213.36, 'LD2450')):
        P.frame(ox, 15.24, ox + 190.5, 132.08, f'USB-C {k} ({s}): power for the {s}, and its UART to the PC')
        P.add('USB_C_USB2.0', 'USB4105-GF-A', ox + 25.4, 68.58,
              {'A4': f'VBUS_{k}', 'A9': f'VBUS_{k}', 'B4': f'VBUS_{k}', 'B9': f'VBUS_{k}', 'A5': f'CC1_{k}', 'B5': f'CC2_{k}',
               'A6': f'DP_{k}', 'B6': f'DP_{k}', 'A7': f'DN_{k}', 'B7': f'DN_{k}', 'A8': 'NC', 'B8': 'NC',
               'A1': 'GND', 'A12': 'GND', 'B1': 'GND', 'B12': 'GND', 'SH': f'SHIELD_{k}'}, mpn='USB4105-GF-A', mfr='GCT')
        R(P, '5.1k', ox + 7.62, 116.84, f'CC1_{k}', 'GND', note='Rd: advertises a sink so a USB-C source gives 5 V')
        R(P, '5.1k', ox + 20.32, 116.84, f'CC2_{k}', 'GND')
        R(P, '1M', ox + 33.02, 116.84, f'SHIELD_{k}', 'GND')
        C(P, '10n', ox + 45.72, 116.84, f'SHIELD_{k}')
        P.add('USBLC6-2SC6', 'USBLC6-2SC6', ox + 66.04, 45.72, {1: f'DP_{k}', 6: f'DP_{k}', 3: f'DN_{k}', 4: f'DN_{k}', 5: f'VBUS_{k}', 2: 'GND'},
              mpn='USBLC6-2SC6', mfr='STMicroelectronics')
        P.add('CH340C', 'CH340C', ox + 106.68, 68.58,
              {5: f'DP_{k}', 6: f'DN_{k}', 16: '+3V3', 4: '+3V3', 1: 'GND', 7: 'NC', 8: 'NC', 15: 'GND',
               2: f'{k}_USB_TX', 3: f'{k}_USB_RX', 13: f'{k}_DTR', 14: f'{k}_RTS',
               9: f'{k}_P20' if k == 'A' else f'{k}_FLT', 10: 'NC', 11: 'NC', 12: 'NC'},
              mpn='CH340C', mfr='WCH',
              note=('CTS# reads the LD6004 P20 pin' if k == 'A' else 'CTS# reads the LD2450 switch fault flag')
              + '. DTR asserted with RTS released turns the sensor off (see the sensor sheet). R232 tied low. '
              '256000 baud: 12 MHz / 47 = 255.3 kbaud (-0.3 %), inside the datasheet\'s 50 bps - 2 Mbps range')
        C(P, '100n', ox + 99.06, 116.84, '+3V3')
        C(P, '1u', ox + 111.76, 116.84, '+3V3')
        MUX(P, ox + 152.4, 68.58, k)
        P.text(f'TPS2113A: USB-C {k} powers the {s} unless the ribbon supplies 5 V (ribbon has priority, no back-feed).', ox + 7.62, 127.0)

    P.frame(15.24, 139.7, 203.2, 205.74, '3.3 V logic rail (CH340Cs, monitors, gates): from whichever 5 V is present')
    P.add('D_Schottky_x2_KCommon', 'BAT54C', 45.72, 172.72, {1: '+5V_A', 2: '+5V_B', 3: '+5V_LOGIC'}, mpn='BAT54CLT1G', mfr='onsemi')
    C(P, '1u', 76.2, 172.72, '+5V_LOGIC')
    P.add('LP5907MFX-3.3', 'LP5907MFX-3.3', 109.22, 170.18, {1: '+5V_LOGIC', 3: '+5V_LOGIC', 2: 'GND', 5: '+3V3', 4: 'NC'},
          mpn='LP5907MFX-3.3/NOPB', mfr='TI')
    C(P, '1u', 139.7, 172.72, '+3V3')
    C(P, '10u', 152.4, 172.72, '+3V3')
    R(P, '1k', 165.1, 172.72, '+3V3', 'LED_3V3')
    LED(P, 177.8, 172.72, 'LED_3V3')
    TP(P, 190.5, 172.72, '+3V3', '3V3')
    P.text('LP5907: 250 mA; load is two CH340Cs, two INA219s, gates and LEDs (~40 mA).', 22.86, 198.12)

    P.frame(213.36, 139.7, 403.86, 284.48, 'Mainboard link: 20-pin ribbon. +5V pair and each UART / I2C line between grounds')
    rib = ['GND', '+5V_RIB', '+5V_RIB', 'GND', 'RIB_A_TX', 'GND', 'RIB_A_RX', 'GND', 'RIB_B_TX', 'GND',
           'RIB_B_RX', 'GND', 'I2C_SDA', 'GND', 'I2C_SCL', 'GND', 'RIB_A_EN', 'RIB_B_EN', 'A_P20', 'B_FLT']
    P.add('Ribbon_2x10', 'Mainboard link', 271.78, 215.9, {i + 1: n for i, n in enumerate(rib)},
          mpn='SBH11-PBPC-D10-ST-BK', mfr='Sullins')
    C(P, '10u', 330.2, 182.88, '+5V_RIB')
    C(P, '100n', 342.9, 182.88, '+5V_RIB')
    R(P, '10k', 330.2, 215.9, '+3V3', 'RIB_A_TX', note='Idle-high when no mainboard is connected')
    R(P, '10k', 342.9, 215.9, '+3V3', 'RIB_B_TX')
    P.text('TX = mainboard to sensor, RX = sensor to mainboard (3.3 V logic). EN: drive low (open-drain) to turn a sensor off.', 220.98, 264.16)
    P.text('I2C: INA219s at 0x40 (LD6004) / 0x44 (LD2450); bridge JP1 for 0x41 / 0x45 on the second board. Pull-ups on the mainboard.', 220.98, 269.24)
    P.text('Wire n = pin n on the flat cable: the +5V pair and every UART / I2C wire have a ground wire on both sides; EN / P20 / FLT are static.', 220.98, 274.32)

    P.frame(15.24, 213.36, 203.2, 284.48, 'Address select, flags, mounting, test points')
    R(P, '10k', 27.94, 233.68, 'ADDR_SEL', 'GND', note='Default: first board (INA219 0x40 / 0x44)')
    P.add('SolderJumper_2', 'ADDR B', 40.64, 233.68, {1: 'ADDR_SEL', 2: '+3V3'}, fp=FP_SJ, bom=False,
          note='Bridge on the second board: INA219s move to 0x41 / 0x45')
    for i, n in enumerate(['+5V_RIB', 'VBUS_A', 'VBUS_B', 'GND', '+5V_LOGIC']):
        P.add('PWR_FLAG', 'PWR_FLAG', 66.04 + i * 15.24, 228.6, {1: n})
    for i in range(4):
        P.add('MountingHole', 'M3', 66.04 + i * 15.24, 254.0, {1: 'GND'}, bom=False)
    TP(P, 132.08, 254.0, 'GND', 'GND')
    TP(P, 147.32, 254.0, '+5V_RIB', '5V_RIB')

    # =================================================================== SENSOR CHANNELS
    def tx_path(sh, k, ox, oy, rail_ok):
        """Either host can talk: AND of the ribbon TX, the CH340C TX and 'sensor rail is up' -> sensor RX.
        Sensor TX fans out to both hosts through 1k."""
        sh.add('74LVC1G11', 'SN74LVC1G11DBVR', ox + 33.02, oy, {1: f'RIB_{k}_TX', 3: f'{k}_USB_TX', 6: f'{k}_RAILOK',
                                                               5: '+3V3', 4: f'{k}_BUFY', 2: 'GND'},
               mpn='SN74LVC1G11DBVR', mfr='TI', note='Output low whenever the sensor rail is down, so nothing back-powers the sensor')
        C(sh, '100n', ox + 7.62, oy + 25.4, '+3V3')
        R(sh, '1k', ox + 20.32, oy + 25.4, f'{k}_BUFY', f'{k}_RXI')
        R(sh, '1k', ox + 33.02, oy + 25.4, f'{k}_TXO', f'{k}_USB_RX')
        R(sh, '1k', ox + 45.72, oy + 25.4, f'{k}_TXO', f'RIB_{k}_RX')
        rail_ok()

    def en_logic(sh, k, ox, oy):
        """Sensor on by default. Mainboard pulls RIB_x_EN low, or the PC asserts DTR with RTS released, to turn it off."""
        R(sh, '100k', ox + 7.62, oy, '+3V3', f'{k}_EN', note='Default on')
        R(sh, '4.7k', ox + 20.32, oy, f'RIB_{k}_EN', f'{k}_EN', note='Mainboard pulls low to turn the sensor off')
        sh.add('Q_NMOS_GSD', '2N7002', ox + 38.1, oy, {1: f'{k}_RTS', 2: f'{k}_DTR', 3: f'{k}_EN'}, mpn='2N7002LT1G', mfr='onsemi',
               note='PC power-cycle: DTR asserted (low) with RTS released (high) pulls EN low. Opening the port asserts both: no effect')

    def discharge(sh, k, ox, oy, rail):
        sh.add('74LVC1G04', 'SN74LVC1G04DBVR', ox + 7.62, oy, {2: f'{k}_EN', 1: 'NC', 5: '+3V3', 4: f'{k}_DISG', 3: 'GND'},
               mpn='SN74LVC1G04DBVR', mfr='TI', note='EN low -> discharge FET on')
        sh.add('Q_NMOS_GSD', 'AO3400A', ox + 38.1, oy, {1: f'{k}_DISG', 3: f'{k}_DIS', 2: 'GND'}, mpn='AO3400A', mfr='Alpha & Omega')
        R(sh, '10', ox + 55.88, oy, rail, f'{k}_DIS', note='Pulls the sensor rail to 0 V whenever EN is low')
        C(sh, '100n', ox + 68.58, oy, '+3V3')

    # ---- LD6004 (channel A)
    A = d.sheet('LD6004', 'ld6004.kicad_sch', 'LD6004: 3.3 V buck, monitor, discharge, TX gate, ESD')
    A.frame(15.24, 15.24, 403.86, 284.48, 'LD6004 (channel A): 115200 8N1; USB-C A or ribbon pins 7 / 9')
    A.add('TLV62569DBV', 'TLV62569DBVR', 50.8, 50.8, {4: '+5V_A', 1: 'A_EN', 2: 'GND', 3: 'A_SW', 5: 'A_FB'}, mpn='TLV62569DBVR', mfr='TI')
    A.add('INA219AxD', 'INA219AIDR', 254.0, 50.8,
          {8: 'A_3V3R', 7: 'A_3V3M', 1: 'GND', 2: 'ADDR_SEL', 5: '+3V3', 3: 'I2C_SDA', 4: 'I2C_SCL', 6: 'GND'},
          mpn='INA219AIDR', mfr='TI', note='I2C 0x40, or 0x41 with ADDR B bridged; 50 mOhm shunt, PGA /1 -> 800 mA')
    y1 = 86.36
    C(A, '10u', row(25.4, 0), y1, '+5V_A')
    C(A, '100n', row(25.4, 1), y1, '+5V_A')
    A.add('L', '2.2uH Isat>2A', row(25.4, 2), y1, {1: 'A_SW', 2: 'A_3V3R'}, fp=FP_L, mpn='SRN4018-2R2M', mfr='Bourns')
    R(A, '453k', row(25.4, 3), y1, 'A_3V3R', 'A_FB')
    R(A, '100k', row(25.4, 4), y1, 'A_FB', 'GND')
    C(A, '6.8p', row(25.4, 5), y1, 'A_3V3R', 'A_FB', note='Feed-forward cap: TLV62569 datasheet value for R2 = 100k')
    C(A, '22u', row(25.4, 6), y1, 'A_3V3R')
    R(A, '1k', row(25.4, 7), y1, 'A_3V3R', 'LED_A')
    LED(A, row(25.4, 8), y1, 'LED_A')
    R(A, '50mΩ 1%', row(25.4, 9), y1, 'A_3V3R', 'A_3V3M', mpn='WSL1206R0500FEA', mfr='Vishay')
    FB(A, row(25.4, 10), y1, 'A_3V3M', 'A_3V3')
    C(A, '22u', row(25.4, 11), y1, 'A_3V3')
    C(A, '100n', row(25.4, 12), y1, 'A_3V3')
    C(A, '100n', row(25.4, 17), y1, '+3V3', note='INA219 VS decoupler')
    TP(A, row(25.4, 14), y1, 'A_3V3', 'A_3V3')
    A.text('Vout = 0.6 x (1 + 453k/100k) = 3.32 V. TLV62569 is specified for 10-47 uF output: 22 + 22 uF here.', 22.86, 33.02)

    tx_path(A, 'A', 22.86, 132.08, lambda: R(A, '1k', 101.6, 157.48, 'A_3V3', 'A_RAILOK', note='Rail-up sense for the TX gate'))
    R(A, '1k', 114.3, 157.48, 'A_P20O', 'A_P20')
    R(A, '100k', 127.0, 157.48, 'A_P20', 'GND')
    A.add('SRV05-4', 'SRV05-4', 177.8, 132.08, {1: 'A_TXO', 3: 'A_RXI', 4: 'A_P20O', 6: 'NC', 5: 'A_3V3', 2: 'GND'},
          mpn='SRV05-4.TCT', mfr='Semtech')
    A.add('LD6004_Module', 'HLK-LD6004 on board', 254.0, 132.08, {1: 'A_P20O', 2: 'A_TXO', 3: 'A_RXI', 4: 'GND', 5: 'A_3V3'},
          mpn='2x LPPB051NFFN-RC sockets + 2x GRPB051VWVN-RC module pins', mfr='Sullins',
          note='Module plugs in antenna side up. Solder 1x5 1.27 mm male headers into both module rows, pins out of the back. Pin n = LD6004 header pin n')
    en_logic(A, 'A', 22.86, 203.2)
    discharge(A, 'A', 101.6, 203.2, 'A_3V3')
    A.text('P20 goes to the ribbon (pin 23) and to CH340C A CTS#, so either host can read it.', 22.86, 254.0)
    A.text('Power-cycle: EN low 500 ms, high, wait 2.5 s, flush RX.', 22.86, 259.08)

    # ---- LD2450 (channel B)
    B = d.sheet('LD2450', 'ld2450.kicad_sch', 'LD2450: 5 V switch, monitor, discharge, TX gate, ESD')
    B.frame(15.24, 15.24, 403.86, 284.48, 'LD2450 (channel B): 256000 8N1; USB-C B or ribbon pins 11 / 13')
    B.add('TPS2051CDBV', 'TPS2051CDBVR', 50.8, 50.8, {5: '+5V_B', 4: 'B_EN', 2: 'GND', 1: 'B_5VS', 3: 'B_FLT'},
          mpn='TPS2051CDBVR', mfr='TI')
    B.add('INA219AxD', 'INA219AIDR', 254.0, 50.8,
          {8: 'B_5VS', 7: 'B_5VM', 1: '+3V3', 2: 'ADDR_SEL', 5: '+3V3', 3: 'I2C_SDA', 4: 'I2C_SCL', 6: 'GND'},
          mpn='INA219AIDR', mfr='TI', note='I2C 0x44, or 0x45 with ADDR B bridged; 100 mOhm shunt, PGA /1 -> 400 mA')
    C(B, '10u', row(25.4, 0), y1, '+5V_B')
    C(B, '100n', row(25.4, 1), y1, '+5V_B')
    R(B, '10k', row(25.4, 2), y1, '+3V3', 'B_FLT')
    R(B, '2.2k', row(25.4, 3), y1, 'B_5VS', 'LED_B')
    LED(B, row(25.4, 4), y1, 'LED_B')
    R(B, '100mΩ 1%', row(25.4, 5), y1, 'B_5VS', 'B_5VM', mpn='WSL1206R1000FEA', mfr='Vishay')
    FB(B, row(25.4, 6), y1, 'B_5VM', 'B_5V')
    CP100(B, row(25.4, 7), y1, 'B_5V')
    C(B, '10u', row(25.4, 8), y1, 'B_5V')
    C(B, '100n', row(25.4, 9), y1, 'B_5V')
    C(B, '100n', row(25.4, 17), y1, '+3V3', note='INA219 VS decoupler')
    TP(B, row(25.4, 11), y1, 'B_5V', 'B_5V')
    B.text('LD2450 is powered at 5 V; its UART is 3.3 V logic.', 22.86, 33.02)

    tx_path(B, 'B', 22.86, 132.08, lambda: R(B, '10k', 101.6, 157.48, 'B_5V', 'B_RAILOK',
                                             note='Rail-up sense for the TX gate (LVC inputs take 5 V)'))
    B.add('SRV05-4', 'SRV05-4', 177.8, 132.08, {1: 'B_TXO', 3: 'B_RXI', 4: 'NC', 6: 'NC', 5: 'B_5V', 2: 'GND'},
          mpn='SRV05-4.TCT', mfr='Semtech')
    B.add('LD2450_Module', 'HLK-LD2450 on board', 254.0, 132.08, {1: 'B_5V', 2: 'GND', 3: 'B_TXO', 4: 'B_RXI'},
          mpn='NPPN042AFCN-RC', mfr='Sullins',
          note='Module plugs in antenna side up on its own 2x4 2.00 mm header (Hi-Link manual fig. 3)')
    en_logic(B, 'B', 22.86, 203.2)
    discharge(B, 'B', 101.6, 203.2, 'B_5V')
    B.text('The switch fault flag goes to the ribbon (pin 25) and to CH340C B CTS#.', 22.86, 254.0)
    B.text('Power-cycle: EN low 500 ms, high, wait 2.5 s, flush RX.', 22.86, 259.08)

    import vendor
    vendor.apply(d)
    return d


MUX_IMPL = None   # set below


def _mux_tps2113a(sh, x, y, k, R, C):
    """Ribbon 5 V (IN1) has priority; USB VBUS (IN2) takes over when the ribbon is absent. No back-feed either way:
    the mux FETs have no body diodes. ~84 mOhm, current limit 500 / R_ILIM = 1.0 A."""
    sh.add('TPS2113APW', 'TPS2113APWR', x, y, {8: '+5V_RIB', 6: f'VBUS_{k}', 7: f'+5V_{k}', 5: 'GND', 2: 'GND', 3: 'VSNS',
                                             4: f'ILIM_{k}', 1: 'NC'}, mpn='TPS2113APWR', mfr='TI',
           note='Auto-switching: OUT = IN1 (ribbon) while VSNS > 0.8 V (ribbon above ~3.8 V), else the higher of IN1 / IN2')
    R(sh, '499', x - 12.7, y + 25.4, f'ILIM_{k}', 'GND', note='Current limit 500 / 499 = 1.0 A')
    C(sh, '100n', x, y + 25.4, '+5V_RIB')
    C(sh, '100n', x + 12.7, y + 25.4, f'VBUS_{k}')
    if k == 'A':                       # one VSNS divider serves both muxes
        R(sh, '100k', x - 12.7, y + 48.26, '+5V_RIB', 'VSNS', note='VSNS = 5 V x 27k / 127k = 1.06 V: ribbon wins above ~3.8 V')
        R(sh, '27k', x, y + 48.26, 'VSNS', 'GND')


MUX_IMPL = _mux_tps2113a
