`timescale 1ns / 1ps

module board_test (
    input logic clk,
    input logic btn,
    input logic [31:0] stride_in,
    output logic [31:0] param_stride,
    output logic [2:0] param_wr_en,
    output logic [7:0] param_wr_addr,
    output logic [9:0] param_wt_id,
    output logic [2:0] param_env_id,
    output logic [2:0] param_wt_lfo_id,
    output logic param_key_on
);
    logic [3:0] state;
    logic [3:0] state_next;
    logic btn_last;

    localparam S_IDLE = 4'd0;
    localparam S_ON_0 = 4'd1;

    initial begin
        state = 0;
        state_next = 0;
    end

    always_comb begin
        // posedge

        case (state)
            S_IDLE: begin
                if (btn_last == 0 && btn == 1) begin
                    state_next = S_ON_0;
                end
                else if (btn_last == 1 && btn == 0) begin
                    state_next = S_OFF_0;
                end
                else begin
                    state_next = state;
                end
            end

            S_ON_0: begin 
                param_wr_en = 3'b001;
                param_wr_addr = 8'd0;
                param_wt_id = 10'b0;
                param_env_id = 0;
                param_key_on = 1;
                param_stride = stride_in;
                state_next = S_ON_1;
            end

            S_ON_1: begin 
                param_wr_en = 3'b001;
                param_wr_addr = 8'd1;
                param_wt_id = 10'b0100000000;
                param_env_id = 0;
                param_key_on = 1;
                param_stride = stride_in >> 1;
                state_next = S_ON_2;
            end

            S_ON_2: begin 
                param_wr_en = 3'b001;
                param_wr_addr = 8'd2;
                param_wt_id = 10'b1000000000;
                param_env_id = 0;
                param_key_on = 1;
                param_stride = stride_in << 1;
                state_next = S_IDLE;
            end

            S_OFF_0: begin 
                param_wr_en = 3'b001;
                param_wr_addr = 8'd0;
                param_wt_id = 0;
                param_env_id = 0;
                param_key_on = 0;
                param_stride = 0;
                state_next = S_OFF_1;
            end

            S_OFF_1: begin 
                param_wr_en = 3'b001;
                param_wr_addr = 8'd1;
                param_wt_id = 0;
                param_env_id = 0;
                param_key_on = 0;
                param_stride = 0;
                state_next = S_OFF_2;
            end

            S_OFF_2: begin 
                param_wr_en = 3'b001;
                param_wr_addr = 8'd2;
                param_wt_id = 0;
                param_env_id = 0;
                param_key_on = 0;
                param_stride = 0;
                state_next = S_IDLE;
            end

        endcase
    end

    always_ff @(posedge clk) begin
        state <= state_next;
        btn_last <= btn;
    end
endmodule