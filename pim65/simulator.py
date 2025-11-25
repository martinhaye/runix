"""Main simulator class for pim65."""

from pathlib import Path
from typing import Optional

from .apple2 import HardDrive, Keyboard, TextScreen
from .config import SimulatorConfig
from .cpu import CPU, InvalidOpcodeError
from .memory import Memory


class Simulator:
    """6502 simulator coordinating memory and CPU."""

    def __init__(self, config: SimulatorConfig):
        self.config = config
        self.memory = Memory()
        self.cpu = CPU(self.memory)

        # Apple II hardware (set up via setup_* methods)
        self._keyboard: Optional[Keyboard] = None
        self._hard_drive: Optional[HardDrive] = None

    def load(self) -> None:
        """Load all binaries into memory and set up reset vector."""
        # Load each binary file
        for binary in self.config.binaries:
            with open(binary.file, "rb") as f:
                data = f.read()
            self.memory.load_binary(data, binary.load_addr)

        # Set reset vector to start address
        self.memory.set_reset_vector(self.config.start_addr)

        # Reset CPU (will read reset vector)
        self.cpu.reset()

    def setup_keyboard(self, input_strings: list[str]) -> None:
        """Set up keyboard input simulation."""
        self._keyboard = Keyboard(input_strings)

        # Hook $C000 for keyboard read
        self.memory.add_read_hook(Keyboard.KBD_DATA, self._keyboard.read_kbd)

        # Hook $C010 for keyboard strobe (both read and write clear it)
        self.memory.add_read_hook(Keyboard.KBD_STROBE, self._keyboard.clear_strobe)
        self.memory.add_write_hook(Keyboard.KBD_STROBE, lambda _: self._keyboard.clear_strobe())

    def setup_hard_drive(self, image_path: str) -> None:
        """Set up hard drive emulation with a .2mg disk image."""
        self._hard_drive = HardDrive(image_path)

        # Load ROM bytes into slot 2 ROM space
        rom_bytes = self._hard_drive.get_rom_bytes()
        self.memory.load_binary(rom_bytes, HardDrive.ROM_BASE)

        # Hook PC at $C20A to intercept block calls
        self.cpu.add_pc_hook(HardDrive.ENTRY_POINT, self._handle_block_call)

    def _handle_block_call(self) -> None:
        """Handle a ProDOS block device call."""
        if self._hard_drive is None:
            raise RuntimeError("Hard drive not initialized")

        try:
            a_val, carry = self._hard_drive.handle_block_call(self.memory)
            self.cpu.a = a_val
            self.cpu.set_flag(CPU.FLAG_C, carry)
            # Execute RTS to return from the block call
            self.cpu.op_rts()
        except IOError as e:
            raise RuntimeError(f"Hard drive I/O error: {e}")

    def run(
        self,
        max_instructions: int = 1000,
        trace: bool = False,
        brk_abort: bool = False
    ) -> bool:
        """Run the simulation.

        Args:
            max_instructions: Maximum instructions to execute
            trace: Whether to enable instruction tracing
            brk_abort: Whether to abort on BRK 00

        Returns:
            True if simulation ended successfully (reached $FFF9)
        """
        self.cpu.trace_enabled = trace
        self.cpu.brk_abort = brk_abort
        return self.cpu.run(max_instructions)

    def get_trace(self) -> list[str]:
        """Get the instruction trace log."""
        return self.cpu.trace_log

    def dump_memory(self, start: int, length: int) -> bytes:
        """Dump a region of memory."""
        return self.memory.dump(start, length)

    def dump_screen(self) -> str:
        """Dump the 40-column text screen."""
        return TextScreen.dump(self.memory)

    @property
    def instruction_count(self) -> int:
        """Get the number of instructions executed."""
        return self.cpu.instruction_count

    def cleanup(self) -> None:
        """Clean up resources."""
        if self._hard_drive:
            self._hard_drive.close()
            self._hard_drive = None
