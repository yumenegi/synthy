`timescale 1ns / 1ps

module synth_engine_256(
    input   logic        clk,
    input   logic        reset,
    input   logic        wr_strb, // audio tick, strb signal, 44.1 or 48

    // parameter write
    input   logic [7:0]     param_wr_addr,  // which addr to write to
                                            // 8 adsr, 8 lfo, takes 3 lsb
    input   logic [2:0]     param_wr_en,    // write strobe
                                            // bit 2 writes adsr, bit 1 writes 
                                            // lfo, bit 0 writes synth slice

    // synth param in
    input   logic           param_key_on_in,
    input   logic [31:0]    param_stride_in,
    input   logic [9:0]     param_wt_id_in,     // wt_id, top 2 msb is bram id
                                                // bit 7 is lfo enable
                                                // 7 lsb is wt position
                                                // @important
                                                // the mcu is expected to know
                                                // how large the wt is so no
                                                // overflow occurs
    input   logic [2:0]     param_wt_lfo_id_in,    // lfo id, 0 to 8
    input   logic [2:0]     param_env_id_in,    // envelope id, 0 to 8

    // lfo param in
    input   logic [31:0]    param_lfo_stride_in,

    // env adsr param in
    input   logic [7:0]     param_ar_in, 
    input   logic [3:0]     param_ar_rs_in,
    input   logic [7:0]     param_dr_in,
    input   logic [3:0]     param_dr_rs_in,
    input   logic [15:0]    param_sl_in,
    input   logic [7:0]     param_rr_in,
    input   logic [3:0]     param_rr_rs_in,

    // wavetable write mode control
    input  logic        mcu_wr_en,      // 1 = Write Mode, 0 = Play Mode
    input  logic [1:0]  mcu_wr_bank,    // Which BRAM? (0-3)
    input  logic [16:0] mcu_wr_addr,    // Address (0-131071)
    input  logic [15:0] mcu_wr_data,    // Sample Data

    // BRAM intf for 4 wavetables
    // All BRAMs use the same address
    output logic [16:0] bram_addr_a,
    output logic [16:0] bram_addr_b,
    input  logic [15:0] bram0_data_a, 
    input  logic [15:0] bram0_data_b,
    input  logic [15:0] bram1_data_a, 
    input  logic [15:0] bram1_data_b,
    input  logic [15:0] bram2_data_a, 
    input  logic [15:0] bram2_data_b,
    input  logic [15:0] bram3_data_a, 
    input  logic [15:0] bram3_data_b,

    output logic [15:0] audio_out // mixed audio out
    );

    ////////////////////////////////////////////////////////////////////////////
    // wavetable signals
    ////////////////////////////////////////////////////////////////////////////
    // setting mem
    logic [31:0] op_stride_mem [256];           // stride
    logic [9:0] op_wt_id_mem [256];             // wt settings, id, slice, lfo
    logic [2:0] op_wt_lfo_id_mem [256];         // which lfo?
    logic [2:0] op_wt_gain_env_id_mem [256];    // which gain env?
    logic op_key_on_mem [256];               // which op to turn on?

    // non-settable state saving
    logic [31:0] phase_mem [256];               // accumulator, fixed point 
    logic [23:0] op_env_gain_vol;
    logic [2:0] op_env_gain_state;
    logic op_prev_key_on_mem [256];             // mem for env
    ////////////////////////////////////////////////////////////////////////////
    
    // lfo settings
    logic [31:0] lfo_stride_mem [8];
    logic [2:0] wr_addr_lfo;
    assign wr_addr_lfo = param_wr_addr[2:0];

    // adsr setting
    logic [7:0] env_ar_mem [8];         // attack rate
    logic [3:0] env_ar_rs_mem [8];      // rate scaling
    logic [7:0] env_dr_mem [8];         // decay rate
    logic [3:0] env_dr_rs_mem [8];      // rate scaling
    logic [15:0] env_sl_mem [8];        // sustain level
    logic [7:0] env_rr_mem [8];         // release rate
    logic [3:0] env_rr_rs_mem [8];      // rate scaling
    logic [2:0] wr_addr_env;
    assign wr_addr_env = param_wr_addr[2:0];

    // write logic
    always_ff @(posedge clk) begin
        // write operating setting
        if (param_wr_en[0]) begin
            op_stride_mem[param_wr_addr] <= param_stride_in;
            op_wt_id_mem[param_wr_addr] <= param_wt_id_in;
            op_wt_lfo_id_mem[param_wr_addr] <= param_wt_lfo_id_in;
            op_wt_gain_env_id_mem[param_wr_addr] <= param_env_id_in;
            op_key_on_mem[param_wr_addr] <= param_key_on_in;
        end 
        
        else if (param_wr_en[1]) begin
            lfo_stride_mem[wr_addr_lfo] <= param_lfo_stride_in;
        end

        else if (param_wr_en[2]) begin
            env_ar_mem[wr_addr_env] <= param_ar_in;
            env_ar_rs_mem[wr_addr_env] <= param_ar_rs_in;
            env_dr_mem[wr_addr_env] <= param_dr_in;
            env_dr_rs_mem[wr_addr_env] <= param_dr_rs_in;
            env_sl_mem[wr_addr_env] <= param_sl_in;
            env_rr_mem[wr_addr_env] <= param_rr_in;
            env_rr_rs_mem[wr_addr_env] <= param_rr_rs_in;
        end
    end
    ////////////////////////////////////////////////////////////////////////////
    // Sync audio strobe
    // crossing clock domains!
    // sync chain acting as shift register to bring wr_strb into clk_sys domain from mclk
    logic [2:0] sync_chain = 0;
    
    // generated trigger signal
    logic stride_trigger;
    
    // 3 stage signal
    always_ff @(posedge clk_sys) begin
        // shift the slow signal into our fast domain
        // sync_chain[0] = metastable
        // sync_chain[1] = synchronized input 
        // sync_chain[2] = history (for edge detection)
        sync_chain <= {sync_chain[1:0], wr_strb};
    end
    
    // negedge
    assign tick = (sync_chain[1] == 1'b1) && (sync_chain[2] == 1'b0);

    ////////////////////////////////////////////////////////////////////////////
    // pipeline control
    ////////////////////////////////////////////////////////////////////////////
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠟⠟⠟⠟⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢼⢌⣅⣉⠊⠒⠐⠀⠂⠀⠄⡉⠛⢋⡩⠉⠉⢛⣉⣩⣉⢥⠤⢦⠤⠤⢄⠠⡠⢀⠄⡠⢀⠄⡈⠉⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⡪⡳⡜⢌⢉⣈⣡⣩⣬⣬⣦⣴⣴⣤⣴⣥⣌⣅⣌⠤⠠⠆⣔⢄⡢⣐⢄⢤⡠⡄⢔⠠⠢⡨⠘⡄⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⣈⣥⡶⣾⢯⣿⣻⣯⡿⣽⣯⢿⣽⣯⢿⣞⣿⣻⢟⢿⡿⣶⣤⣌⠑⠍⢮⠳⡜⠢⡨⢂⠕⠨⢂⠆⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⡿⢏⣥⣾⣯⢿⣾⡏⣿⢷⣟⣾⣻⣷⣻⣟⣷⣻⣯⢿⡾⣯⣿⣮⢎⡭⡫⡻⣷⣦⡐⠡⡉⠢⠢⠡⢌⠱⡀⠣⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⠟⣡⣿⡻⣪⣷⢿⣾⠁⣿⣯⣟⡷⣿⣞⣷⣯⣺⡕⢻⣯⣿⣳⢟⣾⢿⣜⢎⢧⣙⢞⢿⣦⡈⢑⠡⢃⠢⡑⠌⠢⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⡟⣡⣾⣿⠏⣰⣿⣽⣻⢗⠄⣿⡷⣿⡽⣷⡻⢾⣷⣧⢻⡄⢎⢷⢿⣗⢽⣟⢿⣎⢧⢪⡣⣍⡻⣽⣄⠡⠊⢔⢈⢊⠂⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⡿⢋⠀⣽⣿⠃⣼⡿⣿⢺⣿⢱⠀⢽⣿⢿⡯⢸⡇⠨⡻⣽⡇⢷⠈⡮⡹⣷⠸⣽⡳⢿⡂⢗⢭⡪⣎⢝⢿⣧⠈⠢⡡⠂⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣷⡟⣸⡿⡇⣸⣯⣿⠣⠘⣮⡃⣸⠘⣯⣻⣯⠀⢟⢀⠘⡴⡫⣫⠆⢹⡪⣚⢕⢽⡇⢻⣏⠐⣇⢗⡜⡵⡩⣿⣧⠈⠄⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⢁⣿⡏⢠⡿⣾⢧⠁⠄⢯⠀⣿⡇⢳⡹⣞⡀⡨⠂⢷⡈⢞⡜⡣⠈⡪⣡⢫⢺⡅⠳⣏⠆⢱⢕⡭⡺⢜⠮⣿⣗⡘⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⡏⣸⣯⠊⢰⣟⡿⡸⢰⣧⠨⠰⣿⣿⡌⢪⢻⡄⢳⡁⠸⣗⡈⢔⠖⠀⢹⡌⡧⣻⠀⣏⢎⠇⢸⢕⢮⡚⡵⣙⢞⣿⢷⣄⠠⣌⢍⣍⣍⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⠇⣿⠱⠁⢸⢮⣟⡌⣸⣿⡆⢸⣮⣿⣷⡌⠓⡦⢙⣷⣄⣿⣿⡈⢇⢸⢈⡞⡜⡮⠠⣇⣫⡃⢸⢕⡕⣝⢜⢎⡳⣻⣯⠉⠃⠄⠳⡜⡦⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⠅⣿⠁⣾⡁⢷⠳⠄⣿⣿⣿⣾⢨⣿⣿⣿⣆⠙⡄⢿⣿⣾⡂⣷⠀⣿⡄⣫⢚⠆⡸⡆⢷⠄⠑⢧⡹⡜⣪⢣⣝⣽⠚⡆⠑⡵⡢⣬⠚⣸⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⡇⡯⢰⣿⣧⠘⣯⠐⣿⣿⣿⣿⠰⣿⣿⣿⣿⣷⣤⡘⢿⣿⠄⣿⣶⣿⡆⢸⠕⠀⣝⢜⡳⢀⣹⡄⢺⢜⡕⡵⣟⣾⡀⠣⠈⢎⡗⡼⠁⡟⣛⣛⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣇⠂⣾⣿⣿⡄⢳⠨⣿⣿⣿⣿⢈⣿⣿⣿⣿⣿⣻⣿⣾⣿⡃⣿⣿⣿⡅⠪⣰⠀⡷⡩⠎⢈⣷⡇⡸⡪⣎⡾⢙⣿⠀⠄⢈⠪⡮⡍⣼⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣀⣿⣿⣿⣿⡄⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠆⢰⡇⢸⢕⠝⢀⣫⠏⡰⠅⡹⣼⠃⡠⣟⠀⡃⢄⠑⡞⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣇⢨⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣵⣿⠃⡼⡃⠐⣋⢤⡪⡋⡀⣺⠏⣈⡃⢔⣤⣌⣐⠁⢃⣿⡿⢿⡻⠿⠿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣦⣍⠻⢿⣿⣿⣿⣿⣿⢐⢖⡶⡺⣿⣿⣿⣿⣿⣿⠟⠋⢠⠋⡠⠏⣪⢖⠍⣐⢁⠏⣴⣿⡇⣸⠿⢟⣛⣯⣵⣶⠿⠿⠿⠿⣛⣓⣒⣲⣩⣭⣽
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠍⠙⠛⠿⢿⣦⣟⣽⣽⣿⠿⠿⠝⡋⠀⢴⡏⢈⣶⣶⣶⢈⢂⣾⡏⣈⣾⣛⣩⣤⣦⣭⣭⣷⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⢰⡉⠄⣤⣦⡄⣤⠰⣶⠶⢂⣾⠃⠀⠻⣠⣿⣿⣿⣿⢸⢨⣭⣴⣏⣛⣛⣙⡛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⣃⠸⣿⣿⡁⢸⠇⠈⢴⣿⡟⢀⢧⠀⡉⠋⠯⡻⠋⠈⢄⢍⢹⣙⣟⣿⣻⣵⣯⣭⣩⡩⢯⣽⣝⣏⣻⣙⣛⢿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⢩⣶⡾⠿⢃⣉⣪⡀⠄⡄⢁⢠⡉⢠⡪⡳⡂⠌⠀⠘⠂⢄⠘⠃⢑⣶⣌⡙⣿⣿⣿⣿⣿⣿⣿⣷⣶⣭⣝⡻⠿⣿⡷⡻⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣶⣾⣿⣿⣿⡅⢸⠅⠠⠀⢷⡈⢌⢩⣎⠘⡄⡉⠪⡠⠁⠑⠾⠵⣻⢶⡈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣮⣵⣊⢿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⢡⠘⡄⠄⢤⡢⡖⡵⠡⢌⢬⡲⣜⢺⠲⢂⣤⣾⣫⢷⠌⠻⠻⠻⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡠⢸⡢⣡⢜⢮⡪⣛⢴⢫⡲⣕⢵⡹⣄⠻⣿⣿⣿⣿⠅⠻⠿⠿⠿⢂⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⠙⡮⡪⡮⣪⡣⡳⣕⢳⢜⠎⣘⣄⣡⣨⣿⣿⡿⢢⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣌⠚⢮⡲⣙⢮⡪⠑⠹⠦⡘⣿⣿⣿⣿⣿⢃⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⡙⠜⢮⡪⢸⣿⣶⣦⣽⣿⣿⠟⣡⣶⣦⢮⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⠠⣅⣸⣿⣿⡿⠟⣩⣤⣦⣦⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣬⣬⣴⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
    ////////////////////////////////////////////////////////////////////////////

    logic [8:0] op_idx; // operator index
                        // bit 8, pipeline done bit
    logic processing;
    logic [31:0] mixer_acc;
    logic [6:0] pipe_valid;

    always_ff @(posedge clk) begin
        if (reset) begin
            op_idx <= 0; 
            processing <= 0; 
            pipe_valid <= 0;
        end else begin
            // If in Write Mode, we essentially pause/clear the pipeline valid bits
            // so no garbage audio is accumulated.
            if (mcu_wr_en) begin
                pipe_valid <= 0; // Kill pipeline
            end else begin
                pipe_valid <= {pipe_valid[5:0], processing};
            end

            if (tick && !mcu_wr_en) begin // Only start frame if not writing
                op_idx <= 0;
                processing <= 1;
                mixer_acc <= 0; 
            end else if (processing) begin // in pipe
                if (op_idx == 255) processing <= 0; // stop pipe if processed all
                else op_idx <= op_idx + 1; // else increment current slice
            end
            
            // after all slices are processed, the audio becomes valid
            if (pipe_valid[6] && !pipe_valid[5]) begin
                audio_out <= mixer_acc[23:8]; 
            end
        end
    end

    // stage 1: read update
    // TODO: Missing states
    // need states for env and stuff
    logic [31:0] s1_stride;
    logic [31:0] s1_phase;
    logic [9:0]  s1_wt_id;
    logic [23:0] s1_env_vol;
    logic [2:0]  s1_env_state;
    logic        s1_key_on;
    logic        s1_prev_key_on;
    logic [31:0] s1_next_phase;
    logic [23:0] s1_next_vol;
    logic [2:0]  s1_next_state;
    logic        s1_next_prev_key_on;
    localparam IDLE=0, ATTACK=1, DECAY=2, SUSTAIN=3, RELEASE=4;

    
endmodule
