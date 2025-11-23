"""Tests for Apple II hardware emulation."""

import tempfile
from pathlib import Path

import pytest
from pim65.apple2 import HardDrive, Keyboard, TextScreen
from pim65.config import SimulatorConfig
from pim65.cpu import BrkAbortError
from pim65.memory import Memory
from pim65.simulator import Simulator


class TestTextScreen:
    """Tests for text screen emulation."""

    def test_line_addresses(self):
        """Test text screen line address calculation."""
        # Line 0 starts at $400
        assert TextScreen.line_address(0) == 0x400
        # Line 1 starts at $480
        assert TextScreen.line_address(1) == 0x480
        # Line 8 starts at $428
        assert TextScreen.line_address(8) == 0x428
        # Line 16 starts at $450
        assert TextScreen.line_address(16) == 0x450
        # Line 23 (last line) at $7D0
        assert TextScreen.line_address(23) == 0x7D0

    def test_dump_simple_text(self):
        """Test dumping simple text from screen memory."""
        mem = Memory()
        # Clear screen to spaces first
        for addr in range(0x400, 0x800):
            mem.write(addr, ord(' '))

        # Write "HELLO" on line 0
        base = TextScreen.line_address(0)
        for i, ch in enumerate("HELLO"):
            mem.write(base + i, ord(ch) | 0x80)  # Hi-bit ASCII

        screen = TextScreen.dump(mem)
        assert screen == "HELLO"

    def test_dump_multiple_lines(self):
        """Test dumping multiple lines."""
        mem = Memory()
        # Clear screen to spaces
        for addr in range(0x400, 0x800):
            mem.write(addr, ord(' '))

        # Write "LINE1" on line 0
        base = TextScreen.line_address(0)
        for i, ch in enumerate("LINE1"):
            mem.write(base + i, ord(ch) | 0x80)

        # Write "LINE2" on line 1
        base = TextScreen.line_address(1)
        for i, ch in enumerate("LINE2"):
            mem.write(base + i, ord(ch) | 0x80)

        screen = TextScreen.dump(mem)
        lines = screen.split('\n')
        assert lines[0] == "LINE1"
        assert lines[1] == "LINE2"

    def test_strip_trailing_whitespace(self):
        """Test that trailing whitespace is stripped."""
        mem = Memory()
        for addr in range(0x400, 0x800):
            mem.write(addr, ord(' '))

        base = TextScreen.line_address(0)
        for i, ch in enumerate("TEST  "):
            mem.write(base + i, ord(ch) | 0x80)

        screen = TextScreen.dump(mem)
        assert screen == "TEST"

    def test_trim_blank_lines(self):
        """Test that leading/trailing blank lines are trimmed."""
        mem = Memory()
        # Initialize with spaces
        for addr in range(0x400, 0x800):
            mem.write(addr, ord(' '))

        # Write text on line 5 only
        base = TextScreen.line_address(5)
        for i, ch in enumerate("MIDDLE"):
            mem.write(base + i, ord(ch) | 0x80)

        screen = TextScreen.dump(mem)
        assert screen == "MIDDLE"

    def test_nonprintable_as_space(self):
        """Test that non-printable chars become spaces."""
        mem = Memory()
        for addr in range(0x400, 0x800):
            mem.write(addr, ord(' '))

        base = TextScreen.line_address(0)
        mem.write(base, ord('A') | 0x80)
        mem.write(base + 1, 0x01)  # Non-printable
        mem.write(base + 2, ord('B') | 0x80)

        screen = TextScreen.dump(mem)
        assert screen == "A B"

    def test_ff_as_space(self):
        """Test that $FF is treated as space."""
        mem = Memory()
        # Memory is already initialized to $FF
        base = TextScreen.line_address(0)
        mem.write(base, ord('X') | 0x80)

        screen = TextScreen.dump(mem)
        assert screen == "X"


