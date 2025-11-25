#!/usr/bin/env python3
"""
Create a boot stub that runs: cat hello.txt
This is used for testing the cat utility.
"""

import struct

def create_bootstub():
    """Create a simple program that runs cat hello.txt"""
    code = bytearray()

    # Program starts at $1000
    # JSR $0E00 (kernel startup)
    code.extend([0x20, 0x00, 0x0E])

    # Now we're in the shell prompt. We need to programmatically run:
    # "cat hello.txt"

    # Load pointer to "cat" string
    # LDA #<catstr
    code.extend([0xA9, 0x10])  # A = low byte of catstr (will be at $1010)
    # LDX #>catstr
    code.extend([0xA2, 0x10])  # X = high byte of catstr

    # Load pointer to argument string "hello.txt"
    # STA zarg (=$0E)
    code.extend([0x85, 0x0E])
    # LDA #<argstr
    code.extend([0xA9, 0x14])  # low byte of argstr (will be at $1014)
    # STA zarg (=$0E) - oops, need to do this differently
    code.extend([0x85, 0x0E])
    # LDA #>argstr
    code.extend([0xA9, 0x10])  # high byte
    # STA zarg+1 (=$0F)
    code.extend([0x85, 0x0F])

    # Load cat program name again
    # LDA #<catstr
    code.extend([0xA9, 0x10])
    # LDX #>catstr
    code.extend([0xA2, 0x10])

    # JSR progrun ($C12)
    code.extend([0x20, 0x12, 0x0C])

    # BRK (halt)
    code.extend([0x00])

    # catstr: .byte 3, "cat"
    code.extend([0x03, ord('c'), ord('a'), ord('t')])

    # argstr: .byte 9, "hello.txt"
    code.extend([0x09, ord('h'), ord('e'), ord('l'), ord('l'), ord('o'),
                 ord('.'), ord('t'), ord('x'), ord('t')])

    # Write to file
    with open('tests/bootstub_cat.bin', 'wb') as f:
        f.write(code)

    print(f"Created bootstub_cat.bin ({len(code)} bytes)")

if __name__ == '__main__':
    create_bootstub()
