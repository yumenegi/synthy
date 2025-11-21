`timescale 1ns / 1ps

module wt_scanning(
    input logic clk_sys,            // 100mhz sys clk
    input logic wr_strb,            // write strobe 
    input logic [31:0] stride,      // stride
    input logic [15:0] amod,        // amplitude modifier, from envelope generator or lfo
                                    // unused for now
    input logic [6:0] wt_pos,       // wavetable position, up to 12                           
    output logic [5:0] stride_ptr,  // 64 total different stride positions
                                    // unused (?)
                                    // prob implement master side
    output logic [15:0] audio_out   // output
    );
    // wavetable wires
    logic [9:0] phase_addr;
    logic [15:0] wt_data;
    
    // fixed point 32-bit stride accumulator
    logic [31:0] phase_addr_32 = 0;
    
    // phase_addr will take the 10-bit msb
    assign phase_addr = phase_addr_32[31:22];
    
    // combine wt_pos and phase addr
    logic [16:0] bram_addr;
    assign bram_addr = {wt_pos, phase_addr};
    // instantiate wavetable 0
    blk_mem_gen_0 wt (
        .addra(bram_addr),
        .clka(clk_sys),
        .douta(wt_data),
        .ena(1'b1)
    );
    
    // assign BRAM output to module output
    assign audio_out = wt_data;
    
    // crossing clock domains woohoo!
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
    assign stride_trigger = (sync_chain[1] == 1'b1) && (sync_chain[2] == 1'b0);
    
    // we striding
    always_ff @(posedge clk_sys) begin
        if (stride_trigger) begin
            // Only add the stride ONCE per audio sample request
            phase_addr_32 <= phase_addr_32 + stride;
        end
    end
endmodule
