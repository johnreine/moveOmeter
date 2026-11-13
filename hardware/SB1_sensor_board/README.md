# moveOmeter sensor board SB1 (rev B, routed 11/10; final checks 11/13)

Rev B is the minimal, hand-solderable sensor assembly used unchanged in the nightlight and the frame. One HLK-LD6004
(60 GHz), one HLK-LD2450 (24 GHz), two I2S mic breakouts, a VEML7700 light sensor and an ID EEPROM on a 42 x 76 mm,
4-layer board. Power switching, current monitoring and USB-serial moved to the backboard (Mainboard-USB now, the
ESP32-S3 Mainboard later). Generated 2026-10-31 from `tools/`.

Rev A (70 x 56.5 mm, USB-C + CH340C per sensor, muxes, INA219s, 2x10 ribbon) is kept in `docs/revA/`, with its
README, schematics, board and the tools that built it.

**Product arrangement:** two identical SB1s per unit, fronts 90 degrees apart in a V with the point toward the room.
The V stands 35 mm out from the backboard, which stands upright behind it, parallel to the wall, so the unit stays
slim. Each SB1 connects with a short 20-way 1.0 mm FFC from the ZIF at its outer end to a ZIF on the backboard.

## Open it

Open `moveOmeter_SB1.kicad_pro` in KiCad 10. The schematics are KiCad 8 format until KiCad saves them. Project
libraries: `lib/SB1.kicad_sym` and `lib/SB1.pretty`. Run ERC, then Update PCB from Schematic (F8): it should only
refresh fields. Run DRC before routing.

## Sheets

| Sheet | File | Contents |
| --- | --- | --- |
| Power_IO | power_io.kicad_sch | FFC ZIF J7 (one since 11/8), 5 V TVS, LP5907 3.3 V LDO, LED, two I2S mics, 24AA256UID, VEML7700, I2C pull-ups, spare header |
| LD6004 | ld6004.kicad_sch | Isolation link, TLV62569 3.3 V buck, UART series resistors, board-mounted module |
| LD2450 | ld2450.kicad_sch | Isolation link, ferrite + bulk filtering on 5 V, UART series resistors, module mounted upright |

## How it works

- **Power:** 5 V comes in on two FFC wires, with an SMBJ5.0A TVS and 10 uF + 100 nF at the connectors.
  - The LD6004 gets 3.3 V from a TLV62569 buck (453k / 100k divider, 3.32 V).
  - The LD2450 runs from 5 V through a ferrite and 22 uF + 10 uF + 100 nF.
  - An LP5907 makes +3V3 for the mics, EEPROM, light sensor and I2C pull-ups only (~5 mA). It never feeds a radar.
- **Isolation links:** each radar's 5 V goes through a fitted 0 ohm 1206 (R7 LD6004, R12 LD2450), with an open
  solder jumper beside it (JP1, JP2). Remove the resistor to run the other radar alone; bridge the jumper to put it
  back without a resistor.
- **Serial:** 100 ohm series resistors on every UART line: the radar-TX one at the module, the radar-RX one at the
  ZIFs. LD6004 P20 goes straight to the FFC. UART logic is 3.3 V. Baud rates: LD2450 256000; LD6004 115200 by datasheet default, but the bench modules were set to 460800 on 10/14 and keep that setting, so run the host at whatever the module is set to.
- **Mics:** two Adafruit 6049 I2S breakouts, soldered flat to the back at the top edge (see Layout). J1 has SEL
  low (left channel), J2 SEL high (right), so they share one data line. 33 ohm series resistors: BCLK and WS at the
  ZIFs, data at the mics.
- **I2C:** 24AA256UID ID EEPROM at 0x50 (unique 32-bit serial) and VEML7700 at 0x10, with 4.7k pull-ups to +3V3. Both
  SB1s are identical; the backboard keeps them on separate buses.
