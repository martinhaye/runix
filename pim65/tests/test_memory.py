"""Tests for memory module."""

import pytest
from pim65.memory import Memory


class TestMemory:
    """Tests for Memory class."""

    def test_initial_state(self):
        """Memory should be initialized to all $FF."""
        mem = Memory()
        assert mem.read(0x0000) == 0xFF
        assert mem.read(0x1234) == 0xFF
        assert mem.read(0xFFFF) == 0xFF

    def test_read_write_byte(self):
        """Test single byte read/write."""
        mem = Memory()
        mem.write(0x1000, 0x42)
        assert mem.read(0x1000) == 0x42

    def test_write_masks_to_byte(self):
        """Write should mask value to 8 bits."""
        mem = Memory()
        mem.write(0x1000, 0x1FF)
        assert mem.read(0x1000) == 0xFF

    def test_address_wraps(self):
        """Addresses should wrap at 64KB boundary."""
        mem = Memory()
        mem.write(0x10000, 0x42)  # Should wrap to 0x0000
        assert mem.read(0x0000) == 0x42

    def test_read_word(self):
        """Test 16-bit little-endian read."""
        mem = Memory()
        mem.write(0x1000, 0x34)  # Low byte
        mem.write(0x1001, 0x12)  # High byte
        assert mem.read_word(0x1000) == 0x1234

    def test_read_word_wraps(self):
        """read_word should wrap at 64KB boundary."""
        mem = Memory()
        mem.write(0xFFFF, 0x34)  # Low byte
        mem.write(0x0000, 0x12)  # High byte wraps
        assert mem.read_word(0xFFFF) == 0x1234

    def test_read_word_zp(self):
        """read_word_zp should wrap within zero page."""
        mem = Memory()
        mem.write(0xFF, 0x34)  # Low byte
        mem.write(0x00, 0x12)  # High byte wraps to $00
        assert mem.read_word_zp(0xFF) == 0x1234

    def test_write_word(self):
        """Test 16-bit little-endian write."""
        mem = Memory()
        mem.write_word(0x1000, 0x1234)
        assert mem.read(0x1000) == 0x34  # Low byte
        assert mem.read(0x1001) == 0x12  # High byte

    def test_load_binary(self):
        """Test loading binary data."""
        mem = Memory()
        data = bytes([0x01, 0x02, 0x03, 0x04])
        mem.load_binary(data, 0x1000)
        assert mem.read(0x1000) == 0x01
        assert mem.read(0x1001) == 0x02
        assert mem.read(0x1002) == 0x03
        assert mem.read(0x1003) == 0x04

    def test_set_reset_vector(self):
        """Test setting reset vector."""
        mem = Memory()
        mem.set_reset_vector(0x0800)
        assert mem.read_word(0xFFFC) == 0x0800

    def test_dump(self):
        """Test memory dump."""
        mem = Memory()
        mem.write(0x1000, 0x01)
        mem.write(0x1001, 0x02)
        mem.write(0x1002, 0x03)
        data = mem.dump(0x1000, 3)
        assert data == bytes([0x01, 0x02, 0x03])
