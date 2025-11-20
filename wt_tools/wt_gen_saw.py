# Configuration
FILENAME = "sawtooth_1024.coe"
WAVETABLE_SIZE = 1024
BIT_DEPTH = 16
MAX_VAL = (2**(BIT_DEPTH-1)) - 1  # 32767 for 16-bit
MIN_VAL = -(2**(BIT_DEPTH-1))     # -32768

def generate_sawtooth():
    samples = []
    # Sawtooth goes linearly from MIN to MAX (or MAX to MIN)
    # Formula: y = 2 * (x / N) - 1  (Normalized -1.0 to 1.0)
    
    for i in range(WAVETABLE_SIZE):
        # Calculate normalized value (-1.0 to almost 1.0)
        float_val = 2.0 * (i / WAVETABLE_SIZE) - 1.0
        
        # Scale to integer range
        int_val = int(float_val * MAX_VAL)
        
        # Convert to 2's Complement Hex (Standard for FPGA Audio)
        if int_val < 0:
            int_val = (1 << BIT_DEPTH) + int_val
            
        # Format as 4-digit Hex (e.g., "7FFF")
        hex_str = f"{int_val:04X}"
        samples.append(hex_str)
    return samples

def write_coe(samples):
    with open(FILENAME, 'w') as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        
        # Write all samples separated by comma/newline
        for i, sample in enumerate(samples):
            separator = ",\n" if i < len(samples) - 1 else ";"
            f.write(sample + separator)
            
    print(f"Successfully generated {FILENAME} with {len(samples)} samples.")

# Run it
data = generate_sawtooth()
write_coe(data)