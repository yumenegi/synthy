import math

# --- Configuration ---
WAVETABLE_SIZE = 1024
BIT_DEPTH = 16
MAX_VAL = (2**(BIT_DEPTH-1)) - 1  # 32767
MIN_VAL = -(2**(BIT_DEPTH-1))     # -32768

def to_hex(float_val):
    """Converts a float (-1.0 to 1.0) to 16-bit Hex String"""
    # Scale to integer range
    int_val = int(float_val * MAX_VAL)
    
    # Clamp just in case
    int_val = max(MIN_VAL, min(MAX_VAL, int_val))
    
    # Convert to 2's Complement Hex
    if int_val < 0:
        int_val = (1 << BIT_DEPTH) + int_val
        
    return f"{int_val:04X}"

def generate_square():
    print("Generating Square Wave...")
    samples = []
    for i in range(WAVETABLE_SIZE):
        # High for first half, Low for second half
        if i < (WAVETABLE_SIZE / 2):
            val = 1.0
        else:
            val = -1.0
        samples.append(to_hex(val))
    return samples

def generate_triangle():
    print("Generating Triangle Wave...")
    samples = []
    # Triangle goes from -1.0 to 1.0 and back to -1.0
    # Slope is 4.0 units per period (range of 2.0 * 2 slopes)
    
    for i in range(WAVETABLE_SIZE):
        t = i / WAVETABLE_SIZE # Normalized time 0.0 to 1.0
        
        if t < 0.5:
            # First half: Rising slope (-1 to 1)
            # y = mx + c -> y = 4t - 1
            val = (4.0 * t) - 1.0
        else:
            # Second half: Falling slope (1 to -1)
            # y = -4t + 3
            val = 3.0 - (4.0 * t)
            
        samples.append(to_hex(val))
    return samples

def write_coe(filename, samples):
    with open(filename, 'w') as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        
        for i, sample in enumerate(samples):
            separator = ",\n" if i < len(samples) - 1 else ";"
            f.write(sample + separator)
    print(f"Saved {filename}")

if __name__ == "__main__":
    # 1. Generate Square
    sq_data = generate_square()
    write_coe("square_1024.coe", sq_data)

    # 2. Generate Triangle
    tri_data = generate_triangle()
    write_coe("triangle_1024.coe", tri_data)
    
    print("Done!")