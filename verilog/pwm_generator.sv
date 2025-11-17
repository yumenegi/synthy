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
        input logic clk, // Input 100mhz clock
        input logic audio_clock,
        input logic[32:0] pcm,
        output logic output_pwm
    );
    
    logic [32:0] current_pcm;
    logic [32:0] counter;

    always_ff @(posedge audio_clock)
	begin
	   current_pcm <= pcm;
	end
	
	always_ff @(posedge clk)
	begin
	   counter <= counter + 1;
	end
endmodule
