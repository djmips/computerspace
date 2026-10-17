// Simulation model of the Altera LCELL primitive (a buffer that Quartus keeps),
// for the ring oscillators in computerspace_de1.v. Each cell adds 17 ns, so the
// rings oscillate at a few MHz in simulation instead of looping in zero time.
`timescale 1ns/1ps

module lcell (input in, output reg out);
	initial out = 1'b0;
	always @(in) out <= #17 in;
endmodule
