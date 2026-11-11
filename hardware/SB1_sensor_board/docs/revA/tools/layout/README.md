# SB1 layout scripts (2026-10-25; J3 stood on end and cut to 2x10 on 10/26)

These wrote the placed `moveOmeter_SB1.kicad_pcb`. They are adapted from TB1's `place4.py` / `mkpcb3.py` /
`verify3.py`. They find the project from where they sit (`<project>/tools/layout`). KiCad's footprint library is taken
from `/Applications/KiCad/KiCad.app/Contents/SharedSupport/footprints` on a Mac. To override the paths, set
`SB1_PROJ`, `SB1_FPDIR` or `SB1_V1` (the moveOmeter V1 board, whose layer table and stackup are copied).

- `plan_sb1.py out`: the fixed parts (holes, both radars, ribbon header J3 standing on end, the two USB-C ports).
  Board height `SB1_H` (default 56.5). It also works out from the netlist which pin each decoupling / input cap belongs
  to. Writes `out/plan.json` and `anchors.json` here.
- `place_sb1.py out out/plan.json`: fills in every other part by block (LD6004, LD2450, USB A, USB B, logic rail,
  ribbon). Each cap goes next to its pin, and the LD6004 buck is placed as one tight group. Rules: 0.27 in front mount
  clearance, radar fields of view, no through-hole pins behind the radars. Writes `out/placement.json`.
- `mkpcb_sb1.py out/moveOmeter_SB1.kicad_pcb out/placement.json`: writes the KiCad 10 board. It places and flips the
  footprints and puts a net on every pad. It also writes the outline, the 4-layer stackup with GND / +3V3 planes, the
  title block and the silk markers.
- `verify_sb1.py board netlist_report.csv`: reads the written board back and checks it. Checks: courtyards, pins under
  parts on the other side, mount clearance, radar fields of view, edges, and that every netlist pin has its pad and net.
- `BOARD=SB1 render2.py board out.png 70 56.5`: front / back picture.
- `arrangement.py docs/SB1_arrangement.png`: the two-SB1 + mainboard sketch.
- `silkspot.py board F|B w h`: free spots for a silk text box.
- `mkmicfp.py lib/SB1.pretty`: the Adafruit I2S mic breakout socket footprint (6049 / 3421); `render_micfp.py
  footprint out.pdf out.png`: its 1:1 check print and preview.
- `sx.py`, `schdata.py`: S-expression reader / writer and schematic reader.

Once routing starts in KiCad, the .kicad_pcb belongs to KiCad: don't rerun `mkpcb_sb1.py` over it.
