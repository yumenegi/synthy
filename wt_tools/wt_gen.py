import math

# Configuration
FILENAME = "sine_wave_1024.coe"
WAVETABLE_SIZE = 1024
BIT_DEPTH = 16
MAX_VAL = (2**(BIT_DEPTH-1)) - 1  # 32767 for 16-bit

def generate_sine():
    samples = []
    for i in range(WAVETABLE_SIZE):
        # Calculate sine (-1.0 to 1.0)
        float_val = math.sin(2 * math.pi * i / WAVETABLE_SIZE)
        
        # Scale to integer range (-32767 to 32767)
        int_val = int(float_val * MAX_VAL)
        
        # Convert to 2's Complement Hex
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
data = generate_sine()
write_coe(data)