# moveOmeter Mainboard-USB (rev A, 4 layers, routed 11/13)

A passive backboard for two SB1 rev B sensor boards. It powers both from one USB-C port and brings every sensor
signal out to headers, so a PC can run all four radars and both I2C buses through plug-in USB adapters. The mic
headers need an external I2S master (the mics are clock slaves; nothing on this board drives BCLK / WS). It has no processor. It has the same size, mounting and FFC positions the ESP32-S3 Mainboard will use, so
the enclosure and 3D-printed bracket can be tried out now. Generated 2026-10-31 from `tools/` (same generator as SB1).

## How it fits

- The board stands upright behind the SB1 V, parallel to the wall. The V stands 35 mm out, its point toward the
  room, apex at X 50. Its footprint on the front is X 20.3-79.7, y 8-84 (dashed outline on F.Fab).
- **SB1-A** (left) plugs into **J2**, **SB1-B** (right) into **J3**, each from its SB1's only ZIF, J7 (one ZIF per SB1
  since 11/8). Both are Molex 200528-0200 ZIFs (20-way, 1.0 mm, ear-tab lock), standing on end **inside the V**,
  centred on y 50.5, the same height as SB1's ZIF, **both opening toward -X**: J2's mouth at X 38.9 (turned round on
  11/8; it used to open toward the centre at X 33.0), J3's at X 67.0. **Both are wired in reverse (pad n = wire 21 - n,
  GND on pad 20)**, to match SB1's J7, so GND (wire 1) is at the bottom of both and the two links are identical.
  Cable: 20-way 1.00 mm, same-side contacts (Type A), ~51 mm, the same for both sides; never Type D. SB1-B's cable
  leaves its SB1 toward the apex, U-turns inside the V and comes into J3 from the centre; SB1-A's runs out along its SB1
  back, swings round 135 degrees and comes into J2 from the left. Full workup and drawings (pins, cable faces, X / Y
  dimensions): SB1's README, FFC link, and `docs/ffc_top_view.png`, `docs/ffc_links_flat.png`.
- The front strips where each cable runs close to the board (X 27-38.9 left of J2, X 54-67 left of J3, y 36-65) are kept
  free of parts. The bracket on H5-H8 must leave that space open too.
- **Holes:** ten M3 (3.2 mm).
  - H5-H8 at (32, 15), (68, 15), (32, 77), (68, 77), under the V (7 mm inside its top and bottom), for the bracket that holds both SB1s.
  - H1-H4 at the corners of the core (4, 4), (96, 4), (4, 86), (96, 86), and H9 / H10 at the bottom corners
    (4, 117), (96, 117), for the enclosure.
  - Keep-out 3.5 mm on both sides.

## Board (100 x 121 mm, 2 layers)

The size comes from the design: 100 mm wide for the V plus the two ZIFs. The core (y 0-90) sits behind the V; the
wing below it (y 90-121) carries the four USB-serial sticks. (150 mm until SB1 shrank by 10 mm on 10/31, 140 mm until
the sticks plugged straight in on 11/01.)

- **Front, lower left:** USB-C J1 (GCT USB4125, power only) at the left edge, mouth out. 5.1k CC pull-downs (R1, R2),
  SMBJ5.0A TVS (D1), 470 uF polymer (C1), 10 uF + 100 nF, green power LED (R3, D2).
- **Front, wing:** the bench light sensor J14, an Adafruit 4162 VEML7700 breakout (John, 10/31) in a 1x5 socket
  (Sullins PPTC051LFBN-RC), centred below the V so the SB1s don't shade it. Socket row at y 88.5; the breakout hangs
  down over the back UART headers' pin stubs (it sits ~11 mm up), sensor at about y 100. On I2C-A at 0x10, powered from
  the I2C-A adapter's 3.3 V (its own pull-ups go to that). Pins 1 VIN, 2 3Vo (not used), 3 GND, 4 SCL, 5 SDA. SB1's
  own VEML7700 footprint is DNP so the two don't clash at 0x10.
