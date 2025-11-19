#!/usr/bin/env python3
"""
Create a test .2mg disk image with some data for testing block I/O
"""

import struct

# Create a simple ProDOS-ordered .2mg image
# 280 blocks = 143360 bytes (143 KB, matches 5.25" floppy)

BLOCK_SIZE = 512
BLOCK_COUNT = 280
DISK_SIZE = BLOCK_SIZE * BLOCK_COUNT

# Build .2mg header (64 bytes)
header = bytearray(64)
header[0:4] = b'2IMG'              # Signature
header[4:8] = b'\x00\x00\x00\x00' # Creator
header[8:10] = struct.pack('<H', 64)  # Header length
header[10:12] = struct.pack('<H', 1)  # Version
header[12:16] = struct.pack('<I', 1)  # Image format (1 = ProDOS)
header[16:20] = struct.pack('<I', 0)  # Flags
header[20:24] = struct.pack('<I', BLOCK_COUNT)  # ProDOS blocks
header[24:28] = struct.pack('<I', 64)  # Data offset
header[28:32] = struct.pack('<I', DISK_SIZE)  # Data length
header[32:36] = struct.pack('<I', 0)  # Comment offset
header[36:40] = struct.pack('<I', 0)  # Comment length
header[40:44] = struct.pack('<I', 0)  # Creator data offset
header[44:48] = struct.pack('<I', 0)  # Creator data length
header[48:64] = b'\x00' * 16           # Reserved

# Create disk data
disk_data = bytearray(DISK_SIZE)

# Write test pattern to block 0
for i in range(BLOCK_SIZE):
    disk_data[i] = i & 0xFF

# Write different pattern to block 1
for i in range(BLOCK_SIZE):
    disk_data[BLOCK_SIZE + i] = (255 - i) & 0xFF

# Write another pattern to block 5
for i in range(BLOCK_SIZE):
    disk_data[5 * BLOCK_SIZE + i] = ((i * 7) & 0xFF)

# Write the .2mg file
with open('test-disk.2mg', 'wb') as f:
    f.write(header)
    f.write(disk_data)

print(f"Created test-disk.2mg ({BLOCK_COUNT} blocks, {DISK_SIZE} bytes)")
print(f"Block 0: pattern 0x00-0xFF")
print(f"Block 1: pattern 0xFF-0x00")
print(f"Block 5: pattern (i*7) & 0xFF")
