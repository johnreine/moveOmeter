"""SB1 rev B placement (2026-10-31). Front view, origin top-left, y down. [x, y, rot, side] per ref; footprint origins as
KiCad stores them (back-side parts are given in front-view coordinates; mkpcb flips them).

History: placed by hand from the layout John approved on 10/31 (86 mm tall, mic sockets on the front). Later on 10/31
John moved both mics to the BACK at the top edge, soldered flat and overhanging it, and asked for the board to shrink.
Everything below the mics moved up by SHIFT mm, the board lost SHIFT mm at the bottom, the top holes moved just below
the mics, and the small back parts above the LD6004 buck (LED, mic caps, EEPROM, LDO, TVS, buck feedback) are now
placed by a small search below (nearest free spot to an anchor, checked against every courtyard, the hole keep-outs,
the LD2450 ground zone and the through-hole pins of the front parts).

Front (room side), top to bottom: holes H1 / H2, LD6004 J4, LD2450 J5 upright (+90 deg: patches up, 2x4 header down),
VEML7700 U4 on the centreline under it (DNP), holes H3 / H4.
Back: the two mic breakouts J1 / J2 at the top edge (header rows y 2.0, 22 mm apart, overhanging the edge by 8.2 mm),
the small parts, the LD6004 buck behind the LD6004, one FFC ZIF J7 (left edge, J3 removed 11/8) beside the LD2450
opening toward the centre (11/4) with a clear cable lane in front of each, LD2450 filtering under its header. Nothing behind the LD2450 + 3 mm.
Also writes <out>/layout.json (board height, ground zone, holes, silk marks) for mkpcb_sb1b.py and verify_sb1b.py.
usage: place_sb1b.py <out_dir>   -> <out>/placement.json, <out>/layout.json
"""
import json, math, os, sys

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
F, B = 'F', 'B'
SHIFT = 10.0                 # mm everything below the mics moved up (10/31), and the board got shorter
W, H = 42.0, 86.0 - SHIFT
S = SHIFT
J4_UP = 3.0                  # LD6004 moved up 3 mm more (10/31) to keep the LD2450's edge out of its beam

P = {
    # ---- mics on the back at the top edge (John, 10/31)
    'J1': (10.0, 2.0, 0, B), 'J2': (32.0, 2.0, 0, B),
    # ---- front
    'H1': (3.5, 8.3, 0, F), 'H2': (38.5, 8.3, 0, F),                 # just below the mic breakouts (back keep-out)
    'H3': (3.5, 82.5 - S, 0, F), 'H4': (38.5, 82.5 - S, 0, F),
    'J4': (21.0, 29.5 - S - J4_UP, 0, F),                                     # LD6004, signal row (pin 1 = P20) at the right
    'J5': (21.0, 56.2 - S, 90, F),                                    # LD2450 upright: +90 deg, header at the bottom
    'U4': (21.0, 81.0 - S, 0, F), 'C8': (27.6, 81.0 - S, 0, F),       # VEML7700 + decoupler (DNP)
    # ---- back: LD6004 buck, behind the LD6004 (SMD only)
    'C9': (8.0, 28.6 - S, 90, B), 'C10': (11.2, 28.6 - S, 90, B), 'U1': (15.2, 28.6 - S, 0, B), 'L1': (21.0, 28.6 - S, 0, B),
    'C12': (26.0, 28.6 - S, 90, B), 'FB1': (29.3, 28.6 - S, 90, B), 'C13': (32.6, 28.6 - S, 90, B),
    # ---- back: FFC ZIFs beside the LD2450, each opening toward the board centre (loop routing, John 11/3; turned
    # 180 deg on 11/4, they used to open toward their own edge). The cable lies flat on the back from the mouth (x 7.9 /
    # 34.1) toward the centre for ~11 mm, then loops into the V. C14, R10, R7, JP1, R11, R2, R3, R14 used to sit in
    # these lanes and are now placed by the search below.
    'J7': (5.0, 52.5 - S, 270, B),          # 11/8: J3 removed, J7 is the only ZIF
    # ---- back: under the LD2450 header
    'R12': (3.0, 70.5 - S, 90, B), 'JP2': (3.0, 75.0 - S, 90, B), 'C15': (7.0, 72.5 - S, 90, B), 'C18': (13.0, 73.0 - S, 0, B),
    'FB2': (12.5, 77.0 - S, 0, B), 'C16': (12.5, 81.0 - S, 0, B), 'R13': (20.5, 77.5 - S, 0, B), 'C17': (28.0, 81.0 - S, 0, B),
    'J6': (33.3, 72.0 - S, 180, B),
}
ZONE = (10.5, 31.2 - S, 31.5, 71.0 - S)             # LD2450 + 3 mm: no back parts
HOLES = {k: P[k][:2] for k in ('H1', 'H2', 'H3', 'H4')}
BACK_R = 3.3

