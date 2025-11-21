`timescale 1ns / 1ps


module env_tb;
    logic clk_sys;
    logic [7:0] ar;     // attack rate
    logic [3:0] ar_rs;  // rate scaling
    logic [7:0] dr;     // decay rate
    logic [3:0] dr_rs;  // rate scaling
    logic [15:0] sl;     // sustain level
    logic [7:0] rr;     // release rate
    logic [3:0] rr_rs;  // rate scaling
    logic [2:0] exp_mode_on;        // attack, decay, release exp on
    logic key_on;       // key on
    logic [15:0] env_out;       // envelope output

    envelope dut (
        .wr_strb(clk_sys),
        .ar(ar),
        .ar_rs(ar_rs),
        .dr(dr),
        .dr_rs(dr_rs),
        .sl(sl),
        .rr(rr),
        .rr_rs(rr_rs),
        .exp_mode_on(exp_mode_on),
        .key_on(key_on),
        .env_out(env_out)
    );

    // generating clk
    initial begin
        clk_sys = 0;
        forever #5 clk_sys = ~clk_sys; // 100 MHz (10ns period)
    end

    
    initial begin
        ar <= 8'd10;
        ar_rs <= 3'd2;
        dr <= 8'd10;
        dr_rs <= 3'd5;
        rr <= 8'd10;
        rr_rs <= 3'd4;
        sl <= 16'd45000;
        key_on <= 1'b0;

        #5 key_on <= 1'b1;
        #300000;
        #5 key_on <= 1'b0;
        #100000;
        $stop;

    end
    

endmodule
