// Line-locked scandoubler for the Computer Space core on the DE1.
//
// The core draws ~382 game clocks per line and 255 lines per frame
// (~15.3 kHz, ~60 Hz, progressive). Each input line is written into one half
// of a two-line buffer at the game pixel rate and read out twice from the
// other half at double rate, giving ~30.5 kHz / 510 lines / ~60 Hz.
//
// Timing reference is the rising edge of the input hsync: it starts a new
// write line and restarts the read side on the line just completed, so the
// output stays locked to the core with no frame buffer and no added frame of
// lag (one input line of delay).
//
// clk runs at 4x the game pixel clock. ce_in strobes once per game pixel at a
// point where the core's outputs are stable; ce_out strobes twice per game
// pixel.

module scandoubler_cs
(
	input            clk,
	input            ce_in,
	input            ce_out,

	input            hs_in,       // active high
	input            vs_in,       // active high
	input            blank_in,    // hblank | vblank
	input      [3:0] r_in,
	input      [3:0] g_in,
	input      [3:0] b_in,

	input      [1:0] scanlines,   // 0 off, 1 25%, 2 50%, 3 75% darker

	output reg       hs_out,      // active high
	output reg       vs_out,      // active high
	output reg [3:0] r_out,
	output reg [3:0] g_out,
	output reg [3:0] b_out
);

// ---------------------------------------------------------------------------
// Line buffer: 2 lines x 512 entries of {blank, r, g, b}
// ---------------------------------------------------------------------------

reg [12:0] linebuf[0:1023];

// ---------------------------------------------------------------------------
// Write side (input pixel rate)
// ---------------------------------------------------------------------------

reg       hs_d     = 1'b0;
reg       wr_bank  = 1'b0;
reg [8:0] wr_x     = 9'd0;
reg [8:0] line_len = 9'd0;  // pixels in the line just completed
reg [8:0] hs_cnt   = 9'd0;
reg [8:0] hs_len   = 9'd0;  // input hsync width in pixels
reg       vs_line  = 1'b0;  // vsync sampled at the start of the line
reg       new_line = 1'b0;  // a line was completed; restart the read side

wire       hs_rise = hs_in & ~hs_d;
wire [8:0] wa      = hs_rise ? 9'd0 : wr_x;
wire       wb      = hs_rise ? ~wr_bank : wr_bank;

always @(posedge clk) begin
	if (ce_out & new_line) new_line <= 1'b0;

	if (ce_in) begin
		hs_d <= hs_in;
		linebuf[{wb, wa}] <= {blank_in, r_in, g_in, b_in};
		if (wa != 9'h1FF) wr_x <= wa + 1'd1;

		if (hs_in) hs_cnt <= hs_rise ? 9'd1 : hs_cnt + 1'd1;
		else if (hs_d) hs_len <= hs_cnt;

		if (hs_rise) begin
			wr_bank  <= ~wr_bank;
			line_len <= wr_x;
			vs_line  <= vs_in;
			new_line <= 1'b1;
		end
	end
end

// ---------------------------------------------------------------------------
// Read side (double rate)
// ---------------------------------------------------------------------------

reg        rd_bank = 1'b0;
reg  [8:0] rd_x    = 9'd0;
reg  [8:0] rd_len  = 9'd0;
reg        second  = 1'b0;  // second pass over the same line
reg        vs_cur  = 1'b0;
reg [12:0] q;

always @(posedge clk) q <= linebuf[{rd_bank, rd_x}];

// dim a 4-bit level for the scanline pass
function [3:0] dim;
	input [3:0] v;
	input [1:0] sl;
	case (sl)
		2'd1:    dim = v - {2'b00, v[3:2]};
		2'd2:    dim = {1'b0, v[3:1]};
		2'd3:    dim = {2'b00, v[3:2]};
		default: dim = v;
	endcase
endfunction

always @(posedge clk) begin
	if (ce_out) begin
		// q, rd_x and second are consistent here: q was read one clk after
		// rd_x last changed.
		hs_out <= (rd_x < hs_len);
		vs_out <= vs_cur;
		if (q[12]) begin
			{r_out, g_out, b_out} <= 12'd0;
		end else if (second) begin
			r_out <= dim(q[11:8], scanlines);
			g_out <= dim(q[7:4],  scanlines);
			b_out <= dim(q[3:0],  scanlines);
		end else begin
			{r_out, g_out, b_out} <= q[11:0];
		end

		if (new_line) begin
			rd_bank <= ~wr_bank;     // wr_bank already toggled: other half
			rd_len  <= line_len;
			rd_x    <= 9'd0;
			second  <= 1'b0;
			vs_cur  <= vs_line;
		end else if (rd_x + 1'd1 >= rd_len) begin
			rd_x    <= 9'd0;
			second  <= 1'b1;
		end else begin
			rd_x    <= rd_x + 1'd1;
		end
	end
end

endmodule