class TestKeyboard:
    """Tests for keyboard input simulation."""

    def test_simple_input(self):
        """Test reading simple keyboard input."""
        kbd = Keyboard(["ABC"])
        assert kbd.read_kbd() == ord('A') | 0x80
        kbd.clear_strobe()
        assert kbd.read_kbd() == ord('B') | 0x80
        kbd.clear_strobe()
        assert kbd.read_kbd() == ord('C') | 0x80
        kbd.clear_strobe()
        # No more input
        assert kbd.read_kbd() == 0x00

    def test_newline_to_cr(self):
        """Test that \\n maps to CR ($0D)."""
        kbd = Keyboard(["A\\nB"])
        assert kbd.read_kbd() == ord('A') | 0x80
        kbd.clear_strobe()
        assert kbd.read_kbd() == 0x0D | 0x80  # CR
        kbd.clear_strobe()
        assert kbd.read_kbd() == ord('B') | 0x80

    def test_hex_escape(self):
        """Test hex escapes like \\x1B."""
        kbd = Keyboard(["\\x1B"])
        assert kbd.read_kbd() == 0x1B | 0x80  # ESC

    def test_escape_shortcut(self):
        """Test \\e for escape."""
        kbd = Keyboard(["\\e"])
        assert kbd.read_kbd() == 0x1B | 0x80

    def test_backslash_escape(self):
        """Test \\\\ for literal backslash."""
        kbd = Keyboard(["\\\\"])
        assert kbd.read_kbd() == ord('\\') | 0x80

    def test_multiple_strings(self):
        """Test multiple input strings concatenated."""
        kbd = Keyboard(["AB", "CD"])
        assert kbd.read_kbd() == ord('A') | 0x80
        kbd.clear_strobe()
        assert kbd.read_kbd() == ord('B') | 0x80
        kbd.clear_strobe()
        assert kbd.read_kbd() == ord('C') | 0x80
        kbd.clear_strobe()
        assert kbd.read_kbd() == ord('D') | 0x80

    def test_has_input(self):
        """Test has_input property."""
        kbd = Keyboard(["A"])
        assert kbd.has_input
        kbd.clear_strobe()
        assert not kbd.has_input


