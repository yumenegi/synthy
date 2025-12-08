`timescale 1ns / 1ps

module poly_tb;
    logic Clk = 0;
    logic [15:0] SW = 0;
    logic [3:0] BTN = 0;
    logic JA1_P=1, JA1_N=0, JA2_N=0;
    logic JA2_P, JB1_P, JB1_N, JB2_P, JB2_N;
    
    // Outputs
    logic [15:0] LED;
    logic SPKL, SPKR;
    logic [2:0] RGB0, RGB1;

    // --- Instantiate Top Level ---
    top_256 dut (
        .Clk(Clk),
        .SW(SW),
        .BTN(BTN),
        .LED(LED),
        .JA1_P(JA1_P), .JA1_N(JA1_N), .JA2_P(JA2_P), .JA2_N(JA2_N),
        .JB1_P(JB1_P), .JB1_N(JB1_N), .JB2_P(JB2_P), .JB2_N(JB2_N),
        .SPKL(SPKL), .SPKR(SPKR),
        .RGB0(RGB0), .RGB1(RGB1)
    );

    // --- Clock Generation ---
    always #5 Clk = ~Clk; // 100 MHz

    // --- Test Procedure ---
    initial begin
        $display("Starting Simulation...");
        
        // 1. Initialize
        // Force the undefined reset wire in TOP to 0 so PLL can lock
        force dut.clk_wiz.reset = 0; 
        
        #100;
        wait(dut.locked);
        $display("PLL Locked.");
        #1000;
        
        force dut.reset = 1;
        #10;
        force dut.reset = 0;
        
        force dut.mcu_wr_en = 0;
        
        
        

        // 2. CONFIGURATION (Backdoor via 'force')
        // Since SPI isn't driving these wires yet, we force them.
        
        // A. Configure Envelope #1 (Instant Attack, Full Sustain)
        $display("Configuring Envelope #1...");
        force dut.param_wr_en = 3'b100; // Bit 2 = Env Write
        force dut.param_wr_addr = 1;    // ID 1
        force dut.param_ar = 120; force dut.param_ar_rs = 8; // Instant
        force dut.param_dr = 0;   force dut.param_dr_rs = 0;
        force dut.param_sl = 16'hFFFF;                        // Max Vol
        force dut.param_rr = 120;  force dut.param_rr_rs = 8;
        #100;
        force dut.param_wr_en = 0;
        #100;

        // B. Configure Operator #0 (Play 440Hz Sine)
        $display("Configuring Operator #0...");
        // Calc Stride for 440Hz: (440 * 2^32) / 44100 = 42,852,281
        force dut.param_wr_en = 3'b001; // Bit 0 = Op Write
        force dut.param_wr_addr = 0;    // Op 0
        force dut.param_stride = 30301466; 
        force dut.param_wt_id = 0;      // Bank 0, Frame 0 (Sine)
        force dut.param_env_id = 1;     // Use Env #1
        force dut.param_key_on = 1;     // Key Down
        @(posedge dut.clk_sys);
        #50;
        force dut.param_wr_en = 0;
        
        $display("Configuring Operator #1...");
        // Calc Stride for 440Hz: (440 * 2^32) / 44100 = 42,852,281
        force dut.param_wr_en = 3'b001; // Bit 0 = Op Write
        force dut.param_wr_addr = 1;    // Op 0
        force dut.param_stride = 36033982; 
        force dut.param_wt_id = 0;      // Bank 0, Frame 0 (Sine)
        force dut.param_env_id = 1;     // Use Env #1
        force dut.param_key_on = 1;     // Key Down
        @(posedge dut.clk_sys);
        #50;
        force dut.param_wr_en = 0;
        
        $display("Configuring Operator #2...");
        // Calc Stride for 440Hz: (440 * 2^32) / 44100 = 42,852,281
        force dut.param_wr_en = 3'b001; // Bit 0 = Op Write
        force dut.param_wr_addr = 2;    // Op 0
        force dut.param_stride = 45399630; 
        force dut.param_wt_id = 0;      // Bank 0, Frame 0 (Sine)
        force dut.param_env_id = 1;     // Use Env #1
        force dut.param_key_on = 1;     // Key Down
        @(posedge dut.clk_sys);
        #50;
        force dut.param_wr_en = 0;
        #10ms; // Let tail ring out
    
//        // 4. Test Key Off (Release)
        $display("Releasing Key 0...");
        force dut.param_wr_en = 3'b001;
        force dut.param_wr_addr = 0;
        force dut.param_key_on = 0; // Key Up
        @(posedge dut.clk_sys);
        #50;
        force dut.param_wr_en = 0;
        #1ms;
        
        $display("Releasing Key 1...");
        force dut.param_wr_en = 3'b001;
        force dut.param_wr_addr = 1;
        force dut.param_key_on = 0; // Key Up
        @(posedge dut.clk_sys);
        #50;
        force dut.param_wr_en = 0;
        
        #1ms
        $display("Releasing Key 2...");
        force dut.param_wr_en = 3'b001;
        force dut.param_wr_addr = 2;
        force dut.param_key_on = 0; // Key Up
        @(posedge dut.clk_sys);
        #50;
        force dut.param_wr_en = 0;
        
        #5ms
        
        
//        #5ms; // Let tail ring out

        $display("Done.");
        $stop;
    end

endmodule
