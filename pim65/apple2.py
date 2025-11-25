"""Apple II/III specific hardware emulation."""

import mmap
import os
from pathlib import Path
from typing import Optional


class TextScreen:
    """Apple II 40-column text screen emulation."""

    # Text screen memory: $400-$7FF
    SCREEN_BASE = 0x0400
    SCREEN_SIZE = 0x0400
    COLS = 40
    ROWS = 24

    @staticmethod
    def line_address(line: int) -> int:
        """Get the base address for a screen line (0-23)."""
        # Apple II text screen layout:
        # Lines 0,8,16: $400, $428, $450
        # Lines 1,9,17: $480, $4A8, $4D0
        # etc.
        group = line // 8      # 0, 1, or 2
        row_in_group = line % 8
        return 0x400 + row_in_group * 0x80 + group * 0x28

    @classmethod
    def dump(cls, memory) -> str:
        """Dump the 40-column text screen as a string."""
        lines = []
        for row in range(cls.ROWS):
            base = cls.line_address(row)
            chars = []
            for col in range(cls.COLS):
                byte = memory.read(base + col)
                # Map hi-bit ASCII to lo-bit
                char = byte & 0x7F
                # Treat non-printables and $FF as space
                if byte == 0xFF or char < 0x20 or char > 0x7E:
                    chars.append(' ')
                else:
                    chars.append(chr(char))
            # Strip trailing whitespace
            line = ''.join(chars).rstrip()
            lines.append(line)

        # Trim leading blank lines
        while lines and not lines[0]:
            lines.pop(0)

        # Trim trailing blank lines
        while lines and not lines[-1]:
            lines.pop()

        return '\n'.join(lines)


class Keyboard:
    """Apple II keyboard input simulation."""

    KBD_DATA = 0xC000    # Keyboard data (read)
    KBD_STROBE = 0xC010  # Keyboard strobe (read/write to clear)

    def __init__(self, input_strings: list[str]):
        """Initialize with list of input strings.

        Strings use C-style escapes, with \\n mapping to $0D.
        """
        self._buffer = self._parse_input(input_strings)
        self._index = 0

    @staticmethod
    def _parse_input(strings: list[str]) -> bytes:
        """Parse input strings with C-style escapes."""
        result = bytearray()
        for s in strings:
            i = 0
            while i < len(s):
                if s[i] == '\\' and i + 1 < len(s):
                    next_char = s[i + 1]
                    if next_char == 'n':
                        result.append(0x0D)  # Map \n to CR for Apple II
                        i += 2
                    elif next_char == 'r':
                        result.append(0x0D)
                        i += 2
                    elif next_char == 't':
                        result.append(0x09)
                        i += 2
                    elif next_char == '\\':
                        result.append(ord('\\'))
                        i += 2
                    elif next_char == 'x' and i + 3 < len(s):
                        # \xNN hex escape
                        try:
                            result.append(int(s[i+2:i+4], 16))
                            i += 4
                        except ValueError:
                            result.append(ord(s[i]))
                            i += 1
                    elif next_char == '0':
                        result.append(0x00)
                        i += 2
                    elif next_char == 'e':
                        result.append(0x1B)  # Escape
                        i += 2
                    else:
                        result.append(ord(s[i]))
                        i += 1
                else:
                    result.append(ord(s[i]))
                    i += 1
        return bytes(result)

    def read_kbd(self) -> int:
        """Read keyboard data ($C000).

        Returns character with hi-bit set if available,
        otherwise returns without hi-bit.
        """
        if self._index < len(self._buffer):
            return self._buffer[self._index] | 0x80
        return 0x00  # No hi-bit when no key available

    def clear_strobe(self) -> int:
        """Clear keyboard strobe ($C010) and advance to next char.

        Returns the value that was cleared.
        """
        result = self.read_kbd()
        if self._index < len(self._buffer):
            self._index += 1
        return result

    @property
    def has_input(self) -> bool:
        """Check if there's still input available."""
        return self._index < len(self._buffer)


