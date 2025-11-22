module visualizer (
    input  logic        clk,
    input  logic        reset,
    input  logic [15:0] audio_in,
    input  logic [15:0] lfo_in,
    input  logic [31:0] stride_in,
    output logic [2:0]  rgb0,
    output logic [2:0]  rgb1
);

    // Dimming Factor: 2 = Divide by 4, 3 = Divide by 8
    // Increase this if LEDs are still too bright!
    localparam DIM_SHIFT = 4; 

    // PWM Counter (100 MHz)
    logic [7:0] pwm_cnt;
    always_ff @(posedge clk) pwm_cnt <= pwm_cnt + 1;

    function logic drive_led(input logic [7:0] level, input logic [7:0] counter);
        return (level > counter);
    endfunction

    // Registers for brightness
    logic [7:0] r0, g0, b0;
    logic [7:0] r1, g1, b1;

    // --- RGB0: LFO RAINBOW (Dimmed) ---
    logic [15:0] lfo_unsigned;
    assign lfo_unsigned = {~lfo_in[15], lfo_in[14:0]};

    always_comb begin
        // Apply Dimmer Shift immediately
        r0 = lfo_unsigned[15:8] >> DIM_SHIFT;
        g0 = (lfo_unsigned[15:8] + 8'd85)  >> DIM_SHIFT;
        b0 = (lfo_unsigned[15:8] + 8'd170) >> DIM_SHIFT;
    end

    // --- RGB1: AUDIO VU METER (Math Fixed) ---
    
    logic [15:0] abs_audio;
    assign abs_audio = audio_in[15] ? (~audio_in + 1) : audio_in;
    
    logic [7:0] base_r, base_g, base_b;
    
    always_comb begin
        // Pitch color logic
        if (stride_in[24:20] == 0) begin // Bass
             base_r = 255; base_g = 0; base_b = 0;
        end else if (stride_in[26]) begin // Treble
             base_r = 0; base_g = 100; base_b = 255;
        end else begin // Mid
             base_r = 0; base_g = 255; base_b = 50;
        end
    end

    // MATH FIX: Explicitly cast to 16-bit before multiply!
    // Then shift down by 8 (normalize) AND by DIM_SHIFT (brightness control)
    always_comb begin
        r1 = (16'(base_r) * 16'(abs_audio[15:8])) >> (8 + DIM_SHIFT);
        g1 = (16'(base_g) * 16'(abs_audio[15:8])) >> (8 + DIM_SHIFT);
        b1 = (16'(base_b) * 16'(abs_audio[15:8])) >> (8 + DIM_SHIFT);
    end

    // Output Assignments
    assign rgb0[0] = drive_led(r0, pwm_cnt);
    assign rgb0[1] = drive_led(g0, pwm_cnt);
    assign rgb0[2] = drive_led(b0, pwm_cnt);
    
    assign rgb1[0] = drive_led(r1, pwm_cnt);
    assign rgb1[1] = drive_led(g1, pwm_cnt);
    assign rgb1[2] = drive_led(b1, pwm_cnt);

endmodule