//============================================================================
//  Computer Space for the Terasic DE1 (Cyclone II EP2C20F484C7)
//
//  Core: Computer Space FPGA emulator by Mattias G (2015), fixes and sound
//  simulation by DarFPGA (2017), as carried in the MiSTer port by Sorgelig.
//  Video level mixing below follows Sorgelig's MiSTer wrapper (GPL-2.0+).
//
//  Video: 15 kHz native timing scandoubled to ~30.5 kHz / 60 Hz on the
//  on-board 4-bit resistor VGA DAC.
//  Audio: the core's sound simulation through the WM8731 codec (line out).
//
//  Controls (KEYs are active low):
//    KEY3  rotate CCW      KEY2  rotate CW
//    KEY1  thrust          KEY0  fire
//    SW0   coin  (flip either way)
//    SW1   start (flip either way)
//    SW2   two plays per coin
//    SW3   replay (extended play)
//    SW4   colour (off = original monochrome)
//    SW6:5 scanlines: 0 off, 1 25%, 2 50%, 3 75%
//    SW8:7 volume: 0 full, 1 -6 dB, 2 -12 dB, 3 -18 dB
//    SW9   reset (up = held in reset)
//============================================================================

module computerspace_de1
(
	input         CLOCK_50,

	input   [3:0] KEY,
	input   [9:0] SW,

	output  [9:0] LEDR,
	output  [7:0] LEDG,
	output  [6:0] HEX0,
	output  [6:0] HEX1,
	output  [6:0] HEX2,
	output  [6:0] HEX3,

	output  [3:0] VGA_R,
	output  [3:0] VGA_G,
	output  [3:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

	output        AUD_XCK,
	output        AUD_BCLK,
	output        AUD_DACLRCK,
	output        AUD_DACDAT,

	output        I2C_SCLK,
	inout         I2C_SDAT
);

assign {HEX3, HEX2, HEX1, HEX0} = {28{1'b1}};   // segments are active low

////////////////////   CLOCKS   ///////////////////

wire clk_vid;            // 23.333 MHz
wire pll_locked;

pll_de1 pll
(
	.inclk0(CLOCK_50),
	.areset(1'b0),
	.c0(clk_vid),
	.locked(pll_locked)
);

// Game clock = clk_vid / 4. clk_div[1] drives the core's game_clk.
// ce_in samples the core's video 3 clk_vid cycles after a game_clk rising
// edge; ce_out runs at twice the game pixel rate for the scandoubler.
reg [1:0] clk_div = 2'd0;
always @(posedge clk_vid) clk_div <= clk_div + 1'd1;

wire clk_game = clk_div[1];
wire ce_in    = (clk_div == 2'd0);
wire ce_out   = ~clk_div[0];

////////////////////   INPUTS   ///////////////////

reg [3:0] key_s1, key_s2;
reg [9:0] sw_s1,  sw_s2, sw_d;

always @(posedge CLOCK_50) begin
	key_s1 <= ~KEY;   key_s2 <= key_s1;
	sw_s1  <= SW;     sw_s2  <= sw_s1;   sw_d <= sw_s2;
end

wire por;

wire m_ccw    = key_s2[3];
wire m_cw     = key_s2[2];
wire m_thrust = key_s2[1];
wire m_fire   = key_s2[0];

// Coin and start: a 100 ms press whenever the switch is flipped (not at
// power-up, where the synchronisers settle to the switch positions).
reg [22:0] coin_cnt, start_cnt;
always @(posedge CLOCK_50) begin
	if (por)                      coin_cnt <= 23'd0;
	else if (sw_s2[0] != sw_d[0]) coin_cnt <= 23'd5_000_000;
	else if (coin_cnt)            coin_cnt <= coin_cnt - 1'd1;

	if (por)                      start_cnt <= 23'd0;
	else if (sw_s2[1] != sw_d[1]) start_cnt <= 23'd5_000_000;
	else if (start_cnt)           start_cnt <= start_cnt - 1'd1;
end

wire m_coin  = |coin_cnt;
wire m_start = |start_cnt;

wire       sw_2playpercoin = sw_s2[2];
wire       sw_replay       = sw_s2[3];
wire       colour          = sw_s2[4];
wire [1:0] scanlines       = sw_s2[6:5];
wire [1:0] volume          = sw_s2[8:7];

// Reset: ~20 ms after configuration and PLL lock, and while SW9 is up.
reg [19:0] por_cnt = 20'd0;
always @(posedge CLOCK_50) begin
	if (!pll_locked)  por_cnt <= 20'd0;
	else if (~&por_cnt) por_cnt <= por_cnt + 1'd1;
end

assign por   = ~&por_cnt;
wire   reset = por | sw_s2[9];

////////////////////   CORE   ///////////////////

wire       HSync, VSync, HBlank, VBlank;
wire [3:0] video;
wire [15:0] audio;

computer_space_top computerspace
(
	.reset(reset),

	.clock_50(CLOCK_50),
	.game_clk(clk_game),

	.signal_ccw(m_ccw),
	.signal_cw(m_cw),
	.signal_thrust(m_thrust),
	.signal_fire(m_fire),
	.signal_start(m_start),
	.signal_coin(m_coin),

	.sw_2playpercoin(sw_2playpercoin),
	.sw_replay(sw_replay),

	.hsync(HSync),
	.vsync(VSync),
	.hblank(HBlank),
	.vblank(VBlank),
	.video(video),

	.audio(audio)
);

////////////////////   VIDEO MIX   ///////////////////
// video[0] stars, video[1] score/time digits (cyan in colour mode),
// video[2] saucer and the other objects (yellow), video[3] screen inversion
// request (applied for the whole next frame).

wire [5:0] rs,gs,bs, ro,go,bo, rc,gc,bc, rm,gm,bm;
wire [3:0] r,g,b;

assign {rs,gs,bs} = ~video[0] ? 18'd0 : {6'b0111,6'b0111,6'b0111};
assign {rc,gc,bc} = ~video[1] ? 18'd0 : colour ? {6'b0000,6'b1111,6'b1111} : {6'b0111,6'b0111,6'b0111};
assign {ro,go,bo} = ~video[2] ? 18'd0 : colour ? {6'b1111,6'b1111,6'b0000} : {6'b1111,6'b1111,6'b1111};

assign rm = rs + ro + rc;
assign gm = gs + go + gc;
assign bm = bs + bo + bc;

reg inv = 1'b0, cur_inv = 1'b0, old_vs = 1'b0;
assign r = (rm[5:4] ? 4'b1111 : rm[3:0]) ^ {4{inv}};
assign g = (gm[5:4] ? 4'b1111 : gm[3:0]) ^ {4{inv}};
assign b = (bm[5:4] ? 4'b1111 : bm[3:0]) ^ {4{inv}};

always @(posedge clk_game) begin
	old_vs <= VSync;

	cur_inv <= cur_inv | video[3];
	if (~old_vs & VSync) {inv, cur_inv} <= {cur_inv, 1'b0};
end

////////////////////   SCANDOUBLER   ///////////////////

wire       sd_hs, sd_vs;
wire [3:0] sd_r, sd_g, sd_b;

scandoubler_cs scandoubler
(
	.clk(clk_vid),
	.ce_in(ce_in),
	.ce_out(ce_out),

	.hs_in(HSync),
	.vs_in(VSync),
	.blank_in(HBlank | VBlank),
	.r_in(r),
	.g_in(g),
	.b_in(b),

	.scanlines(scanlines),

	.hs_out(sd_hs),
	.vs_out(sd_vs),
	.r_out(sd_r),
	.g_out(sd_g),
	.b_out(sd_b)
);

assign VGA_HS = ~sd_hs;   // negative syncs, as for 640x480
assign VGA_VS = ~sd_vs;
assign VGA_R  = sd_r;
assign VGA_G  = sd_g;
assign VGA_B  = sd_b;

////////////////////   AUDIO   ///////////////////

wire        aud_done, aud_nack;
wire [15:0] aud_sample = $signed(audio) >>> volume;   // 6 dB per step

audio_wm8731 audio_out
(
	.clk(CLOCK_50),
	.reset(reset),

	.sample(aud_sample),

	.AUD_XCK(AUD_XCK),
	.AUD_BCLK(AUD_BCLK),
	.AUD_DACLRCK(AUD_DACLRCK),
	.AUD_DACDAT(AUD_DACDAT),

	.I2C_SCLK(I2C_SCLK),
	.I2C_SDAT(I2C_SDAT),

	.cfg_done(aud_done),
	.cfg_nack(aud_nack)
);

////////////////////   LEDS   ///////////////////

assign LEDG = {pll_locked, 3'b000, m_ccw, m_cw, m_thrust, m_fire};
assign LEDR = {reset, aud_nack, aud_done, 5'd0, m_start, m_coin};

endmodule