- **Back, core:**
  - I2C-A / I2C-B headers (J8, J9) at the top corners, each above a parking pad for an MCP2221A USB-I2C breakout.
    4.7k pull-up footprints to the adapter's 3.3 V (R4-R7, DNP: SB1 has its own pull-ups).
  - Mic headers (J10, J11) and status headers (J12, J13: P20, spare 1, spare 2, GND) below the MCP2221A pads at the
    sides (y 52 / 60; moved 11/4 from the middle, where their pins came through under the new ZIF positions).
- **Back, wing:** four right-angle 1x5 female sockets (J4-J7, Sullins PPTC051LGBN-RC) with the pin row at y 94. John's
  CP2102 sticks (USB-A plug, right-angle pins 3V3 / TXD / RXD / GND / +5V) plug straight in **chip side down**: resting
  on their header plastic puts their pins at the socket's height, and chip side down is the way round that lands 3V3
  on pin 1. Each stick lies flat with its USB plug hanging past the bottom edge, to plug into a hub or a USB-A extension
  lead. Its outline is on the back silk, and "CP2102 CHIP SIDE DOWN" inside it. Plugged in chip side up, its TXD would
  land on the GND pin. A 1k resistor (R8-R11)
  above each header sits in series with the adapter's TXD.
- Back silk labels read as seen from behind; pin 1 is the square pad.
- **Stackup (4 layers since 11/13):** JLC04161H-7628, 1.6 mm, as SB1 / TB1: F.Cu signals + GND pour / In1 GND plane / In2 +5V plane / B.Cu signals + GND pour. (2 layers until 11/13; four Freerouting runs never finished.)
- **Net classes (11/6):** Default 0.2 mm track, 0.175 mm clearance (as on SB1: a 0.2 mm track fits between the 1 mm-pitch ZIF pads), 0.6 / 0.3 vias; Power (+5V) 1.0 mm track, 0.2 mm clearance, 0.8 / 0.4 vias, since +5V carries both SB1s (~1.5 A peak). Neck +5V down to 0.3-0.4 mm for the last mm into the ZIF pads (pins 2-3); hole clearance 0.175 mm.
- **Checks (all pass):** courtyards, pins under the other side's parts, hole keep-outs, FFC bands free, nothing taller
  than 12 mm under the V, back parts off the MCP2221A parking pads and the stick outlines, edges (J1 is meant to be at the edge), and every
  netlist pin has its pad and net.

## Headers

| Ref | For | Pins (1 to n) |
| --- | --- | --- |
| J4 / J7 | LD6004 A / B UART (115200 default; 460800 on the bench modules since 10/14) | 3V3 (nc), TXD, RXD, GND, 5V (nc) |
| J5 / J6 | LD2450 A / B UART (256000) | 3V3 (nc), TXD, RXD, GND, 5V (nc) |
| J8 / J9 | I2C A / B | GND, 3V3, SDA, SCL |
| J14 | VEML7700 breakout (on I2C-A) | VIN, 3Vo (nc), GND, SCL, SDA |
| J10 / J11 | Mics A / B | BCLK, WS, DATA, GND |
| J12 / J13 | Status A / B | P20, spare 1, spare 2, GND |

The UART sockets take John's CP2102 sticks (Amazon B0FJRTL572, 3V3 / TXD / RXD / GND / +5V): the stick's TXD drives
the radar's RX (through the 1k) and its RXD reads the radar's TX. The sticks' 3V3 and 5V pins aren't connected, so they
don't back-feed the sensors. The stick outline (16 x 21 mm PCB) comes from sellers' listings (14-15 mm wide, 41-45 mm
with the plug, ~21 mm PCB): check it against one in hand, and check that its USB plug clears the board edge chip side
down. The MCP2221A parking pads (about 18 x 27 mm) are still placeholders until that breakout is chosen. The sockets'
3D model orientation hasn't been checked in KiCad's 3D viewer yet.

**Resetting the radars:** each adapter's TXD idles high. Without a series resistor it could hold an unpowered radar
partly up through its RX input clamp, so unplugging J1 wouldn't be a clean power-cycle. A 1k in series with each
adapter TXD (R8-R11, John 10/31) limits that current to under ~3 mA, so unplugging J1 is a reset. The 1k plus SB1's
100 ohm is far too small to matter at 256000 baud.

## Ordering

