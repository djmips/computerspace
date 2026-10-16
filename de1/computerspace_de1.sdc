# Computer Space - DE1 timing constraints

create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks

# PLL output pin (a wildcard here also matches inclk[0] and the clkctrl input)
set clk_vid_pin [get_pins -compatibility_mode {pll|altpll_component|pll|clk[0]}]

# Game clock: clk_vid / 4 from a fabric register
create_generated_clock -name clk_game -source $clk_vid_pin \
	-divide_by 4 [get_registers {clk_div[1]}]

derive_clock_uncertainty

# The core's 50 MHz timer logic is asynchronous to the video/game clocks
set_clock_groups -asynchronous \
	-group [get_clocks {CLOCK_50}] \
	-group [get_clocks {*altpll_component*clk[0] clk_game}]

# Switches, keys, LEDs and the resistor-DAC VGA outputs have no timing relation
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] LEDG[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] VGA_*}]

# The scandoubler samples the core's outputs only on ce_in, 3 clk_vid cycles
# after each clk_game rising edge (clk_div 2 -> 3 -> 0, captured as it leaves 0).
set_multicycle_path -setup -end 3 -from [get_clocks {clk_game}] -to [get_clocks {*altpll_component*clk[0]}]
set_multicycle_path -hold  -end 2 -from [get_clocks {clk_game}] -to [get_clocks {*altpll_component*clk[0]}]
