"""Memory management for the 6502 simulator."""

from typing import Callable, Optional


class Memory:
    """64KB memory space for 6502 simulation."""

    SIZE = 0x10000  # 64KB

    def __init__(self):
        """Initialize memory to all $FF."""
        self._mem = bytearray([0xFF] * self.SIZE)
        self._read_hooks: dict[int, Callable[[], int]] = {}
        self._write_hooks: dict[int, Callable[[int], None]] = {}

    def add_read_hook(self, addr: int, hook: Callable[[], int]) -> None:
        """Add a hook for reads from a specific address."""
        self._read_hooks[addr] = hook

    def add_write_hook(self, addr: int, hook: Callable[[int], None]) -> None:
        """Add a hook for writes to a specific address."""
        self._write_hooks[addr] = hook

    def read(self, addr: int) -> int:
        """Read a byte from memory."""
        addr = addr & 0xFFFF
        if addr in self._read_hooks:
            return self._read_hooks[addr]()
        return self._mem[addr]

    def write(self, addr: int, value: int) -> None:
        """Write a byte to memory."""
        addr = addr & 0xFFFF
        if addr in self._write_hooks:
            self._write_hooks[addr](value & 0xFF)
        else:
            self._mem[addr] = value & 0xFF

    def read_word(self, addr: int) -> int:
        """Read a 16-bit word (little-endian) from memory."""
        lo = self.read(addr)
        hi = self.read((addr + 1) & 0xFFFF)
        return lo | (hi << 8)

    def read_word_zp(self, addr: int) -> int:
        """Read a 16-bit word from zero page, wrapping at $FF."""
        lo = self.read(addr & 0xFF)
        hi = self.read((addr + 1) & 0xFF)
        return lo | (hi << 8)

    def write_word(self, addr: int, value: int) -> None:
        """Write a 16-bit word (little-endian) to memory."""
        self.write(addr, value & 0xFF)
        self.write((addr + 1) & 0xFFFF, (value >> 8) & 0xFF)

    def load_binary(self, data: bytes, start_addr: int) -> None:
        """Load binary data into memory at specified address."""
        for i, byte in enumerate(data):
            self.write(start_addr + i, byte)

    def set_reset_vector(self, addr: int) -> None:
        """Set the reset vector at $FFFC-$FFFD."""
        self.write_word(0xFFFC, addr)

    def dump(self, start: int, length: int) -> bytes:
        """Dump a region of memory."""
        return bytes(self._mem[start:start + length])