`bom_board.csv`: about $14.40 a board at qty-1 prices, including the VEML7700 breakout and its socket, not counting
the USB adapters or the FFCs.

## 3D models

KiCad's library has models for the standard parts. The rest are in `3dmodels/`, written by `tools/layout/mk3d.py` (run
by `tools/rebuild.sh`) and referenced as `${KIPRJMOD}/3dmodels/...` in the footprints. They are VRML files, so KiCad's
3D viewer shows them, but a STEP export of the board leaves them out.
- `MBUSB_Adafruit_4162_VEML7700_on_socket.wrl` (J14): Adafruit has no 3D file for the 4162 (only for the right-angle
  5378), so this one is built from their board file: outline, holes, sensor, regulator and STEMMA QT sockets. It sits
  on its header in the 1x5 socket, top at 12.6 mm.
- `Molex_200528-0200_approx.wrl` (J2, J3): a simplified housing, actuator and contacts.
- `3dmodels/vendor/Adafruit_4471_MCP2221A_Breakout.step`: Adafruit's STEP of the MCP2221A breakout, for enclosure
  CAD. It isn't a footprint on the board.
- Mounting holes and solder jumpers have no model, as in KiCad's own library.
- The Molex 200528-0200 footprint points to an official STEP file that this KiCad install doesn't have. The board uses
  the approximate model instead (`MODEL_OVERRIDE` in the board script).

## Regenerating

`sh tools/rebuild.sh` writes the schematic, library, netlist report and BOM (`tools/build.py`), the placement and
silk pads / slots / labels (`tools/layout/place_mbusb.py`), the breakout footprint (`mkfp_mbusb.py`), the board (`mkpcb_mbusb.py`), runs the rule check
(`verify_mbusb.py`) and draws `docs/MBUSB_board.png`. `tools/layout/mkpro_mbusb.py` wrote the project file once
from SB1's. Parts and nets are in `tools/design.py`.

Once you edit in KiCad, KiCad is the source of truth.

## Silkscreen labels (11/6)

`tools/layout/silkrefs.py` (run by `rebuild.sh` after the board is written) moves every reference designator beside its own part so the board can be debugged with everything fitted: never under a part body, off pads, other silk and other labels, 0.5 mm inside the edge. Text is 0.8 mm (0.12 stroke), dropping to 0.7 / 0.6 mm only where there's no room (on SB1 only C11, at 0.6 mm). The module pin labels under the LD6004 / LD2450 and the CP2102 notes stay where their footprints put them. If you move a part in KiCad, move its label by hand: once routing starts, KiCad owns the board.

## Mounting holes: screw keep-outs (11/6)

All ten M3 holes are unplated. Rule areas ban tracks and vias within 3.45 mm of each hole centre on both sides (bracket
screw heads on the front at H5-H8, feet / nuts on the back); GND pour is allowed there.

## Routing prep (11/13)

`tools/layout/fanout_mbusb.py` (run by `rebuild.sh` right after the board is written) applies SB1's routing lessons:
- **Edge strips:** a 0.4 mm no-track / no-via rule area inside each edge on both layers. Freerouting ignores KiCad's
  0.5 mm copper-to-edge rule; the strips put it in the DSN. Pads and pour are allowed there.
- **GND fan-out:** 18 locked GND vias, one per SMD GND pad, each on a 0.3 mm stub: the ZIF GND pads (6, 9, 11, 14, 17,
  20) on the housing side at x 41.3 (J2) / 69.43 (J3), and C2, C3, D1, D2, R1, R2. They keep the two pours joined
  however the tracks cut them up.
- **+5V into the ZIFs:** pads 18 and 19 joined at 0.4 mm, out 0.4 mm past the courtyard, then 1.0 mm for 1.1 mm, so
  Freerouting picks +5V up at full width clear of the 1 mm-pitch pads.
- **Net class fix:** the Power pattern was `+5V`, but the net is `/Mainboard_USB/+5V`, so +5V had been in the Default
  class (0.2 mm). It's `*+5V` now, in the project file and in `mkpro_mbusb.py`.
- `moveOmeter_MBUSB.kicad_dru`: +5V may neck to 0.4 mm, no thinner. Freerouting doesn't read it; DRC does.

