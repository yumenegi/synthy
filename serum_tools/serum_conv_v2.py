import numpy as np
from scipy.io import wavfile
from scipy.signal import resample
import sys
import os

# --- Configuration ---
INPUT_FILENAME = "VR_Growl_02.wav"  # Change this to your file!
OUTPUT_FILENAME = "VR_Growl_02.coe"

# Target Dimensions
TARGET_FRAMES = 128      # We want 128 positions
TARGET_SAMPLES = 1024    # We want 1024 samples per wave
BIT_DEPTH = 16

# Source Dimensions (Serum Standard)
SRC_SAMPLES = 2048
SRC_FRAMES = 256

def process_serum_table():
    print(f"Loading {INPUT_FILENAME}...")
    
    try:
        sr, data = wavfile.read(INPUT_FILENAME)
    except FileNotFoundError:
        print("Error: File not found.")
        return

    # 1. Normalize Audio to Float (-1.0 to 1.0)
    if data.dtype == np.int16:
        data = data.astype(float) / 32768.0
    elif data.dtype == np.int32:
        data = data.astype(float) / 2147483648.0
    elif data.dtype == np.uint8:
        data = (data.astype(float) - 128) / 128.0
    
    # Handle Stereo (Serum exports are often stereo, take left channel)
    if len(data.shape) > 1:
        data = data[:, 0]

    # Verify Length
    expected_len = SRC_SAMPLES * SRC_FRAMES
    if len(data) != expected_len:
        print(f"Warning: File length {len(data)} does not match standard Serum length {expected_len}.")
        print("Attempting to process anyway...")

    # 2. Reshape into Frames [256, 2048]
    # If the file is short, we trim/pad logic here would be needed, 
    # but assuming a valid Serum file:
    frames = data[:expected_len].reshape((SRC_FRAMES, SRC_SAMPLES))

    final_hex_values = []

    print("Processing Frames...")
    
    # 3. Loop through Target Frames (0 to 127)
    for i in range(TARGET_FRAMES):
        # We map Target Frame i to Source Frame i*2 (Skipping every other frame)
        src_idx = i * 2
        
        # Grab the frame
        raw_frame = frames[src_idx]
        
        # 4. Resample (Shrink 2048 -> 1024)
        # scipy.signal.resample uses FFT, which preserves the waveform loop perfectly
        new_frame = resample(raw_frame, TARGET_SAMPLES)
        
        # 5. Convert to 16-bit Hex
        for sample in new_frame:
            # Hard Clip to prevent overflow artifacts
            sample = max(-1.0, min(1.0, sample))
            
            # Scale to Integer
            int_val = int(sample * 32767)
            
            # 2's Complement Hex conversion
            if int_val < 0:
                int_val = (1 << 16) + int_val
            
            final_hex_values.append(f"{int_val:04X}")

    # 6. Write COE File
    print(f"Writing {OUTPUT_FILENAME}...")
    with open(OUTPUT_FILENAME, 'w') as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        
        total = len(final_hex_values)
        for idx, val in enumerate(final_hex_values):
            separator = ",\n" if idx < total - 1 else ";"
            f.write(val + separator)

    print("-" * 30)
    print(f"Done! Total Samples: {total}")
    print(f"Organization: {TARGET_FRAMES} Frames of {TARGET_SAMPLES} samples.")

if __name__ == "__main__":
    process_serum_table()
