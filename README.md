# Computer Space on the Terasic DE1

Nutting Associates' *Computer Space* (1971), as a gate-level HDL recreation running on the original
Terasic DE1 board (Cyclone II EP2C20F484C7) with video on the on-board VGA port.

## Credits and sources

- **Core (`rtl/`)**: Computer Space FPGA emulator by **Mattias G** (2015), copied "wire by wire" from the
  schematics; fixes and sound simulation by **DarFPGA** (2017). Taken from
  [MiSTer-devel/Arcade-ComputerSpace_MiSTer](https://github.com/MiSTer-devel/Arcade-ComputerSpace_MiSTer)
  at commit `8487fb22f11a40c456a507768180845ee2933439`, with one timing change marked `DE1:` (see
  Audio). No ROMs are needed.
- **Video mixing** in `de1/computerspace_de1.v` follows **Sorgelig**'s MiSTer wrapper (GPL-2.0+).
- **DE1 wrapper, scandoubler, simulation**: this repo.

## Layout

| Path | What |
|---|---|
| `rtl/` | The Computer Space core (VHDL), upstream and unmodified |
| `de1/computerspace_de1.v` | DE1 top level: clocks, controls, video mix, VGA |
| `de1/scandoubler_cs.v` | Line-locked 15 kHz to 31 kHz scandoubler with optional scanlines |
| `de1/pll_de1.v` | Cyclone II PLL, 50 MHz to 23.333 MHz |
| `de1/audio_wm8731.v` | WM8731 codec: I2C register setup and I2S output |
| `de1/computerspace_de1.qpf/.qsf/.sdc` | Quartus II 13.0sp1 project, pins and timing |
| `sim/` | GHDL simulation of the core, Icarus simulation of the DE1 top, and a renderer |

## Video

The core produces 382 game clocks per line and 255 lines per frame, which is 15.3 kHz at 59.9 Hz, progressive.
The scandoubler writes each line into a two-line buffer and reads it out twice, giving about
**30.5 kHz / 510 lines / 59.9 Hz** on the VGA pins with negative syncs. That is the same kind of signal MiST
cores send, and a multisync CRT or most LCDs will lock to it. Latency is one 15 kHz line, with no
framebuffer.

Clocks: 50 MHz → PLL → 23.333 MHz `clk_vid`, divided by 4 → 5.833 MHz game clock (MiSTer uses 5.825–5.842 MHz).
The core's analogue-timer emulation runs from the 50 MHz board clock, as upstream.

## Audio

DarFPGA's sound simulation in the core makes a 16-bit signed sample: the turn and missile tones come
from the same motion-board counters as the original circuit, and the drone, thrust and explosion are
shaped noise matched to recordings. `audio_wm8731.v` sends it to the board's WM8731 codec, the same
sample on both channels of the **line-out** jack. All its clocks are divided from the 50 MHz board
clock: 12.5 MHz master clock, 3.125 MHz bit clock, 48.83 kHz sample rate. After reset it writes the
codec registers over I2C in the datasheet's power-up order. The game is silent until a game starts, as
on the original.

One change to the core: in `computer_space_sound.vhd` the explosion envelope's input is registered,
because the path into its multiply was too long for one 50 MHz cycle on Cyclone II (it meets timing on
MiSTer's Cyclone V). It adds one 20 ns clock of delay to a sound computed at 11 kHz.

## Controls

| Control | Function |
|---|---|
| KEY3 / KEY2 | rotate CCW / CW |
| KEY1 | thrust |
| KEY0 | fire |
| SW0 | coin: each flip, up *or* down, is one coin |
| SW1 | start: each flip, up *or* down, is one press |
| SW2 | two plays per coin |
| SW3 | replay (extended play) |
| SW4 | colour (off = original monochrome) |
| SW6:5 | scanlines: 00 off, 01 25 %, 10 50 %, 11 75 % |
| SW8:7 | volume: 00 full, 01 -6 dB, 10 -12 dB, 11 -18 dB |
| SW9 | reset (up = held in reset) |

To play: flip SW0 once (a coin), then flip SW1 once (start). The switches stand in for the
cabinet's coin mech and start button, which are momentary contacts, so each *movement* of the switch
is one short press and the position it ends up in does not matter. Flipping it up and back down
counts as two. Start does nothing without a coin, as on the original.

LEDG3..0 show the four buttons, LEDG7 the PLL lock, LEDR0/1 the coin/start pulses, LEDR7 the audio
codec configured, LEDR8 a codec that did not acknowledge, and LEDR9 reset.

## Building

Cyclone II needs **Quartus II 13.0sp1 Web Edition**, the last release that supports it, plus
`cyclone_web-13.0.1.232.qdz`.

```
cd de1
quartus_sh --flow compile computerspace_de1
quartus_pgm -c USB-Blaster -m jtag -o "p;output_files/computerspace_de1.sof"
```

## Simulation

Tools: GHDL 6.0 (`E:\tools\ghdl`) and OSS CAD Suite for Icarus Verilog (`E:\tools\oss-cad-suite`).

```
cd sim
./run_core.sh -gFRAMES=30 -gSKIP_FRAMES=1 -gDUMP_FILE=out/core_dump.txt   # core, ~1 min
python render.py core out/core_dump.txt out/core                           # timing + PNGs
./run_de1.sh                      # DE1 top on that dump, ~2 min (+scanlines=2 +colour)
iverilog -g2005 -o out/tb_audio.vvp tb_audio.v ../de1/audio_wm8731.v && vvp -n out/tb_audio.vvp   # codec I2C + I2S
```

Simulated results: the core runs 382 clocks/line, 255 lines and a 32-clock hsync, at 15.27 kHz / 59.885 Hz.
The VGA pins carry 30.54 kHz, 510 lines, 59.885 Hz, a 2.74 µs hsync and an 8-line vsync.

`prep_rtl.py` makes simulation-only copies of `rtl/` with two small patches GHDL needs (Quartus takes the
originals as they are), and `sound_stub.vhd` replaces the sound module for video simulation.

## Roadmap

- Install in a 1971 one-player cabinet: native 15 kHz composite-sync video for a 15 kHz CRT,
  protected GPIO inputs for the cabinet's buttons and coin mech, an amplifier for the speaker
  (the original TV set provided it), and the design written to flash so the board boots into the game.
- Framebuffer output at true 640x480@60 if an LCD refuses the 30.5 kHz signal.

## Possible mods

Ideas that are not in the original game; each would sit behind a switch or option, with the original
behaviour as the default.

- **Coin feedback**: a short "ding" on the audio when a coin goes in, and a credit indicator, either on
  the DE1's 7-segment displays (unused now) or as a small marker on screen while a credit is waiting.
  The original gives no sign of a coin at all.
- **Short missile**: rocket missile lifetime about 1.2 s instead of the original 2.3 s, so it can fire
  more often over a shorter range.
- **P4 phosphor tint**: a slightly bluish white, like the original black-and-white tube, for colour
  monitors.
- **Native 15 kHz on the VGA pins**: bypass the scandoubler for monitors that accept 15 kHz.
- **Bench coin/start on the KEYs**: a KEY combination for coin and start, instead of SW0/SW1.
