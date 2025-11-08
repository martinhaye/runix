#!/usr/bin/env python3
"""
mkrunix.py - Build a Runix .2mg disk image

Creates a 32MB ProDOS-ordered disk image with the Runix filesystem:
- Block 0: Boot block
- Blocks 1-4: Root directory
- Block 5+: Kernel, subdirectories (runes, bin, demos), and their contents
  - /runix (kernel)
  - /runes/ (subdirectory containing rune files)
  - /bin/ (subdirectory containing shell and utilities)
  - /demos/ (subdirectory containing demo programs)
"""

import sys
import struct
import os
from pathlib import Path

BLOCK_SIZE = 512
IMAGE_BLOCKS = 65535  # 32 MB = 65535 * 512 bytes
BLOCKS_PER_DIR = 4
ROOT_DIR_BLOCK = 1

def read_binary(path):
    """Read a binary file, return bytes."""
    with open(path, 'rb') as f:
        return f.read()

def write_block(image, block_num, data):
    """Write data to a specific block in the image."""
    offset = block_num * BLOCK_SIZE
    image[offset:offset + len(data)] = data

def create_dir_entry(name, start_block, length_pages):
    """
    Create a directory entry.
    Format: 1-byte name length, name bytes (ASCII), 2-byte start block, 1-byte length in pages
    """
    entry = bytearray()
    # Convert name to ASCII
    name_bytes = bytearray([ord(c) for c in name])
    entry.append(len(name_bytes))
    entry.extend(name_bytes)
    entry.extend(struct.pack('<H', start_block))  # start block (little-endian)
    entry.append(length_pages)  # length in pages (or 0xF8 for directory)
    return bytes(entry)

def pages_needed(data):
    """Calculate number of 256-byte pages needed for data."""
    return (len(data) + 255) // 256

def blocks_needed(data):
    """Calculate number of 512-byte blocks needed for data."""
    return (len(data) + BLOCK_SIZE - 1) // BLOCK_SIZE

def write_file_to_image(image, start_block, data):
    """Write file data to image starting at specified block."""
    offset = start_block * BLOCK_SIZE
    image[offset:offset + len(data)] = data
    return start_block + blocks_needed(data)