- **Light sensor:** the VEML7700-TT footprint (U4 + C8) stays on the front, but both are DNP for now (John, 10/31): on
  the bench the light sensor is an Adafruit 4162 breakout on Mainboard-USB, at the same address (0x10). Fit U4 and C8
  (hot air) when the board goes into a unit without that breakout.
- **LED:** red 5 V LED, off unless JP3 is bridged.
- **Spare:** J6 (1x3) brings out the two spare FFC wires and GND.

## FFC link (J7, Molex 200528-0200)

20-way, 1.0 mm pitch ZIF, bottom contact, front-flip actuator (KiCad's footprint calls it "BackFlip"; Molex lists the
200528 as front flip), with an ear-tab lock that holds an eared cable in through shipping. **Since 11/8 (John) there is
one ZIF per board, J7 (left edge, seen from the front), standing on end on the back and opening toward the board's
centre.** J3 (the right-edge twin, wired in parallel) is gone, so each signal has one connector and no stub, and there
is no bus across the board. J7 is wired in reverse (pad n = wire 21 - n, since 11/7), so GND is at the bottom.
Pin numbers below are FFC wires.

| Pin | Signal | Pin | Signal |
| --- | --- | --- | --- |
| 1 | GND | 11 | I2S BCLK |
| 2 | +5 V in | 12 | GND |
| 3 | +5 V in | 13 | I2S WS |
| 4 | GND | 14 | I2S data (mics to backboard) |
| 5 | LD6004 TX (sensor to backboard) | 15 | GND |
| 6 | LD6004 RX (backboard to sensor) | 16 | I2C SDA |
| 7 | GND | 17 | I2C SCL |
| 8 | LD2450 TX (sensor to backboard) | 18 | LD6004 P20 |
| 9 | LD2450 RX (backboard to sensor) | 19 | Spare 1 |
| 10 | GND | 20 | Spare 2 |

Drawings: `docs/ffc_top_view.png` (top view to scale with X / Y dimensions, cable paths, contact face; script
`tools/layout/ffc_single_draw.py`) and `docs/ffc_links_flat.png` (each link unfolded, pin heights at both ends;
`tools/layout/ffc_draw.py`).

### Cable routes (loop routing 11/4; one ZIF 11/8)

Top view, mm: X from Mainboard-USB's left edge seen from the room, Y out from its front face. SB1-A's back runs from its
outer end (20.3, 5.3) to the apex (50, 35); SB1-B mirrors it. Both SB1s use J7, so on SB1-B it is at the outer end and on
SB1-A it is near the apex.

- **SB1-B (right):** the cable leaves J7 at (72.8, 9.6) toward the apex, lies flat on the back for about 11 mm, makes a
  U-turn (r 6 mm) into the V (nearest the room at (60.6, 19.4)), runs back toward the wall and bends 45 degrees (r 6 mm)
  into Mainboard-USB J3, mouth (67.0, 1.0), coming in from the centre. Unchanged from 11/4.
- **SB1-A (left):** J7 sits near the apex, its mouth at board x 7.9 opening toward SB1-A's outer end. The cable lies flat
  on the back for about 24 mm (board x 7.9 to ~31.9, over the LD2450 ground area, where no parts are allowed), then
  swings round 135 degrees (r 6 mm; furthest out at (27.0, 7.0), 2.8 mm clear of the SB1-A back) and comes straight into
  Mainboard-USB J2, mouth (38.9, 1.0), from the left. J2 was turned round on 11/8 to open toward -X.
- The two cables stay 15 mm apart. Every bend is across the cable's thickness, about a vertical axis, and the cable
  never twists, so each conductor stays at the same height from end to end.
- Both need 44 mm free plus about 3.5 mm inside each connector: **the same ~51 mm cable on both sides.** Length error
  goes into the U-turn (SB1-B) or the swing (SB1-A).
