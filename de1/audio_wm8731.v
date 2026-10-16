//============================================================================
//  WM8731 audio output for the Terasic DE1
//
//  Everything runs from CLOCK_50:
//    AUD_XCK     12.5   MHz  (50 / 4)     codec master clock = 256 fs
//    AUD_BCLK     3.125 MHz  (50 / 16)    64 bit clocks per frame
//    AUD_DACLRCK 48.83  kHz  (50 / 1024)  sample rate, low = left
//
//  The codec is an I2S slave with 16-bit words. The same mono sample goes to
//  both channels. After reset, wm8731_config below writes the codec registers
//  over I2C.
//============================================================================

module audio_wm8731
(
	input             clk,          // 50 MHz
	input             reset,

	input      [15:0] sample,       // signed, taken once per frame

	output reg        AUD_XCK,
	output reg        AUD_BCLK,
	output reg        AUD_DACLRCK,
	output reg        AUD_DACDAT,

	output            I2C_SCLK,
	inout             I2C_SDAT,

	output            cfg_done,
	output            cfg_nack
);

reg  [9:0] cnt = 10'd0;
reg [15:0] word = 16'd0;

wire [4:0] bit_no = cnt[8:4];   // bit clock within the current half-frame

always @(posedge clk) begin
	cnt <= cnt + 1'd1;
	if (cnt == 10'd0) word <= sample;

	// All outputs come from the same registered count, so they stay aligned.
	// The data bit changes with BCLK low; the codec samples on BCLK rising.
	// I2S puts the MSB in the second bit clock after each LRCK edge.
	AUD_XCK     <= cnt[1];
	AUD_BCLK    <= cnt[3];
	AUD_DACLRCK <= cnt[9];
	AUD_DACDAT  <= (bit_no >= 5'd1 && bit_no <= 5'd16) ? word[5'd16 - bit_no] : 1'b0;
end

wm8731_config setup
(
	.clk(clk),
	.reset(reset),
	.scl(I2C_SCLK),
	.sda(I2C_SDAT),
	.done(cfg_done),
	.nack(cfg_nack)
);

endmodule


//============================================================================
//  WM8731 register setup over I2C (write only, about 100 kHz SCL)
//
//  Order follows the datasheet's power-up advice: everything but the output
//  stage first, then activate, then power the outputs, to avoid a pop.
//============================================================================

module wm8731_config
(
	input      clk,                 // 50 MHz
	input      reset,

	output reg scl = 1'b1,
	inout      sda,

	output reg done = 1'b0,
	output reg nack = 1'b0          // the codec failed to acknowledge a byte
);

localparam [7:0] DEV_ADDR = 8'h34;  // WM8731 with CSB low, write
localparam       N_REGS   = 11;

// {register address, 9-bit value}
function [15:0] reg_word(input [3:0] i);
	case (i)
		4'd0:  reg_word = {7'h0F, 9'h000};  // reset
		4'd1:  reg_word = {7'h06, 9'h06F};  // power: DAC on; outputs, ADC, mic, line in, osc, clkout off
		4'd2:  reg_word = {7'h00, 9'h080};  // left line in muted
		4'd3:  reg_word = {7'h01, 9'h080};  // right line in muted
		4'd4:  reg_word = {7'h02, 9'h179};  // headphone out 0 dB, both channels
		4'd5:  reg_word = {7'h04, 9'h012};  // analogue path: DAC selected, mic muted, no bypass
		4'd6:  reg_word = {7'h05, 9'h000};  // digital path: DAC unmuted, no de-emphasis
		4'd7:  reg_word = {7'h07, 9'h002};  // interface: I2S, 16 bit, slave
		4'd8:  reg_word = {7'h08, 9'h000};  // sampling: normal mode, 256 fs
		4'd9:  reg_word = {7'h09, 9'h001};  // active
		default: reg_word = {7'h06, 9'h067}; // power the outputs
	endcase
endfunction

// Quarter-bit tick: 50 MHz / 125 = 400 kHz, so SCL runs at 100 kHz.
reg [6:0] div = 7'd0;
wire tick = (div == 7'd124);
always @(posedge clk) div <= tick ? 7'd0 : div + 1'd1;

// Power-up wait before the first transaction, ~10 ms in ticks
reg [11:0] wait_cnt = 12'd0;

localparam S_WAIT = 3'd0, S_START = 3'd1, S_BIT = 3'd2, S_STOP = 3'd3, S_GAP = 3'd4, S_DONE = 3'd5;
reg  [2:0] state = S_WAIT;
reg  [1:0] qtr = 2'd0;     // quarter of the current bit or start/stop
reg  [4:0] bit_i = 5'd0;   // 0..26: three bytes, each 8 bits + ACK
reg  [3:0] reg_i = 4'd0;
reg        sda_o = 1'b1;   // 1 = released (pulled up), 0 = driven low

assign sda = sda_o ? 1'bz : 1'b0;

// The 27-bit frame, MSB first. The ACK slots are 1 so SDA is released.
wire [15:0] rw    = reg_word(reg_i);
wire [26:0] frame = {DEV_ADDR, 1'b1, rw[15:8], 1'b1, rw[7:0], 1'b1};
wire        is_ack = (bit_i == 5'd8) || (bit_i == 5'd17) || (bit_i == 5'd26);

always @(posedge clk) begin
	if (reset) begin
		state    <= S_WAIT;
		wait_cnt <= 12'd0;
		reg_i    <= 4'd0;
		scl      <= 1'b1;
		sda_o    <= 1'b1;
		done     <= 1'b0;
		nack     <= 1'b0;
	end
	else if (tick) begin
		case (state)
			S_WAIT: begin
				wait_cnt <= wait_cnt + 1'd1;
				if (&wait_cnt) begin state <= S_START; qtr <= 2'd0; end
			end

			// SCL high, SDA high -> SDA low -> SCL low
			S_START: begin
				qtr <= qtr + 1'd1;
				case (qtr)
					2'd0: begin scl <= 1'b1; sda_o <= 1'b1; end
					2'd1: sda_o <= 1'b0;
					2'd2: begin scl <= 1'b0; bit_i <= 5'd0; qtr <= 2'd0; state <= S_BIT; end
				endcase
			end

			// SCL low and set SDA -> SCL high -> sample ACK -> SCL low
			S_BIT: begin
				qtr <= qtr + 1'd1;
				case (qtr)
					2'd0: sda_o <= frame[5'd26 - bit_i];
					2'd1: scl <= 1'b1;
					2'd2: if (is_ack && sda) nack <= 1'b1;
					2'd3: begin
						scl <= 1'b0;
						if (bit_i == 5'd26) state <= S_STOP;
						else bit_i <= bit_i + 1'd1;
					end
				endcase
			end

			// SDA low -> SCL high -> SDA high
			S_STOP: begin
				qtr <= qtr + 1'd1;
				case (qtr)
					2'd0: sda_o <= 1'b0;
					2'd1: scl <= 1'b1;
					2'd2: begin sda_o <= 1'b1; qtr <= 2'd0; state <= S_GAP; end
				endcase
			end

			S_GAP: begin
				qtr <= qtr + 1'd1;
				if (qtr == 2'd3) begin
					if (reg_i == N_REGS - 1) state <= S_DONE;
					else begin reg_i <= reg_i + 1'd1; state <= S_START; end
					qtr <= 2'd0;
				end
			end

			S_DONE: done <= 1'b1;
		endcase
	end
end

endmodule
