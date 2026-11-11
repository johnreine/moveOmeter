#!/bin/sh
# Rebuild Mainboard-USB rev A from the generators: schematic + BOM, placement (+ silk pads / slots / labels), board,
# then the rule check and the board picture. The project file is written once from SB1's by tools/layout/mkpro_mbusb.py.
# usage: sh tools/rebuild.sh   (from anywhere). Set SB1_FPDIR / SB1_V1 as for SB1 if needed.
set -e
P=$(cd "$(dirname "$0")/.." && pwd)
cd "$P/tools" && python3 -B build.py "$P"
cd "$P"
export SB1_ROOT=moveOmeter_MBUSB.kicad_sch SB1_FPLIB="$P/lib/MBUSB.pretty"
python3 -B tools/layout/mk3d.py "$P" MBUSB
python3 -B tools/layout/mkfp_mbusb.py lib/MBUSB.pretty
python3 -B tools/layout/place_mbusb.py docs
eval "$(python3 -B -c "import json;e=json.load(open('docs/env.json'));[print(f\"export {k}='{json.dumps(v)}'\") for k,v in e.items()]")"
python3 -B tools/layout/mkpcb_mbusb.py moveOmeter_MBUSB.kicad_pcb docs/placement.json
python3 -B tools/layout/silkrefs.py moveOmeter_MBUSB.kicad_pcb
python3 -B tools/layout/verify_mbusb.py moveOmeter_MBUSB.kicad_pcb netlist_report.csv docs/env.json
BOARD=MBUSB python3 -B tools/layout/render2.py moveOmeter_MBUSB.kicad_pcb docs/MBUSB_board.png 100 121
