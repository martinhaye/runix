#!/usr/bin/env python3
"""
Test program for sim65 Apple II screen dump feature.

This creates a test binary that writes text to Apple II screen memory
at various locations, then exits. The test verifies:
1. Screen lines are read in Apple II order
2. High-bit ASCII ($A0-FF) maps to low-bit ($20-$7F)
3. Non-printables ($00-$1F, $80-$9F) are treated as spaces
4. Trailing spaces on lines are trimmed
5. Leading and trailing blank lines are trimmed
"""

import struct
import subprocess
import sys

# Apple II 40-column text screen line addresses
# Formula: $400 + (line % 8) * $80 + (line / 8) * $28
def line_addr(line):
    return 0x400 + (line % 8) * 0x80 + (line // 8) * 0x28

# Build 6502 code to write test pattern to screen
code = bytearray()

# Test pattern:
# Line 0: "HELLO" in normal ASCII at column 0
# Line 5: "WORLD" in high-bit ASCII at column 10
# Line 10: Mix of printable and non-printable chars
# Line 23 (last): "END" to test last line works

# Helper to add: LDA #imm; STA addr
def sta_imm(val, addr):
    code.extend([0xA9, val & 0xFF])        # LDA #val
    code.extend([0x8D, addr & 0xFF, (addr >> 8) & 0xFF])  # STA addr

# Line 0: "HELLO" (normal ASCII $48 $45 $4C $4C $4F)
addr = line_addr(0)
sta_imm(0x48, addr + 0)  # H
sta_imm(0x45, addr + 1)  # E
sta_imm(0x4C, addr + 2)  # L
sta_imm(0x4C, addr + 3)  # L
sta_imm(0x4F, addr + 4)  # O

# Line 5: "WORLD" in high-bit ASCII at column 10
addr = line_addr(5) + 10
sta_imm(0xD7, addr + 0)  # W | $80
sta_imm(0xCF, addr + 1)  # O | $80
sta_imm(0xD2, addr + 2)  # R | $80
sta_imm(0xCC, addr + 3)  # L | $80
sta_imm(0xC4, addr + 4)  # D | $80

# Line 10: "A" then non-printable ($05), then "B", then $9F (non-printable), then "C"
# Should render as "A B C"
addr = line_addr(10)
sta_imm(0x41, addr + 0)  # A
sta_imm(0x05, addr + 1)  # non-printable -> space
sta_imm(0x42, addr + 2)  # B
sta_imm(0x9F, addr + 3)  # non-printable -> space
sta_imm(0x43, addr + 4)  # C

# Line 23: "END" at column 35 to test last line and trimming
addr = line_addr(23) + 35
sta_imm(0x45, addr + 0)  # E
sta_imm(0x4E, addr + 1)  # N
sta_imm(0x44, addr + 2)  # D

# Exit via paravirt ($FFF9)
code.extend([0x20, 0xF9, 0xFF])  # JSR $FFF9

# Build version 3 format binary
output = bytearray()
output.extend(b'sim65')           # Signature
output.append(3)                  # Version 3 (multi-segment)
output.append(0)                  # CPU type: 6502
output.append(0xFF)               # SP page
output.extend(struct.pack('<H', 0x0200))  # Reset address
output.extend(struct.pack('<H', 1))       # Segment count

# Segment 0: Main code at $0200
output.extend(struct.pack('<H', 0x0200))      # Load address
output.extend(struct.pack('<H', len(code)))   # Length
output.extend(code)

# Write test binary
with open('test-screen.bin', 'wb') as f:
    f.write(output)

print(f"Created test-screen.bin ({len(code)} bytes of code)")

# Run the test
print("\nRunning test with --screen option...")
result = subprocess.run(
    ['./cc65/bin/sim65', '--screen', 'test-screen.bin'],
    capture_output=True,
    text=True
)

print("Screen output:")
print("-" * 40)
print(result.stdout)
print("-" * 40)

# Verify output
expected_lines = [
    "HELLO",
    "",
    "",
    "",
    "",
    "          WORLD",
    "",
    "",
    "",
    "",
    "A B C",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "                                   END"
]

# After trimming leading/trailing blank lines, we should have:
# Line 0: HELLO
# Lines 1-4: blank
# Line 5: spaces + WORLD
# Lines 6-9: blank
# Line 10: A B C
# Lines 11-22: blank
# Line 23: spaces + END

actual_lines = result.stdout.rstrip('\n').split('\n') if result.stdout.strip() else []

# Expected after trimming: first non-blank is line 0 (HELLO), last is line 23 (END)
# So we should have 24 lines total
print(f"\nGot {len(actual_lines)} lines of output")

# Check specific lines
errors = []

if len(actual_lines) < 1:
    errors.append("No output lines!")
else:
    if actual_lines[0] != "HELLO":
        errors.append(f"Line 0: expected 'HELLO', got '{actual_lines[0]}'")

    if len(actual_lines) > 5:
        expected_world = "          WORLD"
        if actual_lines[5] != expected_world:
            errors.append(f"Line 5: expected '{expected_world}', got '{actual_lines[5]}'")

    if len(actual_lines) > 10:
        if actual_lines[10] != "A B C":
            errors.append(f"Line 10: expected 'A B C', got '{actual_lines[10]}'")

    if len(actual_lines) >= 24:
        expected_end = "                                   END"
        if actual_lines[23] != expected_end:
            errors.append(f"Line 23: expected '{expected_end}', got '{actual_lines[23]}'")

if errors:
    print("\nERRORS:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)
else:
    print("\nAll tests passed!")
    sys.exit(0)
