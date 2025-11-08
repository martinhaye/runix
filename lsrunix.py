#!/usr/bin/env python3
"""
lsrunix.py - Display a tree-style listing of a Runix .2mg disk image

Reads a .2mg disk image and recursively displays its directory structure.
"""

import sys
import struct
from pathlib import Path

BLOCK_SIZE = 512
BLOCKS_PER_DIR = 4
ROOT_DIR_BLOCK = 1

def read_block(image, block_num):
    """Read a specific block from the image."""
    offset = block_num * BLOCK_SIZE
    return image[offset:offset + BLOCK_SIZE]

def parse_dir_entry(data, offset):
    """
    Parse a directory entry starting at offset.
    Returns: (name, start_block, length_pages, new_offset) or None if end of entries
    """
    if offset >= len(data):
        return None

    name_len = data[offset]
    if name_len == 0:  # End of directory entries
        return None

    offset += 1
    name = ''.join(chr(data[offset + i]) for i in range(name_len))
    offset += name_len

    start_block = struct.unpack('<H', data[offset:offset + 2])[0]
    offset += 2

    length_pages = data[offset]
    offset += 1

    return (name, start_block, length_pages, offset)

def read_directory(image, block_num):
    """
    Read a directory and return its entries.
    Returns: (parent_or_next_free, entries_list)
    """
    # Read all 4 blocks of the directory
    dir_data = bytearray()
    for i in range(BLOCKS_PER_DIR):
        dir_data.extend(read_block(image, block_num + i))

    # First 2 bytes: parent dir block (for subdirs) or next free block (for root)
    parent_or_next = struct.unpack('<H', dir_data[0:2])[0]

    # Parse entries
    entries = []
    offset = 2
    while True:
        result = parse_dir_entry(dir_data, offset)
        if result is None:
            break
        name, start_block, length_pages, offset = result
        is_dir = (length_pages == 0xF8)
        entries.append({
            'name': name,
            'start_block': start_block,
            'length_pages': length_pages,
            'is_dir': is_dir
        })

    return parent_or_next, entries

def format_size(pages):
    """Format file size from pages (256 bytes each)."""
    bytes_size = pages * 256
    if bytes_size < 1024:
        return f"{bytes_size}B"
    elif bytes_size < 1024 * 1024:
        return f"{bytes_size / 1024:.1f}K"
    else:
        return f"{bytes_size / (1024 * 1024):.1f}M"

def print_tree(image, block_num, prefix="", is_root=False, name="/"):
    """Recursively print directory tree."""
    parent_or_next, entries = read_directory(image, block_num)

    if is_root:
        print(name)
        print(f"  (Next free block: {parent_or_next})")

    for i, entry in enumerate(entries):
        is_last = (i == len(entries) - 1)
        connector = "└── " if is_last else "├── "

        if entry['is_dir']:
            print(f"{prefix}{connector}{entry['name']}/")
            # Recurse into subdirectory
            new_prefix = prefix + ("    " if is_last else "│   ")
            print_tree(image, entry['start_block'], new_prefix, is_root=False, name=entry['name'])
        else:
            size_str = format_size(entry['length_pages'])
            block_str = f"@{entry['start_block']}"
            print(f"{prefix}{connector}{entry['name']} ({size_str}, {block_str})")

def read_2mg(path):
    """Read a .2mg disk image and return the payload."""
    with open(path, 'rb') as f:
        # Read and verify header
        hdr = f.read(64)
        if hdr[0:4] != b'2IMG':
            raise ValueError("Not a valid .2mg file (missing magic)")

        # Read data offset and length
        data_offset = struct.unpack('<I', hdr[0x18:0x1C])[0]
        data_length = struct.unpack('<I', hdr[0x1C:0x20])[0]

        # Seek to data and read it
        f.seek(data_offset)
        return f.read(data_length)

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <disk.2mg>")
        print()
        print("Display a tree-style listing of a Runix filesystem.")
        sys.exit(1)

    disk_path = sys.argv[1]

    if not Path(disk_path).exists():
        print(f"Error: {disk_path} not found")
        sys.exit(1)

    try:
        image = read_2mg(disk_path)
        print_tree(image, ROOT_DIR_BLOCK, is_root=True, name=disk_path)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