def build_filesystem(build_dir, output_path):
    """Build the complete Runix filesystem."""

    # Initialize empty image
    image = bytearray(IMAGE_BLOCKS * BLOCK_SIZE)

    # Track the next free block
    next_free_block = 5  # Start after root dir (blocks 1-4)

    # Root directory entries
    root_entries = []

    # Subdirectories we'll need
    subdirs = []

    # 1. Read and write boot block (block 0)
    boot_path = Path(build_dir) / 'boot.bin'
    boot_data = read_binary(boot_path)
    write_block(image, 0, boot_data[:BLOCK_SIZE])

    # 2. Add kernel to root directory
    kernel_path = Path(build_dir) / 'kernel.bin'
    if kernel_path.exists():
        kernel_data = read_binary(kernel_path)
        kernel_block = next_free_block
        next_free_block = write_file_to_image(image, kernel_block, kernel_data)
        root_entries.append(create_dir_entry('runix', kernel_block, pages_needed(kernel_data)))

    # 3. Reserve space for subdirectories (runes, bin, demos)
    runes_dir_block = next_free_block
    next_free_block += BLOCKS_PER_DIR
    root_entries.append(create_dir_entry('runes', runes_dir_block, 0xF8))  # 0xF8 = directory

    bin_dir_block = next_free_block
    next_free_block += BLOCKS_PER_DIR
    root_entries.append(create_dir_entry('bin', bin_dir_block, 0xF8))

    demos_dir_block = next_free_block
    next_free_block += BLOCKS_PER_DIR
    root_entries.append(create_dir_entry('demos', demos_dir_block, 0xF8))

    # 4. Build runes subdirectory entries
    runes_entries = []
    runes_dir = Path(build_dir) / 'runes'
    if runes_dir.exists():
        # Sort rune files by name (00-system.bin, 01-example.bin, etc.)
        rune_files = sorted(runes_dir.glob('*.bin'))
        for rune_file in rune_files:
            rune_data = read_binary(rune_file)
            rune_block = next_free_block
            next_free_block = write_file_to_image(image, rune_block, rune_data)
            # Use the basename without .bin extension
            rune_name = rune_file.stem
            runes_entries.append(create_dir_entry(rune_name, rune_block, pages_needed(rune_data)))

    # 5. Build bin subdirectory entries (including shell)
    bin_entries = []

    # Add shell to bin directory
    shell_path = Path(build_dir) / 'shell.bin'
    if shell_path.exists():
        shell_data = read_binary(shell_path)
        shell_block = next_free_block
        next_free_block = write_file_to_image(image, shell_block, shell_data)
        bin_entries.append(create_dir_entry('shell', shell_block, pages_needed(shell_data)))

    # Add bin utilities to bin directory
    bin_dir = Path(build_dir) / 'bin'
    if bin_dir.exists():
        bin_files = sorted(bin_dir.glob('*.bin'))
        for bin_file in bin_files:
            bin_data = read_binary(bin_file)
            bin_block = next_free_block
            next_free_block = write_file_to_image(image, bin_block, bin_data)
            bin_name = bin_file.stem
            bin_entries.append(create_dir_entry(bin_name, bin_block, pages_needed(bin_data)))

    # 6. Build demos subdirectory entries
    demos_entries = []
    demos_dir = Path(build_dir) / 'demos'
    if demos_dir.exists():
        demo_files = sorted(demos_dir.glob('*.bin'))
        for demo_file in demo_files:
            demo_data = read_binary(demo_file)
            demo_block = next_free_block
            next_free_block = write_file_to_image(image, demo_block, demo_data)
            demo_name = demo_file.stem
            demos_entries.append(create_dir_entry(demo_name, demo_block, pages_needed(demo_data)))

    # 7. Write root directory (blocks 1-4)
    root_dir = bytearray(BLOCKS_PER_DIR * BLOCK_SIZE)
    # First 2 bytes: next free block pointer
    root_dir[0:2] = struct.pack('<H', next_free_block)
    # Then the entries
    offset = 2
    for entry in root_entries:
        root_dir[offset:offset + len(entry)] = entry
        offset += len(entry)
    write_block(image, ROOT_DIR_BLOCK, root_dir[:BLOCKS_PER_DIR * BLOCK_SIZE])

    # 8. Write runes subdirectory
    runes_dir_data = bytearray(BLOCKS_PER_DIR * BLOCK_SIZE)
    # First 2 bytes: parent directory block (points to root)
    runes_dir_data[0:2] = struct.pack('<H', ROOT_DIR_BLOCK)
    # Then the entries
    offset = 2
    for entry in runes_entries:
        runes_dir_data[offset:offset + len(entry)] = entry
        offset += len(entry)
    write_block(image, runes_dir_block, runes_dir_data[:BLOCKS_PER_DIR * BLOCK_SIZE])

    # 9. Write bin subdirectory
    bin_dir_data = bytearray(BLOCKS_PER_DIR * BLOCK_SIZE)
    # First 2 bytes: parent directory block (points to root)
    bin_dir_data[0:2] = struct.pack('<H', ROOT_DIR_BLOCK)
    # Then the entries
    offset = 2
    for entry in bin_entries:
        bin_dir_data[offset:offset + len(entry)] = entry
        offset += len(entry)
    write_block(image, bin_dir_block, bin_dir_data[:BLOCKS_PER_DIR * BLOCK_SIZE])

    # 10. Write demos subdirectory
    demos_dir_data = bytearray(BLOCKS_PER_DIR * BLOCK_SIZE)
    # First 2 bytes: parent directory block (points to root)
    demos_dir_data[0:2] = struct.pack('<H', ROOT_DIR_BLOCK)
    # Then the entries
    offset = 2
    for entry in demos_entries:
        demos_dir_data[offset:offset + len(entry)] = entry
        offset += len(entry)
    write_block(image, demos_dir_block, demos_dir_data[:BLOCKS_PER_DIR * BLOCK_SIZE])

    # 11. Create .2mg header and write image
    write_2mg(image, output_path)

    print(f"Created {output_path}")
    print(f"  Total blocks: {IMAGE_BLOCKS}")
    print(f"  Next free block: {next_free_block}")
    print(f"  Root entries: {len(root_entries)}")
    print(f"  Rune entries: {len(runes_entries)}")
    print(f"  Bin entries: {len(bin_entries)}")
    print(f"  Demo entries: {len(demos_entries)}")

def write_2mg(payload, output_path):
    """Write a .2mg disk image with proper header."""
    hdr = bytearray(64)

    def put32(offset, value):
        hdr[offset:offset+4] = struct.pack('<I', value)

    def put16(offset, value):
        hdr[offset:offset+2] = struct.pack('<H', value)

    hdr[0:4] = b'2IMG'                          # magic
    hdr[4:8] = b'RNIX'                          # creator code
    put16(0x08, 64)                             # header length
    put16(0x0A, 1)                              # version
    put32(0x0C, 1)                              # image data format: 1 = ProDOS block order
    put32(0x10, 0)                              # flags (no write-protect)
    put32(0x14, IMAGE_BLOCKS)                   # number of 512-byte blocks
    put32(0x18, 64)                             # data offset
    put32(0x1C, len(payload))                   # data length in bytes
    put32(0x20, 0); put32(0x24, 0)              # comment (none)
    put32(0x28, 0); put32(0x2C, 0)              # creator data (none)

    with open(output_path, 'wb') as f:
        f.write(hdr)
        f.write(payload)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <build_dir> <output.2mg>")
        sys.exit(1)

    build_dir = sys.argv[1]
    output_path = sys.argv[2]

    build_filesystem(build_dir, output_path)