- On SB1 the cable needs a flat lane on the back: from J7's mouth to the LD2450 ground zone (x 7.9-10.5) and, for
  SB1-A's longer run, from the zone to x 34.1 (where J3 used to be), y 29.4-55.6, full cable width including ear tabs.
  `place_sb1b.py` keeps both clear (`LANES` in `docs/layout.json`) and `verify_sb1b.py` fails if a part lands in them.
- **Assembly:** SB1-A's ZIF is in the narrow part of the V (about 9 mm between the board backs there). Plug its cable in
  and close the latch before both boards go into the bracket.

### Pins and cable faces (11/8; from the pad positions in both board files)

| Connector | Wired | GND (wire 1) at | Pad at the bottom |
| --- | --- | --- | --- |
| SB1 J7 (both boards) | **reversed, pad n = wire 21 - n** | bottom (SB1 y 52 = MB y 60) | pad 20 |
| Mainboard-USB J2 (SB1-A) | **reversed** (turned round 11/8) | bottom (MB y 60) | pad 20 |
| Mainboard-USB J3 (SB1-B) | **reversed** | bottom (MB y 60) | pad 20 |

- Both links are now identical: SB1 J7 to a reversed Mainboard ZIF that opens toward -X. The check script matches every
  SB1 J7 pad with the Mainboard-USB pad at the same height: 20 / 20 signals agree on both links. The full Mainboard
  must do the same (both ZIFs reversed, both opening toward -X, J2 at X 38.9).
- **Contact face:** both connectors are bottom contact, so the exposed conductors face the SB1 at one end and the
  Mainboard at the other. Following each cable round (SB1-B: U-turn then 45 degrees; SB1-A: one 135 degree swing), that
  is the same face of the cable all the way: **same-side contacts, Type A,** the same way up (GND on the bottom wire).
- **Why Type A is safe:** plugged in flat with no twist, it can only connect pin for pin. Twisted half a turn or put in
  face-over, its contacts face away from one connector, so nothing connects and nothing is damaged.
- **Never use Type D (opposite-side) here.** It only makes contact at both ends if it's twisted, and the twist reverses
  every pin: +5 V lands on P20 and Spare 1.
- The bracket must hold each SB1's top edge at Mainboard-USB y 8 to about +/-0.5 mm: the cable can't bend across its
  width to take up a height mismatch.

### Cable to buy