# ---------------------------------------------------------------- courtyards (half sizes at rot 0, from the footprints)
HALF = {'R': (2.45, 1.13), 'C': (2.48, 1.15), 'C1210': (2.48, 1.6), 'LED': (2.45, 1.13), 'JP': (1.65, 1.25),
        'SOT': (2.05, 1.7), 'SOIC': (3.7, 2.7), 'SMB': (4.7, 2.25), 'L1206': (2.48, 1.2), 'SRN': (2.53, 2.25),
        'ZIF': (13.8, 3.3), 'HDR3': (1.77, 4.31)}
KIND = {'JP3': 'JP', 'R1': 'R', 'D2': 'LED', 'C5': 'C', 'R4': 'R', 'C6': 'C', 'U3': 'SOIC', 'R5': 'R', 'R6': 'R',
        'C7': 'C', 'U2': 'SOT', 'C3': 'C', 'C4': 'C', 'C1': 'C1210', 'C2': 'C', 'D1': 'SMB', 'R8': 'R', 'R9': 'R', 'C11': 'C',
        'C9': 'C1210', 'C10': 'C', 'U1': 'SOT', 'L1': 'SRN', 'C12': 'C1210', 'FB1': 'L1206', 'C13': 'C1210',
        'C14': 'C', 'R10': 'R', 'R7': 'R', 'JP1': 'JP', 'R11': 'R', 'R2': 'R', 'R3': 'R', 'R14': 'R',
        'R12': 'R', 'JP2': 'JP', 'C15': 'C1210', 'C18': 'C', 'FB2': 'L1206', 'C16': 'C1210', 'R13': 'R', 'C17': 'C1210'}


def rect(ref, x, y, r):
    hx, hy = HALF[KIND[ref]]
    if r % 180 == 90:
        hx, hy = hy, hx
    return (x - hx, y - hy, x + hx, y + hy)


def overlap(a, b, gap=0.15):
    return a[0] < b[2] + gap and b[0] < a[2] + gap and a[1] < b[3] + gap and b[1] < a[3] + gap


def circ(rc, cx, cy):
    nx, ny = min(max(cx, rc[0]), rc[2]), min(max(cy, rc[1]), rc[3])
    return math.hypot(nx - cx, ny - cy)


