# Mainboard-USB layout scripts (2026-10-31)

Adapted from SB1 rev B's. Run them all with `sh tools/rebuild.sh`.

- `mkfp_mbusb.py lib/MBUSB.pretty`: the project footprint for the Adafruit 4162 VEML7700 breakout socket.
- `place_mbusb.py docs`: the placement table (front-view coordinates, `[x, y, rot, side]`), plus the back-silk parking
  pads, zip-tie slots and labels. Writes `docs/placement.json` and `docs/env.json`.
- `mkpcb_mbusb.py moveOmeter_MBUSB.kicad_pcb docs/placement.json`: writes the KiCad 10 board (2 layers, GND pours,
  outline, slots, V outline on F.Fab, notes). Reads the pads / slots / labels from `MB_PADS`, `MB_SLOTS`, `MB_LABELS`
  (rebuild.sh sets them from env.json) and needs `SB1_ROOT=moveOmeter_MBUSB.kicad_sch`.
- `verify_mbusb.py board netlist_report.csv docs/env.json`: the rule check (see the main README). Other parts'
  through-hole pin stubs may sit under the socketed breakout J14.
- `BOARD=MBUSB render2.py board docs/MBUSB_board.png 100 150`: front / back picture.
- `mkpro_mbusb.py <SB1 .kicad_pro> <project dir>`: wrote `moveOmeter_MBUSB.kicad_pro` once from SB1's.
- `sx.py`, `schdata.py`: shared with SB1 (S-expression reader / writer, schematic and footprint loading).
