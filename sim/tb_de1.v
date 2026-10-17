`timescale 1ns/1ps
// DE1 top-level testbench: real computerspace_de1 + scandoubler, core replayed
// from a GHDL dump. Writes one line per output pixel (ce_out):
//   hs vs r g b   (hs/vs as driven on the VGA pins, active low)
module tb_de1;
	reg        CLOCK_50 = 0;
	reg  [3:0] KEY = 4'hF;
	reg  [9:0] SW  = 10'd0;
	wire [9:0] LEDR;
	wire [7:0] LEDG;
	wire [6:0] HEX0, HEX1, HEX2, HEX3;
	wire [3:0] VGA_R, VGA_G, VGA_B;
	wire       VGA_HS, VGA_VS;
	wire       AUD_XCK, AUD_BCLK, AUD_DACLRCK, AUD_DACDAT, I2C_SCLK;
	tri1       I2C_SDAT;   // board pull-up; no codec model here

	always #10 CLOCK_50 = ~CLOCK_50;

	computerspace_de1 dut (.*);

	integer fo;
	reg [8*256-1:0] outf;
	reg [1:0] sl;
	initial begin
		if (!$value$plusargs("out=%s", outf)) outf = "out/vga_dump.txt";
		if ($value$plusargs("volume=%d", sl)) SW[6:5] = sl;
		if ($test$plusargs("colour")) SW[4] = 1;
		fo = $fopen(outf, "w");
	end

	always @(posedge dut.clk_vid) if (dut.ce_out & ~dut.reset)
		$fwrite(fo, "%b %b %h %h %h\n", VGA_HS, VGA_VS, VGA_R, VGA_G, VGA_B);
endmodule
