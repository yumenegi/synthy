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
    
    // for testing
    // 1 hz number of strides
    localparam logic [31:0] FREQ_TO_STRIDE_CONST = 32'd97392;
    logic [31:0] base_stride;
    
    // bottom switches is hz increase
    // top switches are octaves
    assign base_stride = SW[7:0] * FREQ_TO_STRIDE_CONST;    
    assign stride[0] = base_stride << SW[10:8];
    
    // lfo freq
    logic [31:0] lfo_freq;
    assign lfo_freq = SW[15:11] * FREQ_TO_STRIDE_CONST;
    
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
    
    logic [15:0] lfo_out;
//     wavetabling
    wt lfo(
        .clk_sys(clk_sys),
        .wr_strb(wr_strb),
        .stride(lfo_freq),
        .audio_out(lfo_out)
    );
    
    // wavetable position
    logic [6:0] wt_pos_in;
    assign wt_pos_in = lfo_out[15:9];


    // wt
    logic [15:0] wt_out;
    wt_scanning wt0(
        .clk_sys(clk_sys),
        .wr_strb(wr_strb),
        .stride(stride[0]),
        .wt_pos(wt_pos_in),
        .audio_out(wt_out)
    );
    
    sigma_delta pdm (
        .clk(clk_sys),
        .reset(~locked),
        .pcm(audio_out[0]),
        .pdm(SPKL)
    );
    assign SPKR = SPKL;

    logic [15:0] env_out; 
    envelope env (
        .wr_strb(wr_strb),
        .ar(8'ha0),
        .ar_rs(4'h1),
        .dr(8'h0a),
        .dr_rs(4'h2),
        .sl(16'h9999),
        .rr(8'h0a),
        .rr_rs(4'h0),
        .exp_mode_on(1'b0),
        .key_on(BTN[0]),
        .env_out(env_out)
    );

    vca amp (
        .audio_in(wt_out),
        .gain(env_out),
        .audio_out(audio_out[0])
    );


    
    assign LED = {env_out};
endmodule
