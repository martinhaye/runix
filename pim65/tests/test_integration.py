"""Integration tests for pim65 simulator."""

import json
import tempfile
from pathlib import Path

import pytest
from pim65.config import SimulatorConfig
from pim65.cpu import InvalidOpcodeError
from pim65.simulator import Simulator


class TestSimplePrograms:
    """Test small complete programs."""

    def run_program(self, code: bytes, start: int = 0x1000, max_inst: int = 100) -> Simulator:
        """Helper to run a program."""
        config = SimulatorConfig(
            binaries=[],
            start_addr=start
        )
        sim = Simulator(config)
        sim.memory.load_binary(code, start)
        sim.memory.set_reset_vector(start)
        sim.cpu.reset()
        sim.run(max_instructions=max_inst)
        return sim

    def test_simple_load_store(self):
        """Load a value, store it elsewhere, jump to success."""
        # LDA #$42, STA $10, JMP $FFF9
        code = bytes([
            0xA9, 0x42,        # LDA #$42
            0x85, 0x10,        # STA $10
            0x4C, 0xF9, 0xFF   # JMP $FFF9
        ])
        sim = self.run_program(code)
        assert sim.cpu.success
        assert sim.memory.read(0x10) == 0x42

    def test_counting_loop(self):
        """Count from 0 to 5 in a loop."""
        # LDA #$00
        # loop: CMP #$05, BEQ done, ADC #$01 (with C clear), JMP loop
        # done: STA $10, JMP $FFF9
        code = bytes([
            0xA9, 0x00,        # 1000: LDA #$00
            0x18,              # 1002: CLC
            0xC9, 0x05,        # 1003: CMP #$05
            0xF0, 0x05,        # 1005: BEQ +5 (to $100C)
            0x69, 0x01,        # 1007: ADC #$01
            0x4C, 0x02, 0x10,  # 1009: JMP $1002
            0x85, 0x10,        # 100C: STA $10
            0x4C, 0xF9, 0xFF   # 100E: JMP $FFF9
        ])
        sim = self.run_program(code)
        assert sim.cpu.success
        assert sim.memory.read(0x10) == 0x05

    def test_subroutine_call(self):
        """Test JSR/RTS."""
        # Main: LDA #$10, JSR sub, STA $20, JMP $FFF9
        # Sub:  ADC #$05, RTS
        code = bytes([
            0xA9, 0x10,        # 1000: LDA #$10
            0x18,              # 1002: CLC
            0x20, 0x0D, 0x10,  # 1003: JSR $100D
            0x85, 0x20,        # 1006: STA $20
            0x4C, 0xF9, 0xFF,  # 1008: JMP $FFF9
            0x00, 0x00,        # 100B: padding
            0x69, 0x05,        # 100D: ADC #$05
            0x60               # 100F: RTS
        ])
        sim = self.run_program(code)
        assert sim.cpu.success
        assert sim.memory.read(0x20) == 0x15

    def test_memory_copy(self):
        """Copy 4 bytes from one location to another."""
        # Source at $30-$33, dest at $40-$43
        code = bytes([
            # Store source data
            0xA9, 0x11, 0x85, 0x30,  # LDA #$11, STA $30
            0xA9, 0x22, 0x85, 0x31,  # LDA #$22, STA $31
            0xA9, 0x33, 0x85, 0x32,  # LDA #$33, STA $32
            0xA9, 0x44, 0x85, 0x33,  # LDA #$44, STA $33
            # Copy loop using X as counter
            0xA2, 0x00,              # LDX #$00
            # loop:
            0xB5, 0x30,              # LDA $30,X
            0x95, 0x40,              # STA $40,X
            0xE8,                    # INX
            0xE0, 0x04,              # CPX #$04
            0xD0, 0xF7,              # BNE loop (-9)
            0x4C, 0xF9, 0xFF         # JMP $FFF9
        ])
        sim = self.run_program(code)
        assert sim.cpu.success
        assert sim.memory.read(0x40) == 0x11
        assert sim.memory.read(0x41) == 0x22
        assert sim.memory.read(0x42) == 0x33
        assert sim.memory.read(0x43) == 0x44

    def test_fibonacci(self):
        """Calculate first 8 fibonacci numbers."""
        # Store fib(0)..fib(7) at $20-$27
        # fib: 0, 1, 1, 2, 3, 5, 8, 13
        code = bytes([
            0xA9, 0x00, 0x85, 0x20,  # fib[0] = 0
            0xA9, 0x01, 0x85, 0x21,  # fib[1] = 1
            0xA2, 0x02,              # X = 2 (start index)
            # loop:
            0x8A,                    # TXA
            0xA8,                    # TAY
            0x88,                    # DEY  (Y = X-1)
            0xB9, 0x20, 0x00,        # LDA $0020,Y (fib[n-1])
            0x88,                    # DEY  (Y = X-2)
            0x18,                    # CLC
            0x79, 0x20, 0x00,        # ADC $0020,Y (fib[n-2])
            0x9D, 0x20, 0x00,        # STA $0020,X (fib[n])
            0xE8,                    # INX
            0xE0, 0x08,              # CPX #$08
            0xD0, 0xED,              # BNE loop (-19 to $100A)
            0x4C, 0xF9, 0xFF         # JMP $FFF9
        ])
        sim = self.run_program(code)
        assert sim.cpu.success
        assert sim.memory.read(0x20) == 0   # fib(0)
        assert sim.memory.read(0x21) == 1   # fib(1)
        assert sim.memory.read(0x22) == 1   # fib(2)
        assert sim.memory.read(0x23) == 2   # fib(3)
        assert sim.memory.read(0x24) == 3   # fib(4)
        assert sim.memory.read(0x25) == 5   # fib(5)
        assert sim.memory.read(0x26) == 8   # fib(6)
        assert sim.memory.read(0x27) == 13  # fib(7)

    def test_indirect_indexed(self):
        """Test indirect indexed addressing for table lookup."""
        # Set up pointer at $10/$11 pointing to $2000
        # Store values at $2000-$2002
        # Read using (zp),Y
        code = bytes([
            # Set up pointer
            0xA9, 0x00, 0x85, 0x10,  # Store $00 at $10 (low)
            0xA9, 0x20, 0x85, 0x11,  # Store $20 at $11 (high)
            # Store test data at $2000
            0xA9, 0xAA, 0x8D, 0x00, 0x20,  # LDA #$AA, STA $2000
            0xA9, 0xBB, 0x8D, 0x01, 0x20,  # LDA #$BB, STA $2001
            0xA9, 0xCC, 0x8D, 0x02, 0x20,  # LDA #$CC, STA $2002
            # Read via ($10),Y
            0xA0, 0x01,              # LDY #$01
            0xB1, 0x10,              # LDA ($10),Y  -> should get $BB
            0x85, 0x30,              # STA $30
            0xA0, 0x02,              # LDY #$02
            0xB1, 0x10,              # LDA ($10),Y  -> should get $CC
            0x85, 0x31,              # STA $31
            0x4C, 0xF9, 0xFF         # JMP $FFF9
        ])
        sim = self.run_program(code)
        assert sim.cpu.success
        assert sim.memory.read(0x30) == 0xBB
        assert sim.memory.read(0x31) == 0xCC

    def test_brk_and_rti(self):
        """Test BRK triggering interrupt handler and RTI returning."""
        # Main code at $1000
        # IRQ handler at $2000
        code_main = bytes([
            0xA9, 0x42, 0x85, 0x10,  # LDA #$42, STA $10
            0x00,                    # BRK
            0xEA,                    # NOP (padding byte after BRK)
            0xA9, 0x99, 0x85, 0x12,  # LDA #$99, STA $12 (after RTI)
            0x4C, 0xF9, 0xFF         # JMP $FFF9
        ])
        code_irq = bytes([
            0xA9, 0x77, 0x85, 0x11,  # LDA #$77, STA $11
            0x40                     # RTI
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code_main, 0x1000)
        sim.memory.load_binary(code_irq, 0x2000)
        sim.memory.set_reset_vector(0x1000)
        sim.memory.write_word(0xFFFE, 0x2000)  # IRQ vector
        sim.cpu.reset()
        sim.run(max_instructions=100)

        assert sim.cpu.success
        assert sim.memory.read(0x10) == 0x42  # Before BRK
        assert sim.memory.read(0x11) == 0x77  # In IRQ handler
        assert sim.memory.read(0x12) == 0x99  # After RTI


class TestConfigFile:
    """Test configuration file handling."""

    def test_load_config(self):
        """Test loading config from JSON file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a test binary
            bin_path = Path(tmpdir) / "test.bin"
            bin_path.write_bytes(bytes([0xA9, 0x42, 0x4C, 0xF9, 0xFF]))

            # Create config
            config_path = Path(tmpdir) / "config.json"
            config_path.write_text(json.dumps({
                "binaries": [{"file": "test.bin", "load_addr": "0x1000"}],
                "start_addr": "0x1000"
            }))

            config = SimulatorConfig.from_file(config_path)
            assert config.start_addr == 0x1000
            assert len(config.binaries) == 1
            assert config.binaries[0].load_addr == 0x1000

    def test_hex_addr_formats(self):
        """Test various hex address formats."""
        with tempfile.TemporaryDirectory() as tmpdir:
            bin_path = Path(tmpdir) / "test.bin"
            bin_path.write_bytes(bytes([0xEA]))

            # Test $XXXX format
            config_path = Path(tmpdir) / "config.json"
            config_path.write_text(json.dumps({
                "binaries": [{"file": "test.bin", "load_addr": "$0800"}],
                "start_addr": "$0800"
            }))
            config = SimulatorConfig.from_file(config_path)
            assert config.start_addr == 0x0800

    def test_full_simulation_from_config(self):
        """Test running simulation from config file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create test binary: LDA #$42, STA $10, JMP $FFF9
            bin_path = Path(tmpdir) / "test.bin"
            bin_path.write_bytes(bytes([
                0xA9, 0x42,        # LDA #$42
                0x85, 0x10,        # STA $10
                0x4C, 0xF9, 0xFF   # JMP $FFF9
            ]))

            config_path = Path(tmpdir) / "config.json"
            config_path.write_text(json.dumps({
                "binaries": [{"file": "test.bin", "load_addr": "0x0800"}],
                "start_addr": "0x0800"
            }))

            config = SimulatorConfig.from_file(config_path)
            sim = Simulator(config)
            sim.load()
            success = sim.run(max_instructions=100)

            assert success
            assert sim.memory.read(0x10) == 0x42


class TestTracing:
    """Test instruction tracing."""

    def test_trace_output(self):
        """Test that tracing produces output."""
        code = bytes([
            0xA9, 0x42,        # LDA #$42
            0x85, 0x10,        # STA $10
            0x4C, 0xF9, 0xFF   # JMP $FFF9
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code, 0x1000)
        sim.memory.set_reset_vector(0x1000)
        sim.cpu.reset()
        sim.run(max_instructions=100, trace=True)

        trace = sim.get_trace()
        assert len(trace) == 3
        assert "LDA" in trace[0]
        assert "STA" in trace[1]
        assert "JMP" in trace[2]


class TestInstructionLimit:
    """Test instruction limit enforcement."""

    def test_limit_exceeded(self):
        """Test that exceeding instruction limit raises error."""
        # Infinite loop
        code = bytes([
            0x4C, 0x00, 0x10   # JMP $1000
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code, 0x1000)
        sim.memory.set_reset_vector(0x1000)
        sim.cpu.reset()

        with pytest.raises(RuntimeError, match="Instruction limit"):
            sim.run(max_instructions=10)


class TestInvalidOpcodes:
    """Test invalid opcode handling."""

    def test_invalid_opcode_error(self):
        """Test that invalid opcodes raise error."""
        code = bytes([
            0xA9, 0x42,  # LDA #$42
            0x02         # Invalid opcode
        ])

        config = SimulatorConfig(binaries=[], start_addr=0x1000)
        sim = Simulator(config)
        sim.memory.load_binary(code, 0x1000)
        sim.memory.set_reset_vector(0x1000)
        sim.cpu.reset()

        with pytest.raises(InvalidOpcodeError):
            sim.run(max_instructions=100)
