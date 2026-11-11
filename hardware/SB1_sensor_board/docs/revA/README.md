# moveOmeter sensor board SB1 (rev A draft, placed, not routed)

One HLK-LD6004 (60 GHz) and one HLK-LD2450 (24 GHz) on a 70 x 56.5 mm board with TB1's mounting holes. Each sensor
has its own USB-C port and USB-serial chip, so a PC can run both sensors with no mainboard. A 20-pin ribbon carries
5 V in and both serial ports out to the mainboard. Generated 2026-10-25 from `tools/` (same generator as TB1); on
2026-10-26 the ribbon header was stood on end and cut from 26 to 20 pins, and the board re-placed.

**Product arrangement:** two identical SB1s per frame or nightlight, fronts 90 degrees apart in a V with the point toward
the room (`docs/SB1_arrangement.png`).
- **Coverage:** each board points 45 degrees off straight-out, so every direction in front of the wall is within 45
  degrees of one radar's axis. With +/-60 degree radars that leaves 15 degrees to spare at the edges, about 210 degrees
  per radar type, and about 30 degrees of overlap straight ahead. A third board isn't needed.
- **Mainboard:** directly behind the two SB1s. It takes both ribbons on two 2x10 headers that also stand on end, at the
  same height as J3. Each flat cable then runs level, edge-on, and only bends sideways (the easy way) through the 45
  degrees between the boards.

## Open it

Open `moveOmeter_SB1.kicad_pro` in KiCad 10. The schematics are KiCad 8 format until KiCad saves them. Project
libraries: `lib/SB1.kicad_sym` and `lib/SB1.pretty` (radar modules and the front-mount hole, copied from TB1). Run ERC,
then Update PCB from Schematic (F8): it should only refresh fields. Run DRC before routing.

## Sheets

| Sheet | File | Contents |
| --- | --- | --- |
| Power_USB | power_usb.kicad_sch | 2x USB-C + USBLC6 + CH340C, 2x TPS2113A 5 V mux, BAT54C + LP5907 3.3 V logic rail, 20-pin ribbon, INA219 address jumper |
| LD6004 | ld6004.kicad_sch | TLV62569 3.3 V buck, INA219, rail discharge, TX gate, ESD, board-mounted module |
| LD2450 | ld2450.kicad_sch | TPS2051C 5 V switch, INA219, rail discharge, TX gate, ESD, board-mounted module |

## How it works

- **Power:** each sensor's 5 V comes from a TPS2113A that prefers the ribbon's 5 V and falls back to that sensor's
  USB-C. Neither input can back-feed the other (the mux FETs have no body diodes). USB-C A powers the LD6004 and USB-C
  B the LD2450, so each sensor gets a whole USB port. The 3.3 V logic rail (CH340Cs, monitors, gates) comes from
  either sensor's 5 V through a BAT54C and an LP5907 LDO.
- **Serial:** the sensor's TX goes to both its CH340C and the ribbon through 1k each. A 3-input AND gate
  (SN74LVC1G11) drives the sensor's RX from the CH340C TX, the ribbon TX and a "sensor rail is up" sense, so either
  host can talk (an idle UART line is high). The gate's output is held low while the sensor is off, so nothing
  back-powers it.
