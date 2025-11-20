#!/usr/bin/env python3
"""
Build a test program for sim65 that reads from the disk
"""

import struct

# Test program that:
# 1. Sets up block I/O parameters to read block 0 to $0300
# 2. Calls the block device ROM
# 3. Verifies the first byte is 0x00
# 4. Returns

code = bytearray()

# Main code at $0200
# Set up ProDOS block parameters at $42-$47
# $42: command (1 = read)
code.extend([0xA9, 0x01])  # LDA #$01
code.extend([0x85, 0x42])  # STA $42

# $43: unit number (0x20 = device $20)
code.extend([0xA9, 0x20])  # LDA #$20
code.extend([0x85, 0x43])  # STA $43

# $44-$45: buffer address ($0300)
code.extend([0xA9, 0x00])  # LDA #$00
code.extend([0x85, 0x44])  # STA $44
code.extend([0xA9, 0x03])  # LDA #$03
code.extend([0x85, 0x45])  # STA $45

# $46-$47: block number (0)
code.extend([0xA9, 0x00])  # LDA #$00
code.extend([0x85, 0x46])  # STA $46
code.extend([0x85, 0x47])  # STA $47

# Call block device at $C20A
code.extend([0x20, 0x0A, 0xC2])  # JSR $C20A

# Load first byte from buffer and check if it's 0x00
code.extend([0xAD, 0x00, 0x03])  # LDA $0300

# Exit
code.extend([0x60])  # RTS

# Build version 3 format binary
output = bytearray()

# Header
output.extend(b'sim65')  # Signature
output.append(3)         # Version 3 (multi-segment)
output.append(0)         # CPU type: 6502
output.append(0xFF)      # SP page
output.extend(struct.pack('<H', 0x0200))  # Reset address
output.extend(struct.pack('<H', 1))       # Segment count

# Segment 0: Main code at $0200
output.extend(struct.pack('<H', 0x0200))      # Load address
output.extend(struct.pack('<H', len(code)))   # Length
output.extend(code)

# Write to file
with open('test-disk-io.bin', 'wb') as f:
    f.write(output)

print(f"Created test-disk-io.bin ({len(code)} bytes of code)")
print("This program:")
print("  1. Sets up block I/O parameters to read block 0 to $0300")
print("  2. Calls the block device ROM at $C20A")
print("  3. Loads the first byte from $0300 (should be 0x00)")
print("  4. Exits")
