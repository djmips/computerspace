// Checks audio_wm8731: decodes the I2C writes (acting as the codec and
// acknowledging each byte), then receives the I2S stream and compares the
// words against the samples that were fed in.

`timescale 1ns/1ps

module tb_audio;

reg clk = 0, reset = 1;
always #10 clk = ~clk;                  // 50 MHz

reg  [15:0] sample = 16'h0000;
wire xck, bclk, lrck, dat, scl;
tri1 sda;                               // board pull-up
reg  ack_drive = 0;
assign sda = ack_drive ? 1'b0 : 1'bz;

wire done, nack;

audio_wm8731 dut
(
	.clk(clk), .reset(reset), .sample(sample),
	.AUD_XCK(xck), .AUD_BCLK(bclk), .AUD_DACLRCK(lrck), .AUD_DACDAT(dat),
	.I2C_SCLK(scl), .I2C_SDAT(sda),
	.cfg_done(done), .cfg_nack(nack)
);

// ---------------- I2C slave model ----------------
integer nbits = 0, nbytes = 0, ntrans = 0, errors = 0;
reg [7:0] sh;
reg [7:0] bytes [0:2];
reg in_frame = 0;

always @(negedge sda) if (scl) begin in_frame = 1; nbits = 0; nbytes = 0; end
always @(posedge sda) if (scl && in_frame) begin
	in_frame = 0;
	if (nbytes != 3) begin $display("ERROR: transaction with %0d bytes", nbytes); errors = errors + 1; end
	else begin
		$display("I2C write dev %02h  R%0d <= %03h", bytes[0], bytes[1][7:1], {bytes[1][0], bytes[2]});
		if (bytes[0] != 8'h34) begin $display("ERROR: device address"); errors = errors + 1; end
	end
	ntrans = ntrans + 1;
end

always @(posedge scl) if (in_frame) begin
	if (nbits < 8) sh = {sh[6:0], sda};
	nbits = nbits + 1;
end

// Drive ACK low from the falling SCL after bit 8 until the falling SCL after the ACK
always @(negedge scl) if (in_frame) begin
	if (nbits == 8) begin
		bytes[nbytes] = sh;
		nbytes = nbytes + 1;
		ack_drive <= 1;
	end
	else if (nbits == 9) begin
		ack_drive <= 0;
		nbits = 0;
	end
end

// ---------------- I2S receiver ----------------
reg [31:0] lsh = 0;
reg        lr_d = 0;
reg [15:0] left_w, right_w;
integer    nframes = 0, sample_errors = 0;
reg [15:0] expect_q [0:3];

always @(posedge bclk) begin
	lsh <= {lsh[30:0], dat};
	lr_d <= lrck;
end

// On an LRCK change seen at a rising BCLK, the previous channel's 32 bits
// are in lsh, with the I2S one-bit delay: MSB at bit 30.
always @(posedge bclk) if (lrck != lr_d) begin
	if (lrck) left_w  = lsh[30:15];
	else begin
		right_w = lsh[30:15];
		nframes = nframes + 1;
		if (nframes > 2) begin
			if (left_w != right_w || left_w != expect_q[1]) begin
				if (sample_errors < 5)
					$display("ERROR: frame %0d got L %04h R %04h expected %04h", nframes, left_w, right_w, expect_q[1]);
				sample_errors = sample_errors + 1;
			end
		end
	end
end

// New sample per frame, recorded at the moment the DUT latches it
always @(posedge clk) if (dut.cnt == 10'd0) begin
	expect_q[1] <= expect_q[0];
	expect_q[0] <= sample;
end
always @(posedge clk) if (dut.cnt == 10'd512) sample <= $random;

// ---------------- clock checks ----------------
real t_lr0 = 0, t_lr1 = 0;
always @(posedge lrck) begin t_lr0 = t_lr1; t_lr1 = $realtime; end

initial begin
	#1000 reset = 0;
	wait (done);
	$display("config done at %0t ns, nack = %b, %0d transactions", $time, nack, ntrans);
	if (ntrans != 11) begin $display("ERROR: expected 11 transactions"); errors = errors + 1; end
	if (nack) begin $display("ERROR: nack with an acknowledging slave"); errors = errors + 1; end
	repeat (200) @(posedge lrck);
	$display("LRCK period %.1f ns = %.2f kHz; %0d frames, %0d sample errors",
	         t_lr1 - t_lr0, 1e6 / (t_lr1 - t_lr0), nframes, sample_errors);
	errors = errors + sample_errors;

	// A missing codec must be reported
	ack_drive = 0;
	force ack_drive = 0;
	reset = 1; #1000 reset = 0;
	wait (done);
	$display("no-ack run: nack = %b", nack);
	if (!nack) begin $display("ERROR: nack not reported"); errors = errors + 1; end

	if (errors) $display("FAIL: %0d errors", errors);
	else        $display("PASS");
	$finish;
end

endmodule