- **Bench:** any 20-way, 1.00 mm pitch, same-side (Type A) FFC about 50 mm long, e.g. GCT 10-20-A-0050-C-4-08-4-T
  (DigiKey), Molex Premo-Flex 15039 series (gold, which matches the 200528's gold contacts) at 51 mm. These have no ear
  tabs; check in hand that the 200528 holds a cable without ears securely.
- **Units: eared, made to order.** The 200528 has an ear-tab lock (housing indents that take the cable's tabs, for
  alignment and retention). Molex's eared Premo-Flex jumpers (15018, FD19) are 0.5 mm pitch only, and the cable Molex
  lists for the 200528 (15039) has no ears, so an eared 1.0 mm cable is a custom part (Chinese FFC makers, or Molex
  custom Premo-Flex). The ear and notch dimensions come from the "recommended FPC/FFC" view of Molex's 200528 sales
  drawing (cable width = circuits + 1 = 21 mm for 20 circuits). Spec: 20 conductors, 1.00 mm, Type A, ~51 mm, ears at
  both ends, gold-plated exposed ends, stiffeners on the non-contact face.
- Paper mock-up before ordering: a 51 mm strip, "1" written on the same edge at both ends and the contact face marked.

The 24-way 200528-0240 isn't stocked at qty 1 (9000 MOQ), so rev B uses the stocked 20-way part and a 20-wire
pinout.

## Layout (42 x 76 mm, placed 2026-10-31, not routed)

Front-view coordinates, origin at the top-left corner. On 10/31 the mics moved to the back and the board shrank by
10 mm: everything below the mics moved up 10 mm. `place_sb1b.py` holds the table (`SHIFT`) and writes
`docs/layout.json` (height, holes, ground zone, silk marks), which the board script and the rule check read.

- **Holes:** four M2.5 (2.7 mm NPTH) at (3.5, 8.3), (38.5, 8.3), (3.5, 72.5), (38.5, 72.5). Screws go in from the
  front, into a 3D-printed bracket that holds both SB1s to the backboard. Keep-out: 3.0 mm front, 3.3 mm back.
- **Mics (back, top edge):** J1 at x 10, J2 at x 32, header rows 2 mm in. Each breakout lies flat against SB1's back,
  sound-hole side toward SB1, and overhangs the top edge by 8.2 mm, so the sound hole (3.3 mm past the edge) has open
  air on both sides. Pull the black plastic off the 1x6 header so the breakout sits flush; the pins go through both
  boards and are soldered on both. Top of the breakout is about 2.6 mm off the back, under the 3 mm limit in the side
  strips. It has to be the 6049: the 3421 has parts on its sound-hole side and won't sit flush. Keep the area past the
  top edge clear in the bracket, front and back, for both sound holes.
- **LD6004 orientation:** its two 1x5 sockets are the same, so the module fits either way round. J4's front silk
  draws the module as seen from the antenna side: the hatched antenna block toward the debug (left) end, with an
  "ANTENNA" bracket above the outline so it can still be checked once the module is in, and the pin names on the
  signal (right) row. Fit it antenna side up with the antenna over the hatched block. Picture:
  `docs/SB1_LD6004_silk.png`.
- **LD2450 orientation:** its 2x4 socket is symmetric too. J5's front silk adds the module's antenna group (hatched,
  at the end away from the header, where the white 4-pin socket is), the radar chip and an "ANTENNA" bracket beside
  the outline, on top of the notched outline that was already there. Positions are from Hi-Link's STEP; the antenna
  end matches the 10/30 bench check. Picture (footprint view; on SB1 the antenna end is at the top):
  `docs/SB1_LD2450_silk.png`.
- **Front, top to bottom:** H1 / H2; LD6004 (J4) at y 16.5 (moved up 3 mm on 10/31, see Rules); LD2450 (J5) at y 46.2, turned +90 degrees so its patch
  group is at the top and its 2x4 header at the bottom (upright, its x reading is mirrored against the bench mount:
  firmware `LD2450_X_SIGN` should be +1; recheck with a walk test at bring-up); VEML7700 (U4, DNP) on the centreline at
  y 71; H3 / H4.
- **Back:** the small parts (LED group at the top left, EEPROM, LDO, TVS, mic supply parts, buck feedback) fill the
  band under the mics; `place_sb1b.py` places them by searching for the nearest free spot to an anchor. The LD6004
  buck in one row at y 18.6. The ZIF on end at the left edge (J7 at x 5, centred on y 42.5; J3 at x 37 removed 11/8),
  opening toward the board centre (11/4), with a clear cable lane in front of it and on past the LD2450 zone to x 34.1. The series resistors and links that
  used to sit in a column at x 8.7 are placed by the search (11/4): C14 / R10 at the LD6004 signal row, R7 / JP1 at the
  buck input, R11 / R14 / R2 / R3 at the ZIF ends. The LD2450 filter parts and J6 at the
  bottom.
- **Rules (all pass):**
  - Radar fields of view: nothing taller than a radar face inside its cone. The LD2450 cone is kept in board axes.
  - Radar to radar (added 10/31): the LD2450 stands about 1 mm taller than the LD6004's antenna face (board top
    ~7.55 mm vs 6.55 mm), so its edge has to stay 1.73 x 1.0 + 0.5 = ~2.2 mm from the LD6004's antenna block. With the
    LD6004 at y 19.5 it was 0.43 mm short; at y 16.5 there's 2.6 mm to spare (the modules are 4.2 mm apart). The
    rule check prints this margin. The LD6004 is the lower one, so it never shadows the LD2450.
  - The LD6004 sits ~0.75 mm lower than the LD2450 (shorter sockets). That only matters for the front cover: pick
    a cover distance that suits both (for example ~11.75 mm above the LD2450 puts the LD6004 at 12.5 mm, 5 x half a
    60 GHz wavelength, with the LD2450 inside its 12.4 +/- 1.2 mm window).
  - No through-hole pins behind either radar (LD2450 + 3 mm).
  - Solid ground behind the LD2450 + 3 mm on B.Cu, In1 and In2 (rule area: no tracks, vias or parts; pads and pour
    allowed).
  - Back parts in the 6 mm side strips no taller than 3 mm, because the other board of the V sits there.
  - Hole keep-outs, edges, and every netlist pin has its pad and net.
