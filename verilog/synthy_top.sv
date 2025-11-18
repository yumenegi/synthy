`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/17/2025 01:29:48 PM
// Design Name: 
// Module Name: synthy_top
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


module synthy_top(
        input logic [0:7] data_bus,
        input logic [0:3] addr_bus,
        input logic bank_select,
        input logic clk,
        input logic input_clk, // input clock
        input logic audio_clock, 
        input logic cs,
        input logic wr,
        output logic SPKL, // headphone jack left
        output logic SPKR // headphone jack right
    );
   logic[32:0] pcm_signal; 
   logic pwm_clock;
   logic output_audio;
   clk_wiz_0 clocker(.clk_in1(clk), .clk_out1(pwm_clock));
   pwm_generator generator(
        .clk(pwm_clock), // Input 800mhz clock
        .audio_clock(audio_clock), // Input 44.1 khz clock
        .pcm(pcm_signal),
        .output_pwm(output_audio));
   // Stereo audio for now
   assign SPKL = output_audio; 
   assign SPKR = output_audio;
endmodule