class HardDrive:
    """Apple II ProDOS hard drive emulation (slot 2)."""

    BLOCK_SIZE = 512
    HEADER_SIZE = 64  # 2mg header size

    # ROM addresses for slot 2
    ROM_BASE = 0xC200
    ROM_SIZE = 0x100
    ENTRY_POINT = 0xC20A

    # ProDOS block device parameter locations
    PARAM_CMD = 0x42      # Command: 1=read, 2=write
    PARAM_UNIT = 0x43     # Unit number (should be $20 for slot 2)
    PARAM_BUF_LO = 0x44   # Buffer address low
    PARAM_BUF_HI = 0x45   # Buffer address high
    PARAM_BLK_LO = 0x46   # Block number low
    PARAM_BLK_HI = 0x47   # Block number high

    # Commands
    CMD_READ = 1
    CMD_WRITE = 2

    def __init__(self, image_path: str | Path):
        """Open a .2mg disk image."""
        self._path = Path(image_path)
        self._file = open(self._path, 'r+b')
        self._size = os.path.getsize(self._path)
        self._mmap = mmap.mmap(self._file.fileno(), 0)

    def close(self):
        """Close the disk image."""
        if self._mmap:
            self._mmap.close()
            self._mmap = None
        if self._file:
            self._file.close()
            self._file = None

    def __del__(self):
        self.close()

    def get_rom_bytes(self) -> bytes:
        """Get the slot 2 ROM content with proper signatures."""
        rom = bytearray(self.ROM_SIZE)

        # ProDOS block device signature
        # $Cn01 = $20 (read block)
        # $Cn03 = $00
        # $Cn05 = $03 (block device)
        # $Cn07 = $00 (SmartPort ID byte for older interface)
        rom[0x01] = 0x20
        rom[0x03] = 0x00
        rom[0x05] = 0x03
        rom[0x07] = 0x00

        # $CnFF = entry point offset (low byte of $Cn0A = $0A)
        rom[0xFF] = 0x0A

        # Put a simple RTS at the entry point
        # (actual handling is done by PC intercept in CPU)
        rom[0x0A] = 0x60  # RTS

        return bytes(rom)

    def read_block(self, block_num: int) -> bytes:
        """Read a 512-byte block from the disk image."""
        offset = self.HEADER_SIZE + block_num * self.BLOCK_SIZE
        if offset + self.BLOCK_SIZE > self._size:
            raise IOError(f"Block {block_num} out of range")
        return self._mmap[offset:offset + self.BLOCK_SIZE]

    def write_block(self, block_num: int, data: bytes) -> None:
        """Write a 512-byte block to the disk image."""
        if len(data) != self.BLOCK_SIZE:
            raise ValueError(f"Block must be {self.BLOCK_SIZE} bytes")
        offset = self.HEADER_SIZE + block_num * self.BLOCK_SIZE
        if offset + self.BLOCK_SIZE > self._size:
            raise IOError(f"Block {block_num} out of range")
        self._mmap[offset:offset + self.BLOCK_SIZE] = data
        self._mmap.flush()

    def handle_block_call(self, memory) -> tuple[int, bool]:
        """Handle a ProDOS block device call.

        Returns (A register value, carry flag).
        Raises IOError on failure.
        """
        cmd = memory.read(self.PARAM_CMD)
        unit = memory.read(self.PARAM_UNIT)
        buf_addr = memory.read(self.PARAM_BUF_LO) | (memory.read(self.PARAM_BUF_HI) << 8)
        block_num = memory.read(self.PARAM_BLK_LO) | (memory.read(self.PARAM_BLK_HI) << 8)

        if unit != 0x20:
            raise IOError(f"Invalid unit number: ${unit:02X} (expected $20)")

        if cmd == self.CMD_READ:
            data = self.read_block(block_num)
            for i, byte in enumerate(data):
                memory.write(buf_addr + i, byte)
            return 0, False  # A=0, carry clear

        elif cmd == self.CMD_WRITE:
            data = bytes(memory.read(buf_addr + i) for i in range(self.BLOCK_SIZE))
            self.write_block(block_num, data)
            return 0, False  # A=0, carry clear

        else:
            raise IOError(f"Invalid command: ${cmd:02X}")