- **Stackup:** 4 layers, F.Cu signals + GND / In1 GND / In2 GND / B.Cu signals + GND. Fill zones after routing.

## Ordering

`bom_board.csv` has DigiKey numbers and qty-1 prices: about $41.50 a board including the mic breakouts, not counting the
radar modules (the DNP VEML7700 and its cap aren't counted). Everything fitted is 1206 or larger, or through-hole, and
hand-solderable; the VEML7700-TT, when fitted, needs hot air or a hot plate. The FFC isn't in the BOM yet (source still open).

## 3D models

KiCad's library has models for the standard parts. The rest are in `3dmodels/`, written by `tools/layout/mk3d.py` (run
by `tools/rebuild.sh`) and referenced as `${KIPRJMOD}/3dmodels/...` in the footprints. The `.wrl` files are VRML, so KiCad's
3D viewer shows them, but a STEP export of the board leaves them out. The two radar modules are STEP files.
- `SB1_Adafruit_6049_Mic_back.wrl` (J1, J2): Adafruit's own model of the 6049 breakout, from
  `adafruit/Adafruit_CAD_Parts` (the original STEP and 3MF are in `3dmodels/vendor/`). It sits flush on the back,
  sound-hole side toward SB1, overhanging the top edge, with the header pins through both boards.
- `Module_HLK-LD2450.step` (J5): the LD2450 STEP (added by John, 10/31). The footprint turns it 180 degrees and sets the
  module's back 6.3 mm up.