class TestKeyboardIntegration:
    """Integration tests for keyboard with simulator."""

    def test_read_keyboard(self):
        """Test reading keyboard via LDA $C000."""
        # Program: LDA $C000, STA $10, JMP $FFF9
        code = bytes([
            0xAD, 0x00, 0xC0,  # LDA $C000
            0x85, 0x10,        # STA $10
            0x4C, 0xF9, 0xFF   # JMP $FFF9
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code, 0x1000)
        sim.memory.set_reset_vector(0x1000)
        sim.setup_keyboard(["X"])
        sim.cpu.reset()
        sim.run(max_instructions=100)

        assert sim.cpu.success
        # Should have read 'X' with hi-bit set
        assert sim.memory.read(0x10) == ord('X') | 0x80

    def test_keyboard_strobe(self):
        """Test keyboard strobe advances to next character."""
        # Program: LDA $C000, STA $10, LDA $C010, LDA $C000, STA $11, JMP $FFF9
        code = bytes([
            0xAD, 0x00, 0xC0,  # LDA $C000 (read 'A')
            0x85, 0x10,        # STA $10
            0xAD, 0x10, 0xC0,  # LDA $C010 (clear strobe)
            0xAD, 0x00, 0xC0,  # LDA $C000 (read 'B')
            0x85, 0x11,        # STA $11
            0x4C, 0xF9, 0xFF   # JMP $FFF9
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code, 0x1000)
        sim.memory.set_reset_vector(0x1000)
        sim.setup_keyboard(["AB"])
        sim.cpu.reset()
        sim.run(max_instructions=100)

        assert sim.cpu.success
        assert sim.memory.read(0x10) == ord('A') | 0x80
        assert sim.memory.read(0x11) == ord('B') | 0x80


class TestBrkAbort:
    """Tests for BRK 00 abort functionality."""

    def test_brk_abort_triggers(self):
        """Test that BRK 00 triggers abort."""
        code = bytes([
            0xA9, 0x42,  # LDA #$42
            0x00, 0x00   # BRK 00
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code, 0x1000)
        sim.memory.set_reset_vector(0x1000)
        sim.cpu.reset()

        with pytest.raises(BrkAbortError) as exc_info:
            sim.run(max_instructions=100, brk_abort=True)

        assert "A=$42" in str(exc_info.value)

    def test_brk_nonzero_continues(self):
        """Test that BRK with non-zero padding doesn't abort."""
        code = bytes([
            0xA9, 0x42,        # LDA #$42
            0x00, 0x01,        # BRK 01 (non-zero padding)
            0x4C, 0xF9, 0xFF   # JMP $FFF9 (at the IRQ handler)
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code, 0x1000)
        sim.memory.set_reset_vector(0x1000)
        # Set IRQ vector to point to JMP $FFF9
        sim.memory.write_word(0xFFFE, 0x1004)
        sim.cpu.reset()

        # Should not raise - continues via IRQ
        success = sim.run(max_instructions=100, brk_abort=True)
        assert success


class TestHardDrive:
    """Tests for hard drive emulation."""

    def create_test_disk(self, tmpdir: Path, num_blocks: int = 10) -> Path:
        """Create a test .2mg disk image."""
        disk_path = tmpdir / "test.2mg"

        # 2mg header (64 bytes)
        header = bytearray(64)
        header[0:4] = b'2IMG'  # Magic
        header[4:8] = b'RNIX'  # Creator
        header[8:10] = bytes([0x01, 0x00])  # Header size (little-endian)
        header[10:12] = bytes([0x01, 0x00])  # Version
        header[12:16] = bytes([0x01, 0x00, 0x00, 0x00])  # Image format (ProDOS)

        # Create disk with blocks
        with open(disk_path, 'wb') as f:
            f.write(header)
            for block_num in range(num_blocks):
                # Fill each block with its block number
                block = bytes([block_num & 0xFF] * 512)
                f.write(block)

        return disk_path

    def test_read_block(self):
        """Test reading a block from disk."""
        with tempfile.TemporaryDirectory() as tmpdir:
            disk_path = self.create_test_disk(Path(tmpdir))

            hd = HardDrive(disk_path)
            try:
                data = hd.read_block(0)
                assert len(data) == 512
                assert data[0] == 0x00  # Block 0 filled with 0x00

                data = hd.read_block(5)
                assert data[0] == 0x05  # Block 5 filled with 0x05
            finally:
                hd.close()

    def test_write_block(self):
        """Test writing a block to disk."""
        with tempfile.TemporaryDirectory() as tmpdir:
            disk_path = self.create_test_disk(Path(tmpdir))

            hd = HardDrive(disk_path)
            try:
                # Write test data
                test_data = bytes([0xAB] * 512)
                hd.write_block(3, test_data)

                # Read it back
                data = hd.read_block(3)
                assert data == test_data
            finally:
                hd.close()

    def test_rom_signature(self):
        """Test that ROM has correct ProDOS signature."""
        with tempfile.TemporaryDirectory() as tmpdir:
            disk_path = self.create_test_disk(Path(tmpdir))

            hd = HardDrive(disk_path)
            try:
                rom = hd.get_rom_bytes()
                assert rom[0x01] == 0x20  # Read block signature
                assert rom[0x03] == 0x00
                assert rom[0x05] == 0x03  # Block device
                assert rom[0xFF] == 0x0A  # Entry point offset
            finally:
                hd.close()


class TestHardDriveIntegration:
    """Integration tests for hard drive with simulator."""

    def create_test_disk(self, tmpdir: Path) -> Path:
        """Create a test disk with recognizable data."""
        disk_path = tmpdir / "test.2mg"

        header = bytearray(64)
        header[0:4] = b'2IMG'
        header[4:8] = b'RNIX'
        header[8:10] = bytes([0x01, 0x00])
        header[10:12] = bytes([0x01, 0x00])
        header[12:16] = bytes([0x01, 0x00, 0x00, 0x00])

        with open(disk_path, 'wb') as f:
            f.write(header)
            # Block 0: all $AA
            f.write(bytes([0xAA] * 512))
            # Block 1: all $BB
            f.write(bytes([0xBB] * 512))
            # Block 2: all $CC
            f.write(bytes([0xCC] * 512))

        return disk_path

    def test_block_read(self):
        """Test reading a block via ProDOS interface."""
        with tempfile.TemporaryDirectory() as tmpdir:
            disk_path = self.create_test_disk(Path(tmpdir))

            # Program to read block 1 to $2000
            code = bytes([
                # Set up ProDOS parameters
                0xA9, 0x01,        # LDA #$01 (read command)
                0x85, 0x42,        # STA $42
                0xA9, 0x20,        # LDA #$20 (unit $20)
                0x85, 0x43,        # STA $43
                0xA9, 0x00,        # LDA #$00 (buffer low)
                0x85, 0x44,        # STA $44
                0xA9, 0x20,        # LDA #$20 (buffer high = $2000)
                0x85, 0x45,        # STA $45
                0xA9, 0x01,        # LDA #$01 (block low)
                0x85, 0x46,        # STA $46
                0xA9, 0x00,        # LDA #$00 (block high)
                0x85, 0x47,        # STA $47
                # Call block device
                0x20, 0x0A, 0xC2,  # JSR $C20A
                # Check first byte
                0xAD, 0x00, 0x20,  # LDA $2000
                0x85, 0x10,        # STA $10
                0x4C, 0xF9, 0xFF   # JMP $FFF9
            ])

            config = SimulatorConfig(binaries=[], start_addr=0x1000)
            sim = Simulator(config)
            sim.memory.load_binary(code, 0x1000)
            sim.memory.set_reset_vector(0x1000)
            sim.setup_hard_drive(str(disk_path))
            sim.cpu.reset()
            sim.run(max_instructions=1000)

            assert sim.cpu.success
            # Block 1 contains $BB
            assert sim.memory.read(0x10) == 0xBB
            # Verify entire block was loaded
            assert sim.memory.read(0x2000) == 0xBB
            assert sim.memory.read(0x21FF) == 0xBB

            sim.cleanup()
