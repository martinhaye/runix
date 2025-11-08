#!/usr/bin/env python3
"""
Convert font text file to 6502 assembly source code.
Each character becomes 8 bytes, with pixels stored left-to-right as low-bit to high-bit.
"""

def parse_font_file(input_file):
    """Parse the font file and return a dict of character code -> 8 rows."""
    with open(input_file, 'r') as f:
        lines = f.readlines()

    font_data = {}  # Maps char_code (int) -> list of 8 row strings
    i = 0

    while i < len(lines):
        line = lines[i].rstrip('\n')

        # Check if this is a character header line (e.g., "0x41 'A'")
        if line.startswith('0x'):
            # Extract the character code
            parts = line.split()
            if len(parts) >= 1:
                hex_code = parts[0]
                char_code = int(hex_code, 16)

                # Read the 8 rows of the glyph
                i += 1
                glyph_rows = []
                for _ in range(8):
                    if i < len(lines):
                        row = lines[i].rstrip('\n')
                        if row == '':  # Skip blank lines between glyphs
                            break
                        glyph_rows.append(row)
                        i += 1

                # Pad to 8 rows if needed
                while len(glyph_rows) < 8:
                    glyph_rows.append('-------')

                font_data[char_code] = glyph_rows
        else:
            i += 1

    return font_data

def row_to_byte(row_str):
    """Convert a row string like 'X---X--' to a byte value.
    Pixels left-to-right are stored low-bit to high-bit.
    So 'X---X--' becomes 0b00010001 = 0x11
    """
    byte_val = 0
    for bit_pos, char in enumerate(row_str):
        if char == 'X':
            byte_val |= (1 << bit_pos)
    return byte_val

def generate_asm(font_data, output_file):
    """Generate assembly source code from font data."""
    with open(output_file, 'w') as f:
        f.write("; Base font data - 8 bytes per character\n")
        f.write("; Characters 0x20-0x7F (96 characters)\n")
        f.write("; Each character is 8 rows, pixels stored left-to-right as low-bit to high-bit\n")
        f.write("\n")
        f.write("base_font:\n")

        # Generate bytes for characters 0x20-0x7F
        for char_code in range(0x20, 0x80):
            if char_code in font_data:
                rows = font_data[char_code]

                # Generate comment with character
                if 0x20 <= char_code < 0x7F:
                    char_display = chr(char_code)
                    if char_display in ["'", "\\"]:
                        char_display = '\\' + char_display
                    f.write(f"    ; 0x{char_code:02X} '{char_display}'\n")
                else:
                    f.write(f"    ; 0x{char_code:02X} DEL\n")

                # Convert rows to bytes
                byte_values = [row_to_byte(row) for row in rows]

                # Write as .byte directive
                byte_str = ', '.join(f'${b:02X}' for b in byte_values)
                f.write(f"    .byte {byte_str}\n")
            else:
                # Missing character - fill with zeros
                f.write(f"    ; 0x{char_code:02X} (missing)\n")
                f.write(f"    .byte $00, $00, $00, $00, $00, $00, $00, $00\n")

    print(f"Assembly font generated: {output_file}")
    print(f"Total size: {96 * 8} bytes (96 characters × 8 bytes)")

if __name__ == '__main__':
    import sys

    input_file = 'src/runes/base_font.txt'
    output_file = 'src/runes/base_font.s'

    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    if len(sys.argv) > 2:
        output_file = sys.argv[2]

    font_data = parse_font_file(input_file)
    print(f"Parsed {len(font_data)} characters from {input_file}")
    generate_asm(font_data, output_file)
