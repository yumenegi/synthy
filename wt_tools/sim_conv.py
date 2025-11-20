import wave
import struct

# Setup
TXT_FILE = "audio_dump.txt"  # Make sure path is correct
WAV_FILE = "fpga_sweep.wav"
SAMPLE_RATE = 44100

print(f"Processing {TXT_FILE}...")

samples = []
try:
    with open(TXT_FILE, 'r') as f:
        for line in f:
            try:
                val = int(line.strip())
                # Hard Clip to 16-bit range to prevent overflow wrap-around noise
                val = max(-32768, min(32767, val))
                samples.append(val)
            except ValueError:
                pass
except FileNotFoundError:
    print("Error: Could not find audio_dump.txt. Did you run the simulation?")
    exit()

print(f"Writing {len(samples)} samples ({len(samples)/SAMPLE_RATE:.2f} sec) to {WAV_FILE}...")

with wave.open(WAV_FILE, 'w') as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2) # 16-bit
    wav.setframerate(SAMPLE_RATE)
    
    for s in samples:
        wav.writeframes(struct.pack('<h', s))

print("Done! Open the WAV file to hear your synth.")