- `HLK-LD6004_module.step` (J4): a STEP model built by `tools/layout/mkstep_ld6004.py` from Hi-Link's dimension drawing.
  It has the 35 x 7 mm board, the antenna block (10 mm wide, 8 mm from the debug end), both 1x5 1.27 mm male headers
  and the main parts on the component side (placed approximately, from the drawing's photo). The board bottom is
  5.5 mm up (4.5 mm socket + 1.0 mm header plastic), which puts the antenna face at about 6.55 mm. Its frame matches the
  LD2450 model (origin at the board centre, board bottom at z = 0, antenna side up), so it also works in enclosure CAD.
- `SB1_VEML7700-TT.wrl` (U4): a simplified 6.8 x 3.0 x 2.35 mm body.
- `Molex_200528-0200_approx.wrl` (J7): a simplified housing, actuator and contacts.
- Mounting holes and solder jumpers have no model, as in KiCad's own library.
- The Molex 200528-0200 footprint points to an official STEP file that this KiCad install doesn't have. The board uses
  the approximate model instead (`MODEL_OVERRIDE` in the board script).

## Regenerating

`sh tools/rebuild.sh` rebuilds everything: schematics, library, netlist report and BOM (`tools/build.py`), the project
footprints (`mkfp_sb1b.py`), placement (`place_sb1b.py`), board (`mkpcb_sb1b.py`), project file (`fixpro_sb1b.py`),
then runs the rule check (`verify_sb1b.py`) and draws `docs/SB1_board.png`. Parts and nets are in `tools/design.py`,
ordering data in `tools/vendor.py`, the placement table in `tools/layout/place_sb1b.py`.

Rev A's layout scripts (`plan_sb1.py`, `place_sb1.py`, `mkpcb_sb1.py`, `verify_sb1.py`, `arrangement.py`) are still
in `tools/layout/` for reference; `docs/revA/tools/` holds the full rev A generator.

Once you edit in KiCad, KiCad is the source of truth.

## Silkscreen labels (11/6)

`tools/layout/silkrefs.py` (run by `rebuild.sh` after the board is written) moves every reference designator beside its own part so the board can be debugged with everything fitted: never under a part body, off pads, other silk and other labels, 0.5 mm inside the edge. Text is 0.8 mm (0.12 stroke), dropping to 0.7 / 0.6 mm only where there's no room (on SB1 only C11, at 0.6 mm). The module pin labels under the LD6004 / LD2450 and the CP2102 notes stay where their footprints put them. If you move a part in KiCad, move its label by hand: once routing starts, KiCad owns the board.

## Ground behind the radars (11/6)

- **LD2450 (+3 mm):** rule area on B.Cu, In1 and In2: no tracks, vias or parts, so all three layers stay solid GND.
- **LD6004:** In1 / In2 are unbroken GND planes behind it (see below). Its footprint used to keep the front pour
  track-free under the module too; that keep-out was removed on 11/9 (John, option A) because the strip behind the
  LD6004 (buck, LDO, TVS) then had only B.Cu to route on. In1 is a solid plane right under the module.
- **In1 / In2 everywhere (11/6):** both inner layers are GND planes, layer type "power", and tracks on them are banned by
  two custom DRC rules in `moveOmeter_SB1.kicad_dru`. Route on F.Cu and B.Cu only. Vias are allowed: GND vias join the
  planes; keep signal vias few, each one opens an antipad hole in both planes. (The first Freerouting pass put ~720 mm
  of tracks on In1 / In2.)
- **Why the ban isn't a rule area any more (11/10):** from 11/6 it was a board-wide rule area on In1 / In2. KiCad
  exports rule areas to the DSN, this one as a "wire_keepout", and Freerouting treats that as a keep-out for vias too,
  so four Freerouting runs (routed5-8) placed no vias at all and left 23-31 connections open. (On 11/9 I blamed the
  "power" layer type instead and switched it to "signal"; that changed nothing, and it's back to "power".) Custom DRC
  rules aren't exported, so KiCad still flags any inner track while Freerouting can place vias.

## Mounting holes (11/6)

Unplated (NPTH, 2.7 mm for M2.5): the screws go into heat-set inserts in a printed holder, and nothing needs the screw at
ground. Rule areas round each hole ban tracks and vias within 3.0 mm of the centre on F.Cu (screw head, ~5 mm) and
3.3 mm on B.Cu (insert and holder boss). GND pour is allowed there. Parts are kept off by the hole courtyards.

## Routing with Freerouting (11/6)

1. Open `moveOmeter_SB1.kicad_pcb` (the generated board, not a routed copy). Check Board Setup > Board Stackup > Board
   Editor Layers shows In1.Cu and In2.Cu as "power".
2. File > Export > Specctra DSN (overwrite the old `freerouting.dsn`).
3. In Freerouting, open the DSN and check In1 / In2 are not offered as routing layers before you start.
4. Route, then export the session (.ses). In KiCad: File > Import > Specctra Session.
5. Press B to fill the zones, then run DRC. Leave the locked GND fan-out vias alone (see below). Expect: no tracks on In1 / In2, none inside the hole keep-outs (Freerouting
   may not honour KiCad's rule areas; DRC flags any track inside one, so move those by hand), and +5V necked down to
   0.3-0.4 mm into the ZIF pads.
6. Save under a new name (e.g. `moveOmeter_SB1_routed.kicad_pcb`). From then on KiCad owns the routed board.

## GND fan-out and power-track rules (11/7)

The first routed board (routed2) had no GND vias at all, so the routing chopped the outer GND pours into islands and
20 GND pads ended up unconnected. The board now comes with the fan-out done before routing:

- `tools/layout/fanout_gnd.py` (run by `rebuild.sh` after the project file) gives every SMD pad on GND a 0.3 mm stub
  track to its own 0.6 / 0.3 mm via into the In1 / In2 planes: one per pad (U1.2's second via, under the IC body, was dropped on 11/8: it blocked the buck's routing).
  The ZIF GND pads (J7, plus its mounting tab) get theirs on the housing side, so the signal pins keep the
  cable side free for their exits. Every via is at least 0.43 mm from any other net's pad, outside the screw keep-outs
  and the LD2450 solid-ground area. The stubs and vias are locked so the autorouter routes round them.
- Power net-class pattern fixed: the LD2450 rail is called `/LD2450/+5V_2450` (it sits in a sheet), so the pattern is
  now `*+5V_2450`; it had been routed at 0.2 mm as a signal.
- `moveOmeter_SB1.kicad_dru` (written by `fixpro_sb1b.py`): power tracks must be at least 0.4 mm (0.5 mm is the
  Power class width), except where a track enters a fine-pitch part's courtyard (J7, JP1-3, U1-U4), where it may
  neck down to 0.25 mm. Freerouting doesn't read this file; it routes at the class width, and DRC flags anything
  thinner.
- Your project-file settings (clearance 0.1421, min clearance 0.1316, min resolved spokes 2) are kept: the rebuild
  starts from your `.kicad_pro`.

If DRC still reports starved thermals on the ZIF GND pads, they are harmless now that each pad has its own via;
set Board Setup > Constraints > Minimum thermal relief spoke count to 1 rather than adding copper.

## J3-J7 bus (11/8, removed the same day)

The bus between the two ZIFs was pre-routed straight across (`tools/layout/bus_route.py`) and then made unnecessary
when John dropped J3 (one ZIF per board). The script is no longer run by `rebuild.sh`.

## Routing aids (11/8-11/9)

After the 11/8 Freerouting run (31 unconnected, 17 edge errors):
- **Edge strips:** Freerouting doesn't see KiCad's 0.5 mm board-edge clearance, so a 0.4 mm no-track / no-via rule area
  runs inside each edge on F.Cu and B.Cu (`mkpcb_sb1b.py`). Pads and pour are still allowed there.
- **J7 signal fan-out** (`tools/layout/fanout_j7.py`, run after the GND fan-out): every non-GND J7 pad gets a short stub
  to its own via in the same column as the GND vias, so each signal reaches the open front strip beside the connector.
  Signals 0.2 mm, +5 V 0.5 mm, vias 0.6 / 0.3, locked.
- **LD6004 front keep-out removed** (11/9), see Ground behind the radars.
- R2 / R3 (I2S BCLK / WS series resistors) moved from the old J3 end to beside J7.

## Routed (11/10)

`moveOmeter_SB1_routed9.kicad_pcb`: Freerouting, once the inner-layer rule area was gone (see Ground behind the radars):
0 unconnected, 38 vias of its own (87 in all), nothing on In1 / In2. DRC left 2 short 0.1 mm necks on P20 and 5 J7
fan-out vias Freerouting didn't use. `moveOmeter_SB1_routed10.kicad_pcb` is routed9 after two clean-up scripts:
- `tools/layout/postroute_dangling_vias.py in out`: removes vias joined on only one layer (the 5 unused J7 vias, and the
  3 stubs that then led nowhere). GND vias are kept: they join the inner planes.
- `tools/layout/widen_tracks.py in out`: widens each thin track as far as its surroundings allow (power to 0.5 mm,
  signals to 0.2 mm), keeping every other net's pads, tracks and vias at their class clearance and 0.5 mm off the edge.
  86 tracks widened; 1.2 mm of +5V stays at 0.375 mm (boxed in, still above the 0.35 mm minimum).
Checked after: no clearance violations on the widened tracks, nothing inside a rule area. Refill zones (B) and rerun DRC.
- **Rebuilds no longer touch the routed board (11/10):** `tools/rebuild.sh` checks `moveOmeter_SB1.kicad_pcb`; if it has
  any track the generator didn't lay (an unlocked segment), the generated board goes to `moveOmeter_SB1_unrouted.kicad_pcb`
  instead. Schematics, BOM, netlist, project patterns and design rules are still regenerated.

## Ordering (11/10)

Every fitted part has Manufacturer, MPN, Vendor, Vendor Part #, Price (DigiKey qty 1) and Vendor Link fields in the
schematic, so KiCad's BOM export (Symbol Fields Table > Export, or Generate BOM) carries them. All of it comes from
`tools/vendor.py`, and every line was checked on digikey.com on 11/10. Fixed then: J7's DigiKey link pointed at a dead
listing (the part is active, 900-2005280200CT-ND); the mic breakouts are bought from DigiKey (1528-6049-ND, same $8.95);
a few prices moved by a cent. Two Murata 1210 caps (GRM32DR71E106KA12L, GRM32ER61E226KE15L) are "Not for new designs" at
DigiKey but stocked in the hundreds of thousands: fine for these builds, worth replacing before volume.

`tools/mkorders.py` (run by `rebuild.sh`) writes:
- `fab/SB1_revB_assembly_BOM.csv`: for an assembly quote. One line per part type: designators, qty, description,
  package, manufacturer + MPN, DigiKey PN, price, SMT/THT, side, and whether to fit it. All 40 SMT placements are on the
  bottom side; THT is J4 (two 1x5 sockets, front), J5 (2x4 socket, front), J6 (1x3 header) and the two mic breakouts
  (soldered flat on the back, overhanging the top edge). C8 and U4 are DNP. Send it with the Gerbers and the position
  file from KiCad (File > Fabrication Outputs > Component Placement, CSV, mm, both sides).
- `purchase/SB1_revB_digikey_upload.csv`: for DigiKey's BOM Manager. Quantities are per board (set the number of boards
  there): every fitted part, J4's second socket, the LD6004's two 1x5 male headers and one FFC cable (Molex 0150390357,
  51 mm Type A).
- `purchase/SB1_revB_other_parts.csv`: what DigiKey doesn't sell (the two radar modules), with links.

After a schematic field change, open the routed board and run Tools > Update PCB from Schematic (F8): it copies the
fields onto the footprints and leaves the routing alone.

## Connector pinouts on the silkscreen (11/11)

`tools/layout/pinlabels.py` (run by `rebuild.sh` after `silkrefs.py`, and run once on the routed board) puts each
connector's pinout in free space beside it, so the board can be probed with everything fitted:
- **J7 (FFC, back):** pad number and signal on every row, right of the ZIF, in the LD2450 ground area (no parts there;
  on SB1-A the cable lies over it). Header line: "J7 FFC: pad, signal (wire = 21 - pad)".
- **J6 (spare header, back):** SPARE1 / SPARE2 / GND beside the pins.
- **J5 (LD2450 header, pins seen on the back):** 5V 3V3 PA9 GND above the top row, RX TX DP DM below the bottom row,
  the same names as the module's own front labels (which the module hides once it's fitted).
- **J4 (LD6004, front):** 3V3 / GND / RX / TX beside the signal pins, outside the module's outline; P20 under pin 1.
- **J1 / J2 (mics, pins seen on the front):** 3V3 GND BCLK DOUT WS SEL under the pins, in two staggered rows.

All 0.8 mm text, centred (back ones mirrored). The script fails if a label would touch a pad, a part body, other silk
or the 0.5 mm edge margin, and moves a reference designator aside if it's in the way (H1 and R13 moved).
