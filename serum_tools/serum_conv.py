import numpy as np
from scipy.io import wavfile
from scipy.signal import resample
import glob
import os

# --- Configuration ---
TARGET_SAMPLES = 1024
BIT_DEPTH = 16
OUTPUT_COE = "wavetable_bank.coe"
OUTPUT_WAV_DIR = "converted_wavs"

def load_and_process_wav(filename):
    print(f"Processing {filename}...")
    
    # 1. Read WAV file
    try:
        sr, data = wavfile.read(filename)
    except ValueError:
        print(f"  Error: Could not read {filename}. Skipping.")
        return None

    # 2. Convert to Mono (if stereo)
    if len(data.shape) > 1:
        data = data.mean(axis=1)
    
    # 3. Normalize to Float (-1.0 to 1.0) for processing
    # Check original datatype to normalize correctly
    if data.dtype == np.int16:
        data = data.astype(float) / 32768.0
    elif data.dtype == np.int32:
        data = data.astype(float) / 2147483648.0
    elif data.dtype == np.uint8:
        data = (data.astype(float) - 128) / 128.0
    elif data.dtype == np.float32 or data.dtype == np.float64:
        pass # Already float
    
    # 4. Resample to TARGET_SAMPLES (1024)
    # scipy.signal.resample uses FFT, which is ideal for periodic wavetables
    resampled_data = resample(data, TARGET_SAMPLES)

    # 5. Re-Normalize (Maximize volume for FPGA dynamic range)
    max_val = np.max(np.abs(resampled_data))
    if max_val > 0:
        resampled_data = resampled_data / max_val

    return resampled_data

def save_debug_wav(data, original_filename):
    # Ensure directory exists
    if not os.path.exists(OUTPUT_WAV_DIR):
        os.makedirs(OUTPUT_WAV_DIR)
        
    # Convert back to int16 for WAV format
    wav_int16 = (data * 32767).astype(np.int16)
    
    out_name = os.path.join(OUTPUT_WAV_DIR, "1024_" + os.path.basename(original_filename))
    wavfile.write(out_name, 44100, wav_int16)

def main():
    # Find all .wav files in current directory
    wav_files = sorted(glob.glob("*.wav"))
    
    if not wav_files:
        print("No .wav files found in this directory!")
        return

    all_hex_values = []
    
    print(f"Found {len(wav_files)} wav files.")
    
    for fname in wav_files:
        # Process the audio data
        processed_data = load_and_process_wav(fname)
        
        if processed_data is None:
            continue

        # Save a copy as a 1024-sample WAV (so you can listen/verify)
        save_debug_wav(processed_data, fname)

        # Convert to FPGA Hex Format (16-bit 2's complement)
        for sample in processed_data:
            # Scale to integer range
            int_val = int(sample * 32767)
            
            # Clamp to ensure no overflow
            int_val = max(-32768, min(32767, int_val))
            
            # Convert to 2's Complement Hex
            if int_val < 0:
                int_val = (1 << 16) + int_val
            
            hex_str = f"{int_val:04X}"
            all_hex_values.append(hex_str)

    # Write the combined COE file
    with open(OUTPUT_COE, 'w') as f:
        f.write("memory_initialization_radix=16;\n")
        f.write("memory_initialization_vector=\n")
        
        for i, hex_val in enumerate(all_hex_values):
            separator = ",\n" if i < len(all_hex_values) - 1 else ";"
            f.write(hex_val + separator)

    print("-" * 30)
    print(f"Success! Processed {len(wav_files)} files.")
    print(f"1. Resized wavs saved in '{OUTPUT_WAV_DIR}/'")
    print(f"2. FPGA Coefficient file saved as '{OUTPUT_COE}'")
    print(f"Total samples in BRAM: {len(all_hex_values)}")

if __name__ == "__main__":
    main()