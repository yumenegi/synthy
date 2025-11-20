`timescale 1ns / 1ps

module tb_sine_sweep;
    logic Clk;
    logic [15:0] SW;
    logic [3:0] BTN;
    logic [15:0] LED;
    logic JA1_P, JA1_N, JA2_N;
    logic JA2_P;
    logic JB1_P, JB1_N, JB2_P, JB2_N;
    logic SPKL, SPKR;
    logic [15:0] AUDIO_OUT;
    
    // dut
    top dut (
        .Clk(Clk),
        .SW(SW),
        .BTN(BTN),
        .LED(LED),
        .JA1_P(JA1_P), .JA1_N(JA1_N), .JA2_P(JA2_P), .JA2_N(JA2_N),
        .JB1_P(JB1_P), .JB1_N(JB1_N), .JB2_P(JB2_P), .JB2_N(JB2_N),
        .SPKL(SPKL), .SPKR(SPKR)
    );
    
    // generating clk
    initial begin
        Clk = 0;
        forever #5 Clk = ~Clk; // 100 MHz (10ns period)
    end
    
    // record output 
    integer f;
    initial begin
        f = $fopen("audio_dump.txt", "w");
    end

    // log to file, slow
    always @(posedge dut.clk_sys) begin
        if (dut.wr_strb) begin // on write strobe, we log output of audio_out
            AUDIO_OUT <= dut.audio_out[0];
            $fdisplay(f, "%d", $signed(dut.audio_out[0])); 
        end
    end
    
    // stride = Freq * 2^32 / 44100
    function bit [31:0] calc_stride(input int freq);
        // use real math for calculation, then cast to int
        real stride_real;
        stride_real = (real'(freq) * 4294967296.0) / 44100.0;
        return 32'($rtoi(stride_real));
    endfunction
    
    initial begin
        SW = 0; 
        BTN = 0;
        JA1_P = 1; 
        JA1_N = 0; 
        JA2_N = 0; 
        
        // Reset Sequence
        // Wait a bit for the Clock Wizard to lock
        #100;
        wait(dut.locked == 1);
        
//        $display("Starting Sweep...");
//        #1000;
//        for (int f = 440; f <= 22000; f = f + 2000) begin
//            dut.stride[0] = calc_stride(f);
//            #2ms; 
//        end
//        $display("Sweep Complete. Saving file...");
        dut.stride[0] = calc_stride(1000); // 1khz test tone
        #2s; 
        $fclose(f);
        $stop;
    end
    
endmodule