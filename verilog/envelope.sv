`timescale 1ns / 1ps


module envelope(
    input logic wr_strb,        // 44.1khz strobe signal
    input logic [7:0] ar,       // attack rate
    input logic [3:0] ar_rs,  // rate scaling
    input logic [7:0] dr,     // decay rate
    input logic [3:0] dr_rs,  // rate scaling
    input logic [15:0] sl,     // sustain level
    input logic [7:0] rr,     // release rate
    input logic [3:0] rr_rs,  // rate scaling
    input logic [2:0] exp_mode_on,        // attack, decay, release exp on
    input logic key_on,       // key on
    output logic [15:0] env_out       // envelope output
    );
    
    // FSM States
    typedef enum logic [2:0] {IDLE, ATTACK, DECAY, SUSTAIN, RELEASE} state_t;
    state_t state = IDLE;
    
    // Output level, 24 bits, we only take 16 msb
    logic [23:0] output_level; 
    
    // Increment calculation
    logic [23:0] increment;
    
    // remember summer days
    logic prev_key_on;

    // set rate depending on state
    always_comb begin
        case (state)
            ATTACK:  increment = {12'b0, ar, 4'b0} << ar_rs; 
            DECAY:   increment = {12'b0, dr, 4'b0} << dr_rs; 
            RELEASE: increment = {12'b0, rr, 4'b0} << rr_rs; 
            default: increment = 0;
        endcase
    end
    
    // FSM
    always_ff @(posedge wr_strb) begin
        prev_key_on <= key_on;
        case (state)
            IDLE: begin
                output_level <= 24'b0;
                if (~prev_key_on & key_on)
                    state <= ATTACK;
            end

            ATTACK: begin
                // Check level
                // If the level is greater than ffff00, on the next increment
                // it will overflow
                if (output_level >= 24'hffff00) begin 
                    // set max vol
                    output_level <= 24'hffffff;
                    state <= DECAY; 
                end else begin
                    output_level <= output_level + increment;
                end

                // Early release
                if (!key_on) state <= RELEASE;
            end

            DECAY: begin
                // Check level
                // If the level will dip below sustain
                if (output_level <= {sl, 8'h00}) begin 
                    // set max vol
                    output_level <= {sl, 8'h00};
                    state <= SUSTAIN; 
                end else begin
                    output_level <= output_level - increment;
                end

                // Early release
                if (!key_on) state <= RELEASE;
            end

            SUSTAIN: begin
                // set sustain level
                output_level <= {sl, 8'h00};

                // key release
                if (!key_on) state <= RELEASE;
            end

            RELEASE: begin
                // will underflow
                if (output_level <= increment) begin 
                    // set min
                    output_level <= 24'b0;
                    state <= IDLE; 
                end else begin
                    output_level <= output_level - increment;
                end

                // re-attack? rettack? 
                // == re: attack ==
                if (~prev_key_on & key_on)
                    state <= ATTACK;
            end

            default:
                state <= IDLE;
        endcase
    end 

    // take msb
    assign env_out = output_level[23:8];
endmodule
