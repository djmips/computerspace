#!/bin/sh
# Simulate the DE1 top level (PLL, video mix, scandoubler) replaying a core
# dump from run_core.sh, then render the VGA output.
# Extra args go to vvp, e.g. ./run_de1.sh +scanlines=2 +colour
set -e
cd "$(dirname "$0")"
I=${OSS_CAD:-/e/tools/oss-cad-suite}
export PATH="$I/bin:$I/lib:$PATH"
mkdir -p out
iverilog -g2012 -o out/tb_de1.vvp tb_de1.v core_playback.v \
	../de1/computerspace_de1.v ../de1/scandoubler_cs.v
vvp -n out/tb_de1.vvp +dump=out/core_dump.txt +out=out/vga_dump.txt "$@"
python render.py vga out/vga_dump.txt out/vga
