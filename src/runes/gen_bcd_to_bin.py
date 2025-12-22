#!/usr/bin/env python3
"""Generate BCD to binary conversion table."""

print("; BCD to binary conversion table")
print("; Entry at index $XY (where X and Y are BCD digits) contains decimal value XY")
print()
print("bcd_to_bin:")
for i in range(256):
    high_digit = (i >> 4) & 0x0F
    low_digit = i & 0x0F

    # Only valid BCD values have digits 0-9
    if high_digit <= 9 and low_digit <= 9:
        decimal_value = high_digit * 10 + low_digit
        print(f"    .byte {decimal_value:3d} ; ${i:02X} -> {decimal_value}")
    else:
        # Invalid BCD - just put 0 or 255 as a marker
        print(f"    .byte 255 ; ${i:02X} (invalid BCD)")
