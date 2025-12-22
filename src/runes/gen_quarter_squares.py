#!/usr/bin/env python3
"""Generate quarter-squares table for 6502 BCD multiplication."""

def dec_to_bcd(value):
    """Convert decimal value to two BCD bytes (low, high)."""
    # Convert to decimal string, pad to 4 digits
    dec_str = str(value).zfill(4)

    # Extract pairs of digits
    high = int(dec_str[0:2], 10)
    low = int(dec_str[2:4], 10)

    # Convert each pair to BCD
    high_bcd = ((high // 10) << 4) | (high % 10)
    low_bcd = ((low // 10) << 4) | (low % 10)

    return low_bcd, high_bcd

print("; Quarter-squares table for BCD multiplication")
print("; Entry n contains floor((n*n)/4) in BCD format")
print()
print("quarter_squares_low:")
for n in range(199):
    result = (n * n) // 4
    low_bcd, high_bcd = dec_to_bcd(result)
    print(f"    .byte ${low_bcd:02X} ; {n}*{n}/4 = {result}")

print()
print("quarter_squares_high:")
for n in range(199):
    result = (n * n) // 4
    low_bcd, high_bcd = dec_to_bcd(result)
    print(f"    .byte ${high_bcd:02X} ; {n}*{n}/4 = {result}")
