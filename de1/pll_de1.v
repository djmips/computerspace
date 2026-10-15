// Cyclone II PLL: 50 MHz in, 23.333 MHz out (50 * 7 / 15).
//
// 23.333 MHz is the video clock. The game clock is this divided by 4 in the
// top level (5.833 MHz; the MiSTer core uses 5.825-5.842 MHz).

module pll_de1
(
	input  inclk0,
	input  areset,
	output c0,
	output locked
);

wire [5:0] clk;
assign c0 = clk[0];

altpll altpll_component
(
	.inclk         ({1'b0, inclk0}),
	.areset        (areset),
	.clk           (clk),
	.locked        (locked),
	.activeclock   (),
	.clkbad        (),
	.clkena        ({6{1'b1}}),
	.clkloss       (),
	.clkswitch     (1'b0),
	.configupdate  (1'b0),
	.enable0       (),
	.enable1       (),
	.extclk        (),
	.extclkena     ({4{1'b1}}),
	.fbin          (1'b1),
	.fbmimicbidir  (),
	.fbout         (),
	.pfdena        (1'b1),
	.phasecounterselect ({4{1'b1}}),
	.phasedone     (),
	.phasestep     (1'b1),
	.phaseupdown   (1'b1),
	.pllena        (1'b1),
	.scanaclr      (1'b0),
	.scanclk       (1'b0),
	.scanclkena    (1'b1),
	.scandata      (1'b0),
	.scandataout   (),
	.scandone      (),
	.scanread      (1'b0),
	.scanwrite     (1'b0),
	.sclkout0      (),
	.sclkout1      (),
	.vcooverrange  (),
	.vcounderrange ()
);

defparam
	altpll_component.clk0_divide_by          = 15,
	altpll_component.clk0_duty_cycle         = 50,
	altpll_component.clk0_multiply_by        = 7,
	altpll_component.clk0_phase_shift        = "0",
	altpll_component.compensate_clock        = "CLK0",
	altpll_component.inclk0_input_frequency  = 20000,
	altpll_component.intended_device_family  = "Cyclone II",
	altpll_component.lpm_hint                = "CBX_MODULE_PREFIX=pll_de1",
	altpll_component.lpm_type                = "altpll",
	altpll_component.operation_mode          = "NORMAL",
	altpll_component.port_activeclock        = "PORT_UNUSED",
	altpll_component.port_areset             = "PORT_USED",
	altpll_component.port_clkbad0            = "PORT_UNUSED",
	altpll_component.port_clkbad1            = "PORT_UNUSED",
	altpll_component.port_clkloss            = "PORT_UNUSED",
	altpll_component.port_clkswitch          = "PORT_UNUSED",
	altpll_component.port_configupdate       = "PORT_UNUSED",
	altpll_component.port_fbin               = "PORT_UNUSED",
	altpll_component.port_inclk0             = "PORT_USED",
	altpll_component.port_inclk1             = "PORT_UNUSED",
	altpll_component.port_locked             = "PORT_USED",
	altpll_component.port_pfdena             = "PORT_UNUSED",
	altpll_component.port_phasecounterselect = "PORT_UNUSED",
	altpll_component.port_phasedone          = "PORT_UNUSED",
	altpll_component.port_phasestep          = "PORT_UNUSED",
	altpll_component.port_phaseupdown        = "PORT_UNUSED",
	altpll_component.port_pllena             = "PORT_UNUSED",
	altpll_component.port_scanaclr           = "PORT_UNUSED",
	altpll_component.port_scanclk            = "PORT_UNUSED",
	altpll_component.port_scanclkena         = "PORT_UNUSED",
	altpll_component.port_scandata           = "PORT_UNUSED",
	altpll_component.port_scandataout        = "PORT_UNUSED",
	altpll_component.port_scandone           = "PORT_UNUSED",
	altpll_component.port_scanread           = "PORT_UNUSED",
	altpll_component.port_scanwrite          = "PORT_UNUSED",
	altpll_component.port_clk0               = "PORT_USED",
	altpll_component.port_clk1               = "PORT_UNUSED",
	altpll_component.port_clk2               = "PORT_UNUSED",
	altpll_component.port_clk3               = "PORT_UNUSED",
	altpll_component.port_clk4               = "PORT_UNUSED",
	altpll_component.port_clk5               = "PORT_UNUSED",
	altpll_component.port_clkena0            = "PORT_UNUSED",
	altpll_component.port_clkena1            = "PORT_UNUSED",
	altpll_component.port_clkena2            = "PORT_UNUSED",
	altpll_component.port_clkena3            = "PORT_UNUSED",
	altpll_component.port_clkena4            = "PORT_UNUSED",
	altpll_component.port_clkena5            = "PORT_UNUSED",
	altpll_component.port_extclk0            = "PORT_UNUSED",
	altpll_component.port_extclk1            = "PORT_UNUSED",
	altpll_component.port_extclk2            = "PORT_UNUSED",
	altpll_component.port_extclk3            = "PORT_UNUSED";

endmodule