- **On/off:** each sensor is on by default (100k pull-up on EN).
  - The mainboard turns it off by pulling its ribbon EN line low.
  - The PC turns it off by asserting DTR with RTS released (a 2N7002 from RTS# to DTR#). Opening the port asserts both
    lines, which leaves the sensor on. In pyserial: `ser.rts = False; ser.dtr = True` for off, `ser.dtr = False` for
    on.
  - When EN goes low, the rail-discharge FET pulls the sensor rail to 0 V, so a power cycle is a clean reset.
- **Status lines:** LD6004 P20 and the LD2450 switch fault flag go to the ribbon and to each CH340C's CTS# input.
- **Current monitors:** INA219s at 0x40 (LD6004) and 0x44 (LD2450). Bridge solder jumper ADDR B on the second board
  of a pair to move them to 0x41 / 0x45. The I2C pull-ups are on the mainboard.

## Ribbon (J3, 2x10 shrouded header, 2.54 mm)

Wire n on the flat cable is pin n, and the cable is straight through, so the mainboard's headers use the same
pinout. The two +5 V wires and every serial and I2C wire have a ground wire on each side. The four enable / status
lines barely change, so they're grouped at the end without grounds between them.

| Pin | Signal | Pin | Signal |
| --- | --- | --- | --- |
| 1 | GND | 2 | +5 V in |
| 3 | +5 V in | 4 | GND |
| 5 | LD6004 TX (mainboard to sensor) | 6 | GND |
| 7 | LD6004 RX (sensor to mainboard) | 8 | GND |
| 9 | LD2450 TX (mainboard to sensor) | 10 | GND |
| 11 | LD2450 RX (sensor to mainboard) | 12 | GND |
| 13 | I2C SDA | 14 | GND |
| 15 | I2C SCL | 16 | GND |
| 17 | LD6004 enable (low = off) | 18 | LD2450 enable (low = off) |
| 19 | LD6004 P20 | 20 | LD2450 fault (low = fault) |

Seen from behind, pin 1 is at the top, odd pins in the left column, and the shroud's key slot on the left.

UART logic is 3.3 V. Baud rates: LD6004 115200, LD2450 256000. The CH340C makes 256000 as 12 MHz / 47 = 255.3 kbaud
(-0.3 %).

## Layout (70 x 56.5 mm, placed 2026-10-26, not routed)

- **Holes:** TB1's four M3 holes and footprint, with 0.27 in front-mount clearance. J3's shroud sets the board height:
  56.5 mm, 1.5 mm taller than the 70 x 55 mm v0.1 board whose holes it shares (64 mm with the 2x13 header).
- **Front:** LD6004 on the top edge, LD2450 under it (same positions as TB1), and the radar circuitry below them.
- **Back:** the ribbon header J3, a straight shrouded 2x10 standing on end (long side top to bottom), centred
  left-right. Its pins run from just below the LD2450 (27.6 mm from the top edge, pin 1 at the top) to 50.5 mm, and the
  shroud ends about 1 mm from the bottom edge. The cable leaves straight back, edge-on, toward the mainboard.
  - It can't sit behind the radars: no through-hole pins there, so the ground stays solid.
  - It can't sit near a side edge: on one board of each pair that edge is the point of the V, and the plug would hit
    the other board.
  - Also on the back: both USB-C ports on the bottom edge at the corners (bench use; unused in the unit), the
    USB-serial chips, the 5 V muxes and the 3.3 V LDO.
- Nothing is on the side edges: with two identical boards in a V, one board's outer edge is the other's inner edge.
- **Stackup:** 4 layers, F.Cu signals + GND / In1 GND / In2 +3V3 / B.Cu signals + GND. Fill zones after routing.
- **Checks:** all rule checks pass (mount clearance, radar fields of view, no through-hole pins behind the radars,
  edges, nets).

## Ordering

`bom_board.csv` has DigiKey numbers and qty-1 prices: about $49 a board, not counting the two radar modules. The
exception is the CH340C: WCH chips aren't sold by DigiKey or Mouser, so it comes from LCSC (part C84681). Buy a few
spares.

The ribbon cable isn't in the BOM, because its length depends on the mainboard. Any keyed 20-way 2.54 mm IDC cable
with a socket on each end fits. One example is Assmann H3AAH-2006G (LCSC C1770517), which can go in the same order as
the CH340Cs.

## Ready for rev B: mic socket

Rev B (decided on the 10/26 evening drive, not built yet) gets two Adafruit I2S mic breakouts per board. Their socket
is already in the libraries: symbol `SB1:I2S_Mic_Breakout`, footprint `SB1:Adafruit_I2S_Mic_Breakout_Socket_1x06`.

- **Breakouts:** Adafruit 6049 (TDK ICS-43434) or 3421 (Knowles SPH0645). Adafruit's board files show the same
  16.51 x 12.7 mm outline, header, sound-hole position and holes, so either plugs in. Adafruit's 6049 page says the
  ICS-43434 is discontinued and names the SPH0645 as its replacement.
- **Amazon clone (B0FMDGRM8F, silk "MRS179A"), 10/26:** a copy of Adafruit's 6049 layout. From the listing photo: same
  pin order (3V, GND, BCLK, DOUT, LRCL, SEL), same parts, sound hole about 5.3-5.5 mm from the pin row and centred,
  holes about 11.4 mm apart. The board may be up to ~1 mm narrower on the header side, which stays inside the
  footprint's outline. The listing calls SEL an I2S / PDM select; on the ICS-43434 it's the left / right channel
  select, as on Adafruit's board (the chip is I2S only). Fits the same socket.
- **Pins (from Adafruit's board files):** 1 3V, 2 GND, 3 BCLK, 4 DOUT, 5 LRCL (WS), 6 SEL. SEL low = left channel,
  high = right, so the two mics on a board share one data line.
- **Mounting:** a 1x6 female socket (Sullins PPTC061LFBN-RC, 8.5 mm) on SB1's front. Solder the breakout's header
  with its plastic on the chip side (the side shown in Adafruit's photo), so the pins point away from that side and
  the sound hole faces the room. The breakout lies parallel to SB1, its sound hole about 12.6 mm off the board.
  Seen from the front, pin 1 (3V) is at the right, on the square pad.
- **Check print:** `docs/SB1_mic_socket_1to1.pdf` (print at 100 %, check the 50 mm bar). Lay a breakout on it sound
  hole up: the pins should land on the pads with 3V on the square pad, and the sound hole on the cross.
- **Source:** `tools/layout/mkmicfp.py` writes the footprint; `tools/layout/render_micfp.py` draws the check print.

## Regenerating

- `python3 tools/build.py <out>` writes the schematics, symbol library, netlist report and BOM. Parts and nets are in
  `tools/design.py`, ordering data in `tools/vendor.py`.
- `tools/layout/` writes and checks the board (see its README): `plan_sb1.py`, `place_sb1.py`, `mkpcb_sb1.py`,
  `verify_sb1.py`. `render2.py` draws it (`docs/SB1_board.png`). `arrangement.py` draws the three-board sketch.
- Once you edit in KiCad, KiCad is the source of truth.
