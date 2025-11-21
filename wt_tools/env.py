import math

# --- Configuration ---
STROBE_FREQ = 44100        # Frequency of your wr_strb (Hz)
ACC_BITS = 24              # Width of internal accumulator
MAX_VAL = 2**ACC_BITS - 1  # 16,777,215

def calc_regs(time_ms):
    """
    Converts a duration (ms) into (Rate, Rate_Scaling)
    based on a Full Scale transition (0 to Max).
    """
    if time_ms <= 0:
        return (255, 15) # Instant

    # 1. Calculate how many strobe ticks this duration takes
    total_ticks = (time_ms / 1000.0) * STROBE_FREQ
    
    if total_ticks < 1:
        total_ticks = 1

    # 2. Calculate the required increment per tick
    # Inc = Distance / Ticks
    required_inc = MAX_VAL / total_ticks

    # 3. Find the best Rate/Scaling pair
    # We want the smallest shift (Scaling) that allows Rate to fit in 8 bits.
    # This preserves the most precision.
    
    for shift in range(16):
        # Try this shift amount
        rate = required_inc / (2**shift)
        
        # Does it fit in 8 bits (0-255)?
        if rate < 256:
            # Valid!
            rate_int = int(round(rate))
            # Clamp to 1 to prevent 'forever' times if user entered huge number
            if rate_int == 0: rate_int = 1 
            return (rate_int, shift)

    # If we're here, it's too fast even for max shift (unlikely with these numbers)
    return (255, 15)

def main():
    print("-" * 40)
    print(" FPGA ADSR Parameter Calculator")
    print(f" System: {ACC_BITS}-bit Acc @ {STROBE_FREQ}Hz")
    print("-" * 40)

    # --- USER INPUTS ---
    try:
        a_ms = float(input("Attack Time (ms):  "))
        d_ms = float(input("Decay Time (ms):   "))
        s_pct = float(input("Sustain Level (%): "))
        r_ms = float(input("Release Time (ms): "))
    except ValueError:
        print("Invalid input.")
        return

    # --- CALCULATIONS ---
    
    # 1. Calculate Rates
    ar, ar_rs = calc_regs(a_ms)
    dr, dr_rs = calc_regs(d_ms)
    rr, rr_rs = calc_regs(r_ms)

    # 2. Calculate Sustain (16-bit)
    # Map 0-100% to 0-65535
    sl = int((s_pct / 100.0) * 65535)
    sl = max(0, min(65535, sl)) # Clamp

    # --- OUTPUT ---
    print("\n" + "=" * 40)
    print(" REGISTER VALUES (Decimal / Hex)")
    print("=" * 40)
    
    print(f"ATTACK  :: Rate: {ar:3} (0x{ar:02X}) | Shift: {ar_rs:2} (0x{ar_rs:X})")
    print(f"DECAY   :: Rate: {dr:3} (0x{dr:02X}) | Shift: {dr_rs:2} (0x{dr_rs:X})")
    print(f"SUSTAIN :: Level: {sl:5} (0x{sl:04X})")
    print(f"RELEASE :: Rate: {rr:3} (0x{rr:02X}) | Shift: {rr_rs:2} (0x{rr_rs:X})")
    print("=" * 40)

    # --- VERIFICATION ---
    # Calculate the *actual* time resulting from these integers to show error
    def reverse_calc(r, rs):
        inc = r * (2**rs)
        if inc == 0: return float('inf')
        ticks = MAX_VAL / inc
        return (ticks / STROBE_FREQ) * 1000.0

    print("\nActual Resulting Times:")
    print(f"Attack:  {reverse_calc(ar, ar_rs):.2f} ms")
    print(f"Decay:   {reverse_calc(dr, dr_rs):.2f} ms")
    print(f"Release: {reverse_calc(rr, rr_rs):.2f} ms")

if __name__ == "__main__":
    main()