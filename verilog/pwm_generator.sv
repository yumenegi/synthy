`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/17/2025 05:12:37 PM
// Design Name: 
// Module Name: pwm_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module pwm_generator(
        input logic clk, // Input 441mhz clock
        input logic audio_clock, // Input 44.1 khz clock
        input logic[15:0] pcm,
        output logic output_pwm
    );
    logic [15:0] unsigned_sample;
    assign unsigned_sample = {~pcm[15], pcm[14:0]}; // convert signed to unsigned
    logic [9:0] counter = 0; // 10-bit audio main counter

	always_ff @(posedge clk)
	begin
	   counter <= counter + 1;
	   if (unsigned_sample[15:6] > counter)
	       output_pwm = 1'b1;
	   else
	       output_pwm = 1'b0;
	end
endmodule
