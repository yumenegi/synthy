module i2s_transmitter (
    input  logic clk_audio,
    input  logic reset,
    input  logic [15:0] sample_in,
    output logic mclk,
    output logic bclk,
    output logic lrclk, 
    output logic sdata, 
    output logic ready_for_sample // strobe signal for data
);
    assign mclk = clk_audio;

    logic [7:0] counter;
    
    always_ff @(posedge clk_audio) begin
        if (reset) counter <= 0;
        else       counter <= counter + 1;
    end
    
    assign bclk  = counter[1]; 
    assign lrclk = counter[7]; 
    
    assign ready_for_sample = (counter == 8'd0); 
    
endmodule