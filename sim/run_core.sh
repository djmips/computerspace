#!/bin/sh
# Build and run the GHDL core simulation. Extra args go to the simulator,
# e.g. ./run_core.sh -gFRAMES=26 -gSKIP_FRAMES=1 -gDUMP_FILE=build/core_dump.txt
set -e
cd "$(dirname "$0")"
G=${GHDL:-/e/tools/ghdl/bin/ghdl.exe}
O="--std=93c -fsynopsys -fexplicit -frelaxed --workdir=build"
rm -rf build && mkdir -p out && python -I prep_rtl.py
for f in v74161 v74161_16bit scan_counter saucer_diode_image rocket_diode_images \
         sync_star_board motion_board memory_board clocks computer_space_logic; do
	$G -a $O build/src/$f.vhd
done
$G -a $O sound_stub.vhd
$G -a $O build/src/computer_space_top.vhd
$G -a $O tb_core.vhd
$G -e $O tb_core
$G -r $O tb_core --ieee-asserts=disable "$@"