- **Signal fan-out (11/13, after routed1):** Freerouting left 12 connections open, all J2 / J3 signals and +5V: every
  ZIF pad exits toward +X, so the signals were boxed in on F.Cu beside the connector. Each ZIF signal pad now has a
  0.2 mm stub to its own via 1.3 mm past the pad (24 vias, 1.0 mm apart), and each +5V stub ends in a 0.8 / 0.4 mm via,
  so every one can drop to B.Cu at once. Unused ones come out after routing:
  `python3 ../SB1_sensor_board/tools/layout/postroute_dangling_vias.py <routed> <out>`.
- **J14 courtyard (11/13):** cut to the socket row; the breakout outline stays on F.Fab. The back sockets' pins under the
  breakout (it sits 11 mm up) had shown as 6 "PTH inside courtyard" errors.
- **Stick silk (11/13):** the CP2102 outlines stop 0.3 mm inside the bottom edge (sides only; the full stick is on
  F.Fab), and the text is "CHIP SIDE DOWN", which fits inside them.
- **+5V trunk, pre-routed (11/13, after routed2 / routed3 left 12-14 open):** 1.0 mm on F.Cu, locked: from J2's +5V
  stub down to y 67 (just below both ZIF housings), across to below J3's stub and up into it, and left to x 27, down
  and into C3. Freerouting had laid +5V wherever it liked and walled off the signals heading down to the sockets; now
  every ZIF signal drops to B.Cu at its fan-out via and passes under the trunk. J1 to C3 is left to Freerouting.
- `moveOmeter_MBUSB_prep3.kicad_pcb` (with its own `.kicad_pro` / `.kicad_dru`) is the board with all of this; route
  from it. (prep2 had +5V drop vias instead of the trunk.)

- **4 layers (11/13, John):** after routed1-3 (and prep3) all stopped with 12-15 connections open, the board went to
  4 layers (`tools/layout/to4layer_mbusb.py`, run by `rebuild.sh` before the fan-out): In1 GND plane, In2 +5V plane,
  both layer type "power" so Freerouting doesn't route on them, and two DRC rules ban tracks there. +5V is no longer
  routed: every SMD +5V pad has a 0.4 mm stub to its own 0.6 / 0.3 mm via into In2 (J2 / J3 pads 18-19 in the ZIF
  fan-out column, J1 A9 / B9, D1, C2, C3, R3); the 1 mm necks and the trunk are gone. The GND vias now join In1.
- `moveOmeter_MBUSB_prep4.kicad_pro` / `.kicad_pcb` / `.kicad_dru` is the 4-layer board; route from it. (prep3 has
  John's unfinished 2-layer routing.)

### Routing with Freerouting

1. Open `moveOmeter_MBUSB_prep4.kicad_pro`. In Board Setup > Net Classes, check `/Mainboard_USB/+5V` shows as Power.
2. File > Export > Specctra DSN (`freerouting.dsn`). Route in Freerouting, export the session (.ses).
3. In KiCad: File > Import > Specctra Session. Leave the locked fan-out stubs and vias alone.
4. Press B to fill the zones, then run DRC. Expect 0 unconnected; fix any +5V narrower than 0.4 mm by hand.
5. Save as `moveOmeter_MBUSB_routed.kicad_pcb`, then copy it over `moveOmeter_MBUSB.kicad_pcb` once it's clean. From
   then on KiCad owns the board; don't re-run `rebuild.sh` over it.
6. Optional: a few GND stitching vias across the big pours (Place > Add Vias, or KiCad's via stitching).

## Routed (11/13)

`moveOmeter_MBUSB.kicad_pcb` is the routed board: prep4 routed by Freerouting on 4 layers with nothing left open, then
the 12 fan-out vias it didn't use (and 6 stubs to them) removed; every signal net checked connected before and after.
DRC 11/13: 0 errors, 0 unconnected; 4 warnings that J4-J7 differ from the library copy (the library adds the full
stick outline on F.Fab; Tools > Update Footprints from Library clears them). 250 tracks, 49 vias. KiCad owns the board
now: `rebuild.sh` writes a regenerated board to `moveOmeter_MBUSB_unrouted.kicad_pcb` instead of over it. The prep and
routed* files are scratch (git-ignored).

