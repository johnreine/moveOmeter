#!/bin/sh
# Rebuild SB1 rev B from the generators: schematics + BOM, project footprints, placement, board, project file,
# then the rule check and the board picture.  usage: sh tools/rebuild.sh   (from anywhere)
# Needs python3 with matplotlib for the picture. Set SB1_FPDIR / SB1_V1 if KiCad or the V1 board aren't in the
# default places (see tools/layout/schdata.py).
set -e
P=$(cd "$(dirname "$0")/.." && pwd)
cd "$P/tools" && python3 -B build.py "$P"
cd "$P"
python3 -B tools/layout/mk3d.py "$P" SB1 3dmodels/vendor/Adafruit_6049_I2S_MEMS_Microphone.3mf
python3 -B tools/layout/mkstep_ld6004.py 3dmodels/HLK-LD6004_module.step
python3 -B tools/layout/mkmicfp.py lib/SB1.pretty
python3 -B tools/layout/mkfp_sb1b.py lib/SB1.pretty
python3 -B tools/layout/place_sb1b.py docs
# 11/10: once the board is routed, KiCad owns moveOmeter_SB1.kicad_pcb. If it has tracks the generator didn't lay
# (any unlocked segment), the generated board goes to moveOmeter_SB1_unrouted.kicad_pcb instead, so a rebuild never
# overwrites the routing.
PCB=moveOmeter_SB1.kicad_pcb
if [ -f "$PCB" ] && python3 -B -c "
import sys; sys.path.insert(0, 'tools/layout'); import sx
b = sx.parse(open('$PCB').read())
sys.exit(0 if any(not sx.find(s, 'locked') for s in sx.findall(b, 'segment')) else 1)"; then
  PCB=moveOmeter_SB1_unrouted.kicad_pcb
  echo "moveOmeter_SB1.kicad_pcb is routed: leaving it alone, writing the generated board to $PCB"
fi
python3 -B tools/layout/mkpcb_sb1b.py $PCB docs/placement.json
python3 -B tools/layout/fixpro_sb1b.py "$P"
python3 -B tools/layout/fanout_gnd.py $PCB
python3 -B tools/layout/fanout_j7.py $PCB
python3 -B tools/layout/silkrefs.py $PCB
python3 -B tools/layout/verify_sb1b.py $PCB netlist_report.csv
BOARD=SB1 python3 -B tools/layout/render2.py $PCB docs/SB1_board.png 42 $(python3 -c "import json;print(json.load(open('docs/layout.json'))['H'])")
