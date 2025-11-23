"""Main simulator class for pim65."""

from pathlib import Path
from typing import Optional

from .config import SimulatorConfig
from .cpu import CPU, InvalidOpcodeError
from .memory import Memory


class Simulator:
    """6502 simulator coordinating memory and CPU."""

    def __init__(self, config: SimulatorConfig):
        self.config = config
        self.memory = Memory()
        self.cpu = CPU(self.memory)

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

    def run(
        self,
        max_instructions: int = 1000,
        trace: bool = False
    ) -> bool:
        """Run the simulation.

        Args:
            max_instructions: Maximum instructions to execute
            trace: Whether to enable instruction tracing

        Returns:
            True if simulation ended successfully (reached $FFF9)
        """
        self.cpu.trace_enabled = trace
        return self.cpu.run(max_instructions)

    def get_trace(self) -> list[str]:
        """Get the instruction trace log."""
        return self.cpu.trace_log

    def dump_memory(self, start: int, length: int) -> bytes:
        """Dump a region of memory."""
        return self.memory.dump(start, length)

    @property
    def instruction_count(self) -> int:
        """Get the number of instructions executed."""
        return self.cpu.instruction_count