occupied = [rect(k, *P[k][:3]) for k in P if P[k][3] == B and k in KIND]
occupied += [(10 - 8.505, -8.41, 10 + 8.505, 4.79), (32 - 8.505, -8.41, 32 + 8.505, 4.79)]          # mic breakouts
occupied += [(33.3 - 1.77, 72.0 - S - 1.77, 33.3 + 1.77, 72.0 - S + 6.85)]                            # J6 header
# ZIF courtyards (local y -4.69..+1.91, mouth at local y -2.89), turned to open toward the centre
occupied.append((5.0 - 1.91, 52.5 - S - 13.8, 5.0 + 4.69, 52.5 - S + 13.8))                             # J7
# cable lanes (11/8: SB1-A's cable lies flat from J7's mouth across the zone to x ~32, then swings off; the right
# lane, where J3 was, keeps that stretch clear): from the mouth to the LD2450 ground zone and on to x 34.1, full cable width incl. ear tabs (ZIF body 25.2 mm) + 0.5 mm
LANE_Y = (52.5 - S - 13.1, 52.5 - S + 13.1)
LANES = [(5.0 + 2.89, LANE_Y[0], ZONE[0], LANE_Y[1]), (ZONE[2], LANE_Y[0], 37.0 - 2.89, LANE_Y[1])]
occupied += LANES
for px in (21 - 16.4, 21 + 16.4):                                       # LD6004 socket pins come through the board
    occupied.append((px - 0.9, P['J4'][1] - 3.4, px + 0.9, P['J4'][1] + 3.4))

ORDER = [('R8', 'U1'), ('R9', 'R8'), ('C11', 'U1'),                       # buck feedback / bootstrap: close to U1 first
         ('D1', (21, 14)), ('U3', (12, 12)), ('R5', 'U3'), ('R6', 'U3'), ('C7', 'U3'),
         ('U2', (28, 12)), ('C3', 'U2'), ('C4', 'U2'), ('C1', 'U2'), ('C2', 'U2'),
         ('C5', (10, 7)), ('R4', (21, 7)), ('C6', (32, 7)),                     # mic supply parts, just under the mics
         ('JP3', (3, 14)), ('R1', 'JP3'), ('D2', 'R1'),                         # status LED group together
         # moved out of the cable lanes (11/4), placed last so everything above keeps its spot
         ('C14', (37.4, 19.0)), ('R10', (37.4, 17.0)),                  # LD6004 3V3 decoupler and TX series R, at its signal row
         ('R7', (13.0, 23.5)), ('JP1', 'R7'),                           # LD6004 supply link, at the buck input
         ('R11', (5.0, 25.5)), ('R14', (5.0, 59.5)),                    # radar RX series R, at the ZIF ends
         ('R2', (5.0, 22.0)), ('R3', 'R2'),                              # I2S BCLK / WS series R, at J7's top end (11/8: moved from the old J3 end)
         ]


def free(rc):
    if rc[0] < 0.3 or rc[1] < 0.3 or rc[2] > W - 0.3 or rc[3] > H - 0.3:
        return False
    if overlap(rc, ZONE, 0.0) or any(overlap(rc, o) for o in occupied):
        return False
    return all(circ(rc, hx, hy) >= BACK_R for hx, hy in HOLES.values())


for ref, anc in ORDER:
    ax, ay = (P[anc][0], P[anc][1]) if isinstance(anc, str) else anc
    best = None
    for gy in range(0, int(H * 4)):
        for gx in range(0, int(W * 4)):
            x, y = gx / 4, gy / 4
            d = math.hypot(x - ax, y - ay)
            if best and d >= best[0]:
                continue
            for r in (0, 90):
                rc = rect(ref, x, y, r)
                if free(rc):
                    best = (d, x, y, r)
                    break
    if not best:
        sys.exit(f'no room for {ref} with SHIFT {SHIFT}')
    _, x, y, r = best
    P[ref] = (x, y, r, B)
    occupied.append(rect(ref, x, y, r))

json.dump({k: list(v) for k, v in P.items()}, open(f'{OUT}/placement.json', 'w'), indent=0)
json.dump({'H': H, 'zone': ZONE, 'lanes': LANES, 'holes': HOLES, 'marks': {'front': [21.0, H - 1.4], 'back': [21.0, H - 1.2]}},
          open(f'{OUT}/layout.json', 'w'), indent=0)
print(len(P), 'parts placed;', sum(1 for v in P.values() if v[3] == F), 'front,', sum(1 for v in P.values() if v[3] == B),
      f'back; board {W:g} x {H:g} mm')
