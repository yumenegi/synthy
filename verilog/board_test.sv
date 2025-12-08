`timescale 1ns / 1ps

module board_test (
    input  logic        clk,
    input  logic        reset,
    input  logic        btn,
    input  logic [31:0] stride_in,
    
    // Operator Control
    output logic [31:0] param_stride,
    output logic [2:0]  param_wr_en,    // [2]=Env, [1]=LFO, [0]=Op
    output logic [7:0]  param_wr_addr,
    output logic [9:0]  param_wt_id,
    output logic [2:0]  param_env_id,
    output logic [2:0]  param_wt_lfo_id,
    output logic        param_key_on,
    
    // NEW: Envelope Parameter Outputs
    output logic [7:0]  param_ar, 
    output logic [3:0]  param_ar_rs,
    output logic [7:0]  param_dr,
    output logic [3:0]  param_dr_rs,
    output logic [15:0] param_sl,
    output logic [7:0]  param_rr,
    output logic [3:0]  param_rr_rs
);

    typedef enum logic [3:0] {
        S_IDLE, 
        S_INIT_ENV,             // NEW: Program the Envelope first
        S_ON_0, S_ON_1, S_ON_2, S_ON_3, S_ON_4,
        S_OFF_0, S_OFF_1, S_OFF_2, S_OFF_3, S_OFF_4
    } state_t;

    state_t state = S_IDLE;
    state_t state_next;
    logic btn_last = 0; 

    logic [48:0] detune_down;
    logic [48:0] detune_up;
    assign detune_down = stride_in * 17'd65156;
    assign detune_up = stride_in * 17'd65916;



    always_comb begin
        // 1. DEFAULTS (Prevent Latches)
        param_wr_en     = 0;
        param_wr_addr   = 0;
        
        // Op Defaults
        param_stride    = 0;
        param_wt_id     = 0;
        param_env_id    = 0;
        param_wt_lfo_id = 0;
        param_key_on    = 0;
        
        // Env Defaults
        param_ar        = 0;
        param_ar_rs     = 0;
        param_dr        = 0;
        param_dr_rs     = 0;
        param_sl        = 0;
        param_rr        = 0;
        param_rr_rs     = 0;
        
        state_next      = state;

        case (state)
            S_IDLE: begin
                // Rising Edge -> Go to Init Env first!
                if (!btn_last && btn)       state_next = S_INIT_ENV;
                // Falling Edge -> Go to Off
                else if (btn_last && !btn)  state_next = S_OFF_0;
            end

            // --- NEW STATE: Program Envelope #0 ---
            S_INIT_ENV: begin
                param_wr_en   = 3'b100; // Bit 2 = Write Envelope Memory
                param_wr_addr = 8'd0;   // Target Envelope ID #0
                
                // Settings: Fast Attack, Max Sustain, Fast Release (Snappy)
                param_ar    = 8'd10;  param_ar_rs = 4'd3; // Fast Attack
                param_dr    = 8'd10;  param_dr_rs = 4'd2; // Fast Decay
                param_sl    = 16'h9999;                   // Max Sustain
                param_rr    = 8'd10;  param_rr_rs = 4'd0; // Fast Release
                
                state_next = S_ON_0; // Now turn on the notes
            end

            S_ON_0: begin 
                param_wr_en   = 3'b001; // Bit 0 = Write Operator
                param_wr_addr = 8'd0;   // Op 0
                param_wt_id   = 10'b0;
                param_env_id  = 0;      // Use Env #0 (Which we just programmed!)
                param_key_on  = 1;
                param_stride  = stride_in;
                state_next    = S_ON_1;
            end

            S_ON_1: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd1;   // Op 1
                param_wt_id   = 10'b0100000000;
                param_env_id  = 0;      // Use Env #0
                param_key_on  = 1;
                param_stride  = stride_in;
                state_next    = S_ON_2;
            end

            S_ON_2: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd2;   // Op 2
                param_wt_id   = 10'b1000000000;
                param_env_id  = 0;      // Use Env #0
                param_key_on  = 1;
                param_stride  = stride_in << 1;
                state_next    = S_ON_3;
            end

            S_ON_3: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd3;   // Op 2
                param_wt_id   = 10'b0100000000;
                param_env_id  = 0;      // Use Env #0
                param_key_on  = 1;
                param_stride  = detune_down[47:16];
                state_next    = S_ON_4;
            end

            S_ON_4: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd4;   // Op 2
                param_wt_id   = 10'b0100000000;
                param_env_id  = 0;      // Use Env #0
                param_key_on  = 1;
                param_stride  = detune_up[47:16];
                state_next    = S_IDLE;
            end

            S_OFF_0: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd0;
                param_wt_id   = 10'b0000000000;
                param_env_id  = 0;
                param_key_on  = 0; // Key Up
                param_stride  = stride_in;
                state_next    = S_OFF_1;
            end

            S_OFF_1: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd1;
                param_wt_id   = 10'b0100000000;
                param_env_id  = 0;
                param_key_on  = 0;
                param_stride  = stride_in;
                state_next    = S_OFF_2;
            end

            S_OFF_2: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd2;
                param_wt_id   = 10'b1000000000;
                param_env_id  = 0;
                param_key_on  = 0;
                param_stride  = stride_in << 1;
                state_next    = S_OFF_3;
            end

            S_OFF_3: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd3;
                param_wt_id   = 10'b0100000000;
                param_env_id  = 0;
                param_key_on  = 0;
                param_stride  = detune_down[47:16];
                state_next    = S_OFF_4;
            end

            S_OFF_4: begin 
                param_wr_en   = 3'b001;
                param_wr_addr = 8'd4;
                param_wt_id   = 10'b0100000000;
                param_env_id  = 0;
                param_key_on  = 0;
                param_stride  = detune_up[47:16];
                state_next    = S_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            btn_last <= 0;
        end else begin
            state <= state_next;
            btn_last <= btn;
        end
    end
endmodule