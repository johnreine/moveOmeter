"""Mainboard-USB rev A placement (2026-10-31), by hand. 100 x 140 mm (150 until SB1 shrank 10 mm on 10/31), front view (from the room), origin top-left,
y down. [x, y, rot, side] per ref; back-side parts in front-view coordinates (mkpcb flips them).

Front: the SB1 V stands 35 mm out, apex at X 50, SB1 tops at y 8 (V footprint X 20.3-79.7, y 8-84). The two FFC ZIFs
stand on end inside the V (loop routing, 11/4; J2 turned round 11/8 when SB1 went to one ZIF): J2 (SB1-A) mouth at
X 38.87 opening left (SB1-A's cable swings in from the left), J3 (SB1-B) mouth at X 67.0 opening left (they were at the outer edges, X 7.1 / 92.9), both centred on y 50.5 (SB1's ZIF height; SB1 is 76 mm tall since 10/31). USB-C J1 on the left edge below J2, power parts beside it.
VEML7700 breakout J14 on the front of the wing, centred below the V.
Back: I2C headers with their MCP2221A parking pads at the top corners, mic / status headers below them at the sides, and on the
wing below y 90 the four CP2102 UART headers over their parking pads and zip-tie slots.
Back-silk pin labels read right-to-left from pin 1, as seen from behind. Also writes the silk pads, slots and labels for mkpcb_mbusb.py (env.json).
usage: place_mbusb.py <out_dir>   -> <out>/placement.json, <out>/env.json
"""
import json, os, sys

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
F, B = 'F', 'B'
UART_X0 = (11.17, 33.42, 56.42, 78.67)         # x of the socket row's left end (front view); sticks centred 5.08 mm in
UART_Y, SOCK_ROT = 94.0, 0                      # right-angle socket pin row; body toward +y (the stick)
STICK = (16.0, 21.0)                           # CP2102 stick PCB, w x l (sellers: 14-15 wide, 41-45 long with the plug,
                                               # PCB only ~21): it rests chip side down on its header plastic
FACE = UART_Y + 9.97                           # socket mouth (KiCad PinSocket_1x05_P2.54mm_Horizontal)
BOARD_H = 121.0                                # edge ~4 mm short of the stick PCB's end (FACE + 17): its USB plug, which may
                                               # sit a little over the PCB and hangs ~2 mm below it chip side down, stays clear
P = {
    # ---- front
    'J2': (41.76, 50.5, 270, F), 'J3': (69.89, 50.5, 270, F),    # 11/8: both open toward -X, mouths at X 38.87 / 67.0
    'J1': (3.4, 76.5, 270, F),
    'R1': (12.5, 74.5, 90, F), 'R2': (15.5, 74.5, 90, F), 'R3': (19.5, 74.5, 90, F), 'D2': (23.0, 74.5, 90, F),
    'D1': (14.0, 80.5, 0, F), 'C1': (11.0, 87.5, 0, F), 'C2': (21.0, 89.0, 90, F), 'C3': (24.6, 89.0, 90, F),
    'H1': (4.0, 4.0, 0, F), 'H2': (96.0, 4.0, 0, F), 'H3': (4.0, 86.0, 0, F), 'H4': (96.0, 86.0, 0, F),
    'H5': (32.0, 15.0, 0, F), 'H6': (68.0, 15.0, 0, F), 'H7': (32.0, 77.0, 0, F), 'H8': (68.0, 77.0, 0, F),
    'H9': (4.0, BOARD_H - 4.0, 0, F), 'H10': (96.0, BOARD_H - 4.0, 0, F),
    'J14': (50.0, 94.85, 180, F),     # VEML7700 breakout on the wing front: socket row at y 88.5 (below the V, above
                                       # the back UART headers), body hanging down over J5 / J6 (y 86-103.7), sensor ~y 100
    # ---- back: core
    'J8': (8.0, 12.0, 270, B), 'J9': (84.4, 12.0, 270, B),
    'R4': (10.5, 7.0, 0, B), 'R5': (16.0, 7.0, 0, B), 'R6': (84.0, 7.0, 0, B), 'R7': (89.5, 7.0, 0, B),
    # mic / status headers moved out from behind the new ZIFs (11/4) to where the old ZIFs were
    'J10': (10.0, 52.0, 270, B), 'J12': (10.0, 60.0, 270, B), 'J11': (82.4, 52.0, 270, B), 'J13': (82.4, 60.0, 270, B),
    # ---- back: wing
    'J4': (UART_X0[0], UART_Y, SOCK_ROT, B), 'J5': (UART_X0[1], UART_Y, SOCK_ROT, B),
    'J6': (UART_X0[2], UART_Y, SOCK_ROT, B), 'J7': (UART_X0[3], UART_Y, SOCK_ROT, B),
    # 1k in series with each adapter TXD (John, 10/31), just above its header (R8 off-centre to clear C1's pins on the front; J14's socket pins sit between R9 and R10)
    'R8': (UART_X0[0] + 9.5, 88.0, 0, B), 'R9': (UART_X0[1] + 5.08, 88.0, 0, B),
    'R10': (UART_X0[2] + 5.08, 88.0, 0, B), 'R11': (UART_X0[3] + 5.08, 88.0, 0, B),
}
NAMES = ('CP2102 LD6004-A', 'CP2102 LD2450-A', 'CP2102 LD2450-B', 'CP2102 LD6004-B')
PADS = [(6.0, 18.0, 24.0, 45.0, 'MCP2221A I2C-A'), (76.0, 18.0, 94.0, 45.0, 'MCP2221A I2C-B')]
SLOTS = []                                     # zip-tie slots dropped: the sticks plug in (11/01)
LABELS = [(12.0, 15.7, B, 'I2C-A  SCL SDA 3V3 GND(1)'), (88.0, 15.7, B, 'I2C-B  SCL SDA 3V3 GND(1)'),
          (14.0, 49.0, B, 'MIC-A  GND DATA WS BCLK(1)'), (86.4, 49.0, B, 'MIC-B  GND DATA WS BCLK(1)'),
          (14.0, 63.7, B, 'STAT-A  GND S2 S1 P20(1)'), (86.4, 63.7, B, 'STAT-B  GND S2 S1 P20(1)'),
          (50.0, 91.0, B, 'UART sockets: 5V(nc) GND RXD TXD 3V3(nc)(1), read from behind')]
LABELS += [(x + 5.08, FACE + STICK[1] / 2 + 2.5, B, n.replace('CP2102 ', '')) for x, n in zip(UART_X0, NAMES)]
LABELS += [(40.5, 66.5, F, 'SB1-A FFC'), (68.5, 66.5, F, 'SB1-B FFC'), (6.0, 69.5, F, '5V USB-C'), (50.0, 106.0, F, 'LIGHT SENSOR (I2C-A)')]
json.dump({k: list(v) for k, v in P.items()}, open(f'{OUT}/placement.json', 'w'), indent=0)
json.dump({'MB_PADS': PADS, 'MB_SLOTS': SLOTS, 'MB_LABELS': LABELS}, open(f'{OUT}/env.json', 'w'), indent=0)
print(len(P), 'parts placed;', sum(1 for v in P.values() if v[3] == F), 'front,', sum(1 for v in P.values() if v[3] == B), 'back')
