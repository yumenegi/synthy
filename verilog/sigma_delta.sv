`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/20/2025 09:18:06 PM
// Design Name: 
// Module Name: sigma_delta
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


module sigma_delta(
    input logic clk, //100mhz
    input logic reset, // reset_h signal
    input logic [15:0] pcm, // 16 bit signed audio in
    output logic pdm // sigma delta output
    );
    
    logic [15:0] unsigned_in;
    assign unsigned_in = {~pcm[15], pcm[14:0]};
    
    // sigma delta accumulator
    logic [16:0] acc;
    
    always_ff @(posedge clk) begin 
        acc <= acc[15:0] + unsigned_in;
    end
    
    assign pdm = acc[16]; // one bit output
    
endmodule
