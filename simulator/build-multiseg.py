#!/usr/bin/env python3
"""
Build a sim65 version 3 (multi-segment) test binary
"""

import struct

# Segment data (hand-assembled for now)
# Segment 0: Main code at $0200
#   jsr $C200   (20 00 C2)
#   jsr $F800   (20 00 F8)
#   lda #$00    (A9 00)
#   rts         (60)
seg0_addr = 0x0200
seg0_data = bytes([0x20, 0x00, 0xC2, 0x20, 0x00, 0xF8, 0xA9, 0x00, 0x60])

# Segment 1: ROM at $C200
#   clc         (18)
#   adc #$01    (69 01)
#   rts         (60)
seg1_addr = 0xC200
seg1_data = bytes([0x18, 0x69, 0x01, 0x60])

# Segment 2: ROM at $F800
#   clc         (18)
#   adc #$02    (69 02)
#   rts         (60)
seg2_addr = 0xF800
seg2_data = bytes([0x18, 0x69, 0x02, 0x60])

segments = [
    (seg0_addr, seg0_data),
    (seg1_addr, seg1_data),
    (seg2_addr, seg2_data),
]

# Build the binary
output = bytearray()

# Header
output.extend(b'sim65')           # Signature (5 bytes)
output.append(3)                   # Version 3 (1 byte)
output.append(0)                   # CPU type: 6502 (1 byte)
output.append(0xFF)                # SP page (1 byte)
output.extend(struct.pack('<H', 0x0200))  # Reset address (2 bytes)
output.extend(struct.pack('<H', len(segments)))  # Segment count (2 bytes)

# Segments
for addr, data in segments:
    output.extend(struct.pack('<H', addr))      # Load address (2 bytes)
    output.extend(struct.pack('<H', len(data))) # Length (2 bytes)
    output.extend(data)                         # Data

# Write to file
with open('test-multi.bin', 'wb') as f:
    f.write(output)

print(f"Created test-multi.bin with {len(segments)} segments")
for i, (addr, data) in enumerate(segments):
    print(f"  Segment {i}: ${addr:04X}-${addr+len(data)-1:04X} ({len(data)} bytes)")
