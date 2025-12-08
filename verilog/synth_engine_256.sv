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
    input  logic            mcu_wr_en,      // 1 = Write Mode, 0 = Play Mode
    input  logic [1:0]      mcu_wr_bank,    // Which BRAM? (0-3)
    input  logic [16:0]     mcu_wr_addr,    // Address (0-131071)
    input  logic [15:0]     mcu_wr_data,    // Sample Data

    // BRAM intf for 4 wavetables
    // All BRAMs use the same address
    output logic [16:0]     bram_addr_a,
    output logic [16:0]     bram_addr_b,
    input  logic [15:0]     bram0_data_a, 
    input  logic [15:0]     bram0_data_b,
    input  logic [15:0]     bram1_data_a, 
    input  logic [15:0]     bram1_data_b,
    input  logic [15:0]     bram2_data_a, 
    input  logic [15:0]     bram2_data_b,
    input  logic [15:0]     bram3_data_a, 
    input  logic [15:0]     bram3_data_b,

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
    logic [23:0] op_env_gain_vol[256];               // env current state
    logic [2:0] op_env_gain_state[256];
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
    // get data into the registers
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
    // metastability
    logic [2:0] sync_chain = 0;
    
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
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠟⠟⠟⠟⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢼⢌⣅⣉⠊⠒⠐⠀⠂⠀⠄⡉⠛⢋⡩⠉⠉⢛⣉⣩⣉⢥⠤⢦⠤⠤⢄⠠⡠⢀⠄⡠⢀⠄⡈⠉⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⡪⡳⡜⢌⢉⣈⣡⣩⣬⣬⣦⣴⣴⣤⣴⣥⣌⣅⣌⠤⠠⠆⣔⢄⡢⣐⢄⢤⡠⡄⢔⠠⠢⡨⠘⡄⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⣈⣥⡶⣾⢯⣿⣻⣯⡿⣽⣯⢿⣽⣯⢿⣞⣿⣻⢟⢿⡿⣶⣤⣌⠑⠍⢮⠳⡜⠢⡨⢂⠕⠨⢂⠆⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⡿⢏⣥⣾⣯⢿⣾⡏⣿⢷⣟⣾⣻⣷⣻⣟⣷⣻⣯⢿⡾⣯⣿⣮⢎⡭⡫⡻⣷⣦⡐⠡⡉⠢⠢⠡⢌⠱⡀⠣⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⠟⣡⣿⡻⣪⣷⢿⣾⠁⣿⣯⣟⡷⣿⣞⣷⣯⣺⡕⢻⣯⣿⣳⢟⣾⢿⣜⢎⢧⣙⢞⢿⣦⡈⢑⠡⢃⠢⡑⠌⠢⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⡟⣡⣾⣿⠏⣰⣿⣽⣻⢗⠄⣿⡷⣿⡽⣷⡻⢾⣷⣧⢻⡄⢎⢷⢿⣗⢽⣟⢿⣎⢧⢪⡣⣍⡻⣽⣄⠡⠊⢔⢈⢊⠂⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⡿⢋⠀⣽⣿⠃⣼⡿⣿⢺⣿⢱⠀⢽⣿⢿⡯⢸⡇⠨⡻⣽⡇⢷⠈⡮⡹⣷⠸⣽⡳⢿⡂⢗⢭⡪⣎⢝⢿⣧⠈⠢⡡⠂⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣷⡟⣸⡿⡇⣸⣯⣿⠣⠘⣮⡃⣸⠘⣯⣻⣯⠀⢟⢀⠘⡴⡫⣫⠆⢹⡪⣚⢕⢽⡇⢻⣏⠐⣇⢗⡜⡵⡩⣿⣧⠈⠄⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⢁⣿⡏⢠⡿⣾⢧⠁⠄⢯⠀⣿⡇⢳⡹⣞⡀⡨⠂⢷⡈⢞⡜⡣⠈⡪⣡⢫⢺⡅⠳⣏⠆⢱⢕⡭⡺⢜⠮⣿⣗⡘⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⡏⣸⣯⠊⢰⣟⡿⡸⢰⣧⠨⠰⣿⣿⡌⢪⢻⡄⢳⡁⠸⣗⡈⢔⠖⠀⢹⡌⡧⣻⠀⣏⢎⠇⢸⢕⢮⡚⡵⣙⢞⣿⢷⣄⠠⣌⢍⣍⣍⢻⣿⣿⣿⣿⣿⣿ //
    // ⣿⠇⣿⠱⠁⢸⢮⣟⡌⣸⣿⡆⢸⣮⣿⣷⡌⠓⡦⢙⣷⣄⣿⣿⡈⢇⢸⢈⡞⡜⡮⠠⣇⣫⡃⢸⢕⡕⣝⢜⢎⡳⣻⣯⠉⠃⠄⠳⡜⡦⢸⣿⣿⣿⣿⣿⣿ //
    // ⣿⠅⣿⠁⣾⡁⢷⠳⠄⣿⣿⣿⣾⢨⣿⣿⣿⣆⠙⡄⢿⣿⣾⡂⣷⠀⣿⡄⣫⢚⠆⡸⡆⢷⠄⠑⢧⡹⡜⣪⢣⣝⣽⠚⡆⠑⡵⡢⣬⠚⣸⣿⣿⣿⣿⣿⣿ //
    // ⣿⡇⡯⢰⣿⣧⠘⣯⠐⣿⣿⣿⣿⠰⣿⣿⣿⣿⣷⣤⡘⢿⣿⠄⣿⣶⣿⡆⢸⠕⠀⣝⢜⡳⢀⣹⡄⢺⢜⡕⡵⣟⣾⡀⠣⠈⢎⡗⡼⠁⡟⣛⣛⣿⣿⣿⣿ //
    // ⣿⣇⠂⣾⣿⣿⡄⢳⠨⣿⣿⣿⣿⢈⣿⣿⣿⣿⣿⣻⣿⣾⣿⡃⣿⣿⣿⡅⠪⣰⠀⡷⡩⠎⢈⣷⡇⡸⡪⣎⡾⢙⣿⠀⠄⢈⠪⡮⡍⣼⣾⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣀⣿⣿⣿⣿⡄⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠆⢰⡇⢸⢕⠝⢀⣫⠏⡰⠅⡹⣼⠃⡠⣟⠀⡃⢄⠑⡞⢰⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣇⢨⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣵⣿⠃⡼⡃⠐⣋⢤⡪⡋⡀⣺⠏⣈⡃⢔⣤⣌⣐⠁⢃⣿⡿⢿⡻⠿⠿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣦⣍⠻⢿⣿⣿⣿⣿⣿⢐⢖⡶⡺⣿⣿⣿⣿⣿⣿⠟⠋⢠⠋⡠⠏⣪⢖⠍⣐⢁⠏⣴⣿⡇⣸⠿⢟⣛⣯⣵⣶⠿⠿⠿⠿⣛⣓⣒⣲ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠍⠙⠛⠿⢿⣦⣟⣽⣽⣿⠿⠿⠝⡋⠀⢴⡏⢈⣶⣶⣶⢈⢂⣾⡏⣈⣾⣛⣩⣤⣦⣭⣭⣷⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⢰⡉⠄⣤⣦⡄⣤⠰⣶⠶⢂⣾⠃⠀⠻⣠⣿⣿⣿⣿⢸⢨⣭⣴⣏⣛⣛⣙⡛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⣃⠸⣿⣿⡁⢸⠇⠈⢴⣿⡟⢀⢧⠀⡉⠋⠯⡻⠋⠈⢄⢍⢹⣙⣟⣿⣻⣵⣯⣭⣩⡩⢯⣽⣝⣏⣻⣙⣛⢿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⢩⣶⡾⠿⢃⣉⣪⡀⠄⡄⢁⢠⡉⢠⡪⡳⡂⠌⠀⠘⠂⢄⠘⠃⢑⣶⣌⡙⣿⣿⣿⣿⣿⣿⣿⣷⣶⣭⣝⡻⠿⣿⡷⡻⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣶⣾⣿⣿⣿⡅⢸⠅⠠⠀⢷⡈⢌⢩⣎⠘⡄⡉⠪⡠⠁⠑⠾⠵⣻⢶⡈⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣮⣵⣊⢿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⠀⢡⠘⡄⠄⢤⡢⡖⡵⠡⢌⢬⡲⣜⢺⠲⢂⣤⣾⣫⢷⠌⠻⠻⠻⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡠⢸⡢⣡⢜⢮⡪⣛⢴⢫⡲⣕⢵⡹⣄⠻⣿⣿⣿⣿⠅⠻⠿⠿⠿⢂⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⠙⡮⡪⡮⣪⡣⡳⣕⢳⢜⠎⣘⣄⣡⣨⣿⣿⡿⢢⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣌⠚⢮⡲⣙⢮⡪⠑⠹⠦⡘⣿⣿⣿⣿⣿⢃⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⡙⠜⢮⡪⢸⣿⣶⣦⣽⣿⣿⠟⣡⣶⣦⢮⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣦⠠⣅⣸⣿⣿⡿⠟⣩⣤⣦⣦⣶⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    // ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣬⣬⣴⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿ //
    ////////////////////////////////////////////////////////////////////////////

    logic [8:0] op_idx; // operator index
                        // bit 8, pipeline done bit
    logic processing;   // shift register
    logic [31:0] mixer_acc; // mixer accumulator, only updated when pipeline is
                            // done 
    logic [6:0] pipe_valid; // signal the data in pipe is valid

    // TODO: test pipeline delay
    always_ff @(posedge clk) begin
        if (reset) begin
            op_idx <= 0; 
            processing <= 0; 
            pipe_valid <= 0;
            mixer_acc <= 0;
        end else begin
            // If in Write Mode, we essentially pause/clear the pipeline valid bits
            // so no garbage audio is accumulated.
            if (mcu_wr_en) begin
                pipe_valid <= 0; // Kill pipeline
            end else begin
                pipe_valid <= {pipe_valid[5:0], processing};
            end

            if (tick && !mcu_wr_en) begin // Only start frame if not writing
                op_idx <= 0; // reset index to beginning
                processing <= 1; // start processing
                mixer_acc <= 0;  // clear mixer accumulator
            end else if (processing) begin // in pipe
                if (op_idx == 255) processing <= 0; // stop pipe if processed all
                else op_idx <= op_idx + 1; // else increment current slice
            end

            if (pipe_valid[3]) begin
                // Use the result from the previous combinational block
                mixer_acc <= mixer_acc + final_voice_sample; 
            end
            
            // after all slices are processed, the audio becomes valid
            if (pipe_valid[4] && !pipe_valid[3]) begin
                audio_out <= mixer_acc[23:8]; 
            end
        end
    end

    // stage 1: read update
    // logic [31:0] s1_stride; // unused
    // logic [31:0] s1_phase;
    // logic [9:0]  s1_wt_id;
    // logic [23:0] s1_env_vol;
    // logic [2:0]  s1_env_state;
    // logic        s1_key_on;
    // logic        s1_prev_key_on;
    // logic [31:0] s1_next_phase;
    localparam IDLE=0, ATTACK=1, DECAY=2, SUSTAIN=3, RELEASE=4;

    // envelope settings
    logic [2:0] s1_env_id;
    logic [7:0] s1_env_ar;
    logic [3:0] s1_env_ar_rs;
    logic [7:0] s1_env_dr;
    logic [3:0] s1_env_dr_rs;
    logic [15:0] s1_env_sl;
    logic [7:0] s1_env_rr;
    logic [3:0] s1_env_rr_rs;

    // // operation states
    // assign s1_stride        = op_stride_mem[op_idx];
    // assign s1_phase         = phase_mem[op_idx];
    // assign s1_wt_id         = op_wt_id_mem[op_idx];
    // assign s1_env_vol       = op_env_gain_vol[op_idx];
    // assign s1_env_state     = op_env_gain_state[op_idx];
    // assign s1_key_on        = op_key_on_mem[op_idx];
    // assign s1_prev_key_on   = op_prev_key_on_mem[op_idx];
    // assign s1_next_phase    = s1_phase + s1_stride;

    // setting to specific slice's envelope id
    assign s1_env_id        = op_wt_gain_env_id_mem[op_idx];
    assign s1_env_ar        = env_ar_mem[s1_env_id]; 
    assign s1_env_ar_rs     = env_ar_rs_mem[s1_env_id]; 
    assign s1_env_dr        = env_dr_mem[s1_env_id]; 
    assign s1_env_dr_rs     = env_dr_rs_mem[s1_env_id]; 
    assign s1_env_sl        = env_sl_mem[s1_env_id]; 
    assign s1_env_rr        = env_rr_mem[s1_env_id]; 
    assign s1_env_rr_rs     = env_rr_rs_mem[s1_env_id]; 

    // combinational read first stage of pipeline
    logic [31:0] r_stride;
    logic [31:0] r_phase;
    logic [9:0]  r_wt_id;
    logic [23:0] r_env_vol;
    logic [2:0]  r_env_state;
    logic        r_key_on;
    logic        r_prev_key_on;

    // first stage variable to next state
    logic [31:0] next_phase;
    logic [23:0] next_env_vol;
    logic [2:0]  next_env_state;
    logic        next_prev_key_on;

    // envelope increment and output level for vca
    logic [23:0] increment;

    // sl target bit extend
    logic [23:0] sl_target;
    logic sl_target = {s1_env_sl, 8'h00};

    // set rate depending on state
    always_comb begin
        r_stride        = op_stride_mem[op_idx];
        r_phase         = phase_mem[op_idx];
        r_wt_id         = op_wt_id_mem[op_idx];
        r_env_vol       = op_env_gain_vol[op_idx];
        r_env_state     = op_env_gain_state[op_idx];
        r_key_on        = op_key_on_mem[op_idx];
        r_prev_key_on   = op_prev_key_on_mem[op_idx];
        
        // next phase
        next_phase      = r_phase + r_stride;

        // default
        next_env_vol        = r_env_vol;
        next_env_state      = r_env_state;
        next_prev_key_on    = r_key_on;

        // increment logic
        case (r_env_state)
            ATTACK:  increment = {12'b0, s1_env_ar, 4'b0} << s1_env_ar_rs; 
            DECAY:   increment = {12'b0, s1_env_dr, 4'b0} << s1_env_dr_rs; 
            RELEASE: increment = {12'b0, s1_env_rr, 4'b0} << s1_env_rr_rs; 
            default: increment = 0;
        endcase
        
        // asdr transition logic
        case (r_env_state)
            IDLE: begin
                next_env_vol = 24'd0;
                if (r_key_on && !r_prev_key_on) begin
                    next_env_state = ATTACK;
                end
            end

            ATTACK: begin
                if (r_env_vol >= 24'hFFFFFF - increment) begin
                    next_env_vol = 24'hFFFFFF; // Clamp to Max
                    next_env_state = DECAY;    // Move to Decay
                end else begin
                    next_env_vol = r_env_vol + increment;
                end

                // Gate Logic: If key released early, go to Release
                if (!r_key_on) next_env_state = RELEASE;
            end

            DECAY: begin
                // Check if we passed the Sustain Level
                // Use a temporary larger variable to check subtraction result
                if (r_env_vol <= sl_target + increment) begin
                    next_env_vol = sl_target; // Snap to Sustain
                    next_env_state = SUSTAIN;
                end else begin
                    next_env_vol = r_env_vol - increment;
                end

                if (!r_key_on) next_env_state = RELEASE;
            end

            SUSTAIN: begin
                // Hold exact Sustain Level
                next_env_vol = {global_sl, 8'h00};
                
                // Wait for Key Off
                if (!r_key_on) next_env_state = RELEASE;
            end

            RELEASE: begin
                // Ramp down to 0
                if (r_env_vol <= increment) begin
                    next_env_vol = 24'd0; // Snap to 0
                    next_env_state = IDLE;
                end else begin
                    next_env_vol = r_env_vol - increment;
                end

                // Retriggering: If Key pressed again during release, restart
                if (r_key_on && !r_prev_key_on) next_env_state = ATTACK;
            end
            
            default: next_env_state = IDLE;
        endcase

    end

    logic [1:0]  s2_bank_sel;
    logic [15:0] s2_frac;
    logic [15:0] s2_env_vol_top;

    // stride calculation and envelope
    always_ff @(posedge clk) begin
        if (processing) begin
            ////////////////////////////////////////////////////////////////////
            // phase calculation
            phase_mem[op_idx] <= next_phase; // phase calculation, will be 
                                                // combined with the id
            // previous key on update
            op_prev_key_on_mem[op_idx] <= next_prev_key_on;

            ////////////////////////////////////////////////////////////////////
            // envelope stuff
            op_env_gain_vol[op_idx] <= next_env_vol;
            op_env_gain_state[op_idx] <= next_env_state;

            // pass off to stage 2
            s2_bank_sel <= r_wt_id[9:8];
            s2_frac <= next_phase[21:6];    // this is the 16 bit frac part
                                            // discarding last 6 bits
                                            // 16 bit for the interpolation
            s2_env_vol_top <= next_env_vol[23:8]; // msb for the vca
        end
    end

    // BRAM address calculation
    logic [16:0] calc_addr_a, calc_addr_b;
    // Bank bits [9:8] used for mux, frame bits [6:0] used here
    assign calc_addr_a = {r_wt_id[6:0], next_phase[31:22]};

    // Addr b for the next sample for interpolation
    assign calc_addr_b = calc_addr_a + 1;

    // write logic
    assign bram_addr_a = calc_addr_a;
    assign bram_addr_b = mcu_wr_en ? mcu_wr_addr : calc_addr_b;
    assign bram_wdata  = mcu_wr_data;

    always_comb begin
        bram_we = 4'b0000;
        if (mcu_wr_en) begin
            case (mcu_wr_bank)
                2'b00: bram_we = 4'b0001;
                2'b01: bram_we = 4'b0010;
                2'b10: bram_we = 4'b0100;
                2'b11: bram_we = 4'b1000;
            endcase
        end
    end


    // stage 2 delay for data
    // stall stage
    logic [1:0]  s3_bank_sel;
    logic [15:0] s3_frac;
    logic [15:0] s3_env_vol;

    always_ff @(posedge clk) begin
        s3_bank_sel <= s2_bank_sel;
        s3_frac     <= s2_frac;
        s3_env_vol  <= s2_env_vol_top;
    end

    // stage 3
    // data ready
    logic [15:0] raw_a, raw_b;
    
    always_comb begin
        case (s3_bank_sel)
            2'b00: begin raw_a = bram0_data_a; raw_b = bram0_data_b; end
            2'b01: begin raw_a = bram1_data_a; raw_b = bram1_data_b; end
            2'b10: begin raw_a = bram2_data_a; raw_b = bram2_data_b; end
            2'b11: begin raw_a = bram3_data_a; raw_b = bram3_data_b; end
        endcase
    end

    // VCA
    logic signed [15:0] interp_out;
    logic signed [31:0] vca_product;
    logic signed [15:0] final_voice_sample;
    logic signed [16:0] diff;
    logic signed [32:0] prod;

    always_comb begin
        if (pipe_valid[2]) begin // TODO, check pipe delay
            // linear interpolation
            diff = $signed(raw_b) - $signed(raw_a); // diff
            prod = diff * $signed({1'b0, s3_frac}); // fraction
            interp_out = $signed(raw_a) + (prod >>> 16); // add fraction

            // vca
            vca_product = $signed(interp_out) * $signed({1'b0, s3_env_vol});
            final_voice_sample = vca_product[31:16];
        end else begin
            final_voice_sample = 0;
        end
    end
    


    
endmodule
