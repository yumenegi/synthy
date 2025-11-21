`timescale 1ns / 1ps

module vca(
    input  logic [15:0] audio_in,   // signed
    input  logic [15:0] gain,       // unsigned
    output logic [15:0] audio_out   // signed
    );
    logic sign_bit;
    logic [15:0] audio_mag;

    always_comb begin
        sign_bit = audio_in[15];
        
        if (sign_bit) begin
            audio_mag = (~audio_in) + 1; // negate
        end else begin
            audio_mag = audio_in;
        end
    end

    logic [31:0] audio_mag_gain;
    
    always_comb begin
        audio_mag_gain = audio_mag * gain;
    end
    
    // divide by 65536
    logic [15:0] result_mag;
    assign result_mag = audio_mag_gain[31:16];

    // restore signed bit
    always_comb begin
        if (sign_bit) begin
            audio_out = (~result_mag) + 1;
        end else begin
            audio_out = result_mag;
        end
    end

endmodule
