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
        input logic clk, // Input 800mhz clock
        input logic audio_clock, // Input 44.1 khz clock
        input logic[32:0] pcm,
        output logic output_pwm
    );
    
    logic [32:0] current_pcm;
    logic [14:0] counter; // So a full audio duty cycle is 18141 input clock ticks 

    always_ff @(posedge audio_clock)
	begin
	   current_pcm <= pcm;
	end
	
	always_ff @(posedge clk)
	begin
	   counter <= counter + 1;
	   if ((current_pcm / 18141) > counter)
	       output_pwm = 0;
	   else
	       output_pwm = 1;
	end
endmodule
