`timescale 1ns / 1ps
/*******************************************************************************
    Quad engine implementation of the 2D wavetable synthesizer. This is not for
    polyphony, but for four separate wavetables with different waveforms. 
*******************************************************************************/

module wt_scanning(
    input logic clk_sys,            // 100mhz sys clk
    input logic wr_strb,            // write strobe 
    input logic [31:0] stride,      // stride
    input logic [15:0] amod,        // amplitude modifier, from envelope generator or lfo
                                    // unused for now
    input logic [6:0] wt_pos,       // wavetable position, up to 12                           
    output logic [5:0] stride_ptr,  // 64 total different stride positions
                                    // unused (?)
                                    // prob implement master side
    output logic [15:0] audio_out   // output
    );

endmodule
