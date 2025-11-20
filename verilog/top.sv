`timescale 1ns / 1ps

//                                            
//                                            
//    ???    ??? ???    ???    ??? ???    ??? 
//    ???    ??? ???    ???    ??? ???    ??? 
//    ???    ???  ???  ?????  ???  ???    ??? 
//    ???   ????   ?????? ??????   ???   ???? 
//     ?????????    ????   ????     ????????? 
//                                            
//                                            
//                 welcome to hell!

module top(
    input  logic       Clk,
    input  logic [15:0] SW,
    input  logic [ 3:0] BTN,
    output logic [15:0] LED,
    input  logic       JA1_P,      // SPI_CS_N
    input  logic       JA1_N,      // SPI_MOSI
    output logic       JA2_P,      // SPI_MISO
    input  logic       JA2_N,      // SPI_SCK
    output logic       JB1_P,      // I2S_MCLK
    output logic       JB1_N,      // I2S_BCLK
    output logic       JB2_P,      // I2S_LRCLK
    output logic       JB2_N,      // I2S_SDATA
    output logic       SPKL,
    output logic       SPKR
    );
    
    // clk sig
    logic clk_sys;
    logic clk_audio;
    
    // Write strobe signal
    logic wr_strb;
    
    // clk locked
    logic locked;
    
    // instantiate clock wiz
    clk_wiz_0 clk_wiz (
        .reset(reset),
        .clk_in1(Clk),
        .clk(clk_sys),
        .clk_audio(clk_audio),
        .locked(locked)
    );
    
    // stride table
    logic [31:0] stride[64];
    
    // output of each wt operator
    logic [15:0] audio_out[8];
    
    // sync signal generation from i2s transmitter
    i2s_transmitter i2s_inst (
        .clk_audio(clk_audio),
        .reset(~locked),         // reset if clock unlocks
        .sample_in(audio_out[0]), // data from Synth
//        .bclk(i2s_bclk),
//        .lrclk(i2s_lrclk),
//        .sdata(i2s_sdata),
        .ready_for_sample(wr_strb) // request signal
    );
    
    // wavetabling
    wt wt0(
        .clk_sys(clk_sys),
        .clk_audio(clk_audio),
        .wr_strb(wr_strb),
        .stride(stride[0]),
        .audio_out(audio_out[0])
    );
endmodule
