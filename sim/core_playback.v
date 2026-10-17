// Stand-in for computer_space_top in Verilog simulation of the DE1 top:
// replays a GHDL dump (one "hs vs hb vb v3 v2 v1 v0" line per game clock).
module computer_space_top
(
	input            reset,
	input            clock_50,
	input            game_clk,
	input            signal_ccw, signal_cw, signal_thrust, signal_fire,
	input            signal_start, signal_coin,
	input            sw_2playpercoin, sw_replay,
	output reg       hsync, vsync, hblank, vblank,
	output reg [3:0] video,
	output    [15:0] audio,
	output    [15:0] scores,
	input            score_orig
);
	assign audio = 16'd0;
	assign scores = 16'd0;
	integer fd, n;
	reg [7:0] s;
	reg [8*256-1:0] dump;
	initial begin
		if (!$value$plusargs("dump=%s", dump)) dump = "out/core_dump.txt";
		fd = $fopen(dump, "r");
		if (fd == 0) begin $display("cannot open dump"); $finish; end
		{hsync, vsync, hblank, vblank, video} = 0;
	end
	always @(posedge game_clk) if (!reset) begin
		n = $fscanf(fd, "%b\n", s);
		if (n != 1) begin $display("end of dump at %t", $time); $finish; end
		#10 {hsync, vsync, hblank, vblank, video} <= s;   // model core clock-to-out
	end
endmodule

// Behavioural PLL: 23.333 MHz, lock after 10 us.
module pll_de1 (input inclk0, input areset, output reg c0, output reg locked);
	initial begin c0 = 0; locked = 0; #10000 locked = 1; end
	always #21.428 c0 = ~c0;
endmodule
