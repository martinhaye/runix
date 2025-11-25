"""6502 CPU emulation core."""

from typing import Callable, Optional
from .memory import Memory


class InvalidOpcodeError(Exception):
    """Raised when an invalid opcode is encountered."""
    pass


class BrkAbortError(Exception):
    """Raised when BRK 00 is encountered with brk_abort enabled."""
    pass


class CPU:
    """6502 CPU emulator (results-accurate, not cycle-accurate)."""

    # Status flag bits
    FLAG_C = 0x01  # Carry
    FLAG_Z = 0x02  # Zero
    FLAG_I = 0x04  # Interrupt disable
    FLAG_D = 0x08  # Decimal mode (not implemented)
    FLAG_B = 0x10  # Break
    FLAG_U = 0x20  # Unused (always 1)
    FLAG_V = 0x40  # Overflow
    FLAG_N = 0x80  # Negative

    # Special addresses
    STACK_BASE = 0x0100
    NMI_VECTOR = 0xFFFA
    RESET_VECTOR = 0xFFFC
    IRQ_VECTOR = 0xFFFE
    SUCCESS_ADDR = 0xFFF9

    def __init__(self, memory: Memory):
        self.memory = memory
        self.a = 0      # Accumulator
        self.x = 0      # X register
        self.y = 0      # Y register
        self.sp = 0xFD  # Stack pointer (after reset)
        self.pc = 0     # Program counter
        self.status = self.FLAG_U | self.FLAG_I  # Status register

        self.halted = False
        self.success = False
        self.instruction_count = 0
        self.trace_enabled = False
        self.trace_log: list[str] = []

        # Options
        self.brk_abort = False  # Abort on BRK 00

        # Hooks for Apple II hardware
        self.read_hooks: dict[int, Callable[[], int]] = {}
        self.write_hooks: dict[int, Callable[[int], None]] = {}
        self.pc_hooks: dict[int, Callable[[], None]] = {}

        self._build_opcode_table()

    def reset(self) -> None:
        """Reset the CPU to initial state."""
        self.a = 0
        self.x = 0
        self.y = 0
        self.sp = 0xFD
        self.pc = self.memory.read_word(self.RESET_VECTOR)
        self.status = self.FLAG_U | self.FLAG_I
        self.halted = False
        self.success = False
        self.instruction_count = 0
        self.trace_log = []

    # --- Flag operations ---

    def get_flag(self, flag: int) -> bool:
        return (self.status & flag) != 0

    def set_flag(self, flag: int, value: bool) -> None:
        if value:
            self.status |= flag
        else:
            self.status &= ~flag

    def update_nz(self, value: int) -> None:
        """Update N and Z flags based on value."""
        self.set_flag(self.FLAG_Z, (value & 0xFF) == 0)
        self.set_flag(self.FLAG_N, (value & 0x80) != 0)

    # --- Stack operations ---

    def push(self, value: int) -> None:
        self.memory.write(self.STACK_BASE + self.sp, value & 0xFF)
        self.sp = (self.sp - 1) & 0xFF

    def pull(self) -> int:
        self.sp = (self.sp + 1) & 0xFF
        return self.memory.read(self.STACK_BASE + self.sp)

    def push_word(self, value: int) -> None:
        self.push((value >> 8) & 0xFF)
        self.push(value & 0xFF)

    def pull_word(self) -> int:
        lo = self.pull()
        hi = self.pull()
        return lo | (hi << 8)

    # --- Addressing modes ---

    def addr_immediate(self) -> int:
        """Immediate: operand is the byte itself."""
        addr = self.pc
        self.pc = (self.pc + 1) & 0xFFFF
        return addr

    def addr_zero_page(self) -> int:
        """Zero page: operand is an address in page zero."""
        addr = self.memory.read(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        return addr

    def addr_zero_page_x(self) -> int:
        """Zero page,X: address in page zero + X (wraps in zero page)."""
        addr = (self.memory.read(self.pc) + self.x) & 0xFF
        self.pc = (self.pc + 1) & 0xFFFF
        return addr

    def addr_zero_page_y(self) -> int:
        """Zero page,Y: address in page zero + Y (wraps in zero page)."""
        addr = (self.memory.read(self.pc) + self.y) & 0xFF
        self.pc = (self.pc + 1) & 0xFFFF
        return addr

    def addr_absolute(self) -> int:
        """Absolute: full 16-bit address."""
        addr = self.memory.read_word(self.pc)
        self.pc = (self.pc + 2) & 0xFFFF
        return addr

    def addr_absolute_x(self) -> int:
        """Absolute,X: 16-bit address + X."""
        base = self.memory.read_word(self.pc)
        self.pc = (self.pc + 2) & 0xFFFF
        return (base + self.x) & 0xFFFF

    def addr_absolute_y(self) -> int:
        """Absolute,Y: 16-bit address + Y."""
        base = self.memory.read_word(self.pc)
        self.pc = (self.pc + 2) & 0xFFFF
        return (base + self.y) & 0xFFFF

    def addr_indirect(self) -> int:
        """Indirect: JMP (addr) - read address from memory."""
        ptr = self.memory.read_word(self.pc)
        self.pc = (self.pc + 2) & 0xFFFF
        # 6502 bug: wraps within page for indirect
        if (ptr & 0xFF) == 0xFF:
            lo = self.memory.read(ptr)
            hi = self.memory.read(ptr & 0xFF00)
            return lo | (hi << 8)
        return self.memory.read_word(ptr)

    def addr_indexed_indirect(self) -> int:
        """(Indirect,X): (zp + X) - read pointer from zero page."""
        zp = (self.memory.read(self.pc) + self.x) & 0xFF
        self.pc = (self.pc + 1) & 0xFFFF
        return self.memory.read_word_zp(zp)

    def addr_indirect_indexed(self) -> int:
        """(Indirect),Y: (zp) + Y - read pointer, then add Y."""
        zp = self.memory.read(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        base = self.memory.read_word_zp(zp)
        return (base + self.y) & 0xFFFF

    def addr_relative(self) -> int:
        """Relative: signed offset from PC (for branches)."""
        offset = self.memory.read(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF
        if offset & 0x80:
            offset -= 0x100
        return (self.pc + offset) & 0xFFFF

    # --- Instruction implementations ---

    def op_adc(self, addr: int) -> None:
        """Add with carry."""
        value = self.memory.read(addr)
        carry = 1 if self.get_flag(self.FLAG_C) else 0
        result = self.a + value + carry

        # Overflow: sign of result differs from both operands
        self.set_flag(self.FLAG_V,
                      ((self.a ^ result) & (value ^ result) & 0x80) != 0)
        self.set_flag(self.FLAG_C, result > 0xFF)
        self.a = result & 0xFF
        self.update_nz(self.a)

    def op_and(self, addr: int) -> None:
        """Logical AND."""
        self.a &= self.memory.read(addr)
        self.update_nz(self.a)

    def op_asl_acc(self) -> None:
        """Arithmetic shift left (accumulator)."""
        self.set_flag(self.FLAG_C, (self.a & 0x80) != 0)
        self.a = (self.a << 1) & 0xFF
        self.update_nz(self.a)

    def op_asl_mem(self, addr: int) -> None:
        """Arithmetic shift left (memory)."""
        value = self.memory.read(addr)
        self.set_flag(self.FLAG_C, (value & 0x80) != 0)
        value = (value << 1) & 0xFF
        self.memory.write(addr, value)
        self.update_nz(value)

    def op_branch(self, condition: bool) -> None:
        """Generic branch operation."""
        target = self.addr_relative()
        if condition:
            self.pc = target

    def op_bit(self, addr: int) -> None:
        """Bit test."""
        value = self.memory.read(addr)
        self.set_flag(self.FLAG_Z, (self.a & value) == 0)
        self.set_flag(self.FLAG_N, (value & 0x80) != 0)
        self.set_flag(self.FLAG_V, (value & 0x40) != 0)

    def op_brk(self) -> None:
        """Break - software interrupt."""
        # Check for BRK 00 abort
        if self.brk_abort and self.memory.read(self.pc) == 0x00:
            raise BrkAbortError(
                f"BRK 00 at ${(self.pc - 1) & 0xFFFF:04X}: "
                f"A=${self.a:02X} X=${self.x:02X} Y=${self.y:02X} "
                f"SP=${self.sp:02X} PC=${self.pc:04X}"
            )
        self.pc = (self.pc + 1) & 0xFFFF  # BRK skips next byte
        self.push_word(self.pc)
        self.push(self.status | self.FLAG_B | self.FLAG_U)
        self.set_flag(self.FLAG_I, True)
        self.pc = self.memory.read_word(self.IRQ_VECTOR)

    def op_cmp(self, addr: int, reg: int) -> None:
        """Compare register with memory."""
        value = self.memory.read(addr)
        result = reg - value
        self.set_flag(self.FLAG_C, reg >= value)
        self.update_nz(result & 0xFF)

    def op_dec_mem(self, addr: int) -> None:
        """Decrement memory."""
        value = (self.memory.read(addr) - 1) & 0xFF
        self.memory.write(addr, value)
        self.update_nz(value)

    def op_eor(self, addr: int) -> None:
        """Exclusive OR."""
        self.a ^= self.memory.read(addr)
        self.update_nz(self.a)

    def op_inc_mem(self, addr: int) -> None:
        """Increment memory."""
        value = (self.memory.read(addr) + 1) & 0xFF
        self.memory.write(addr, value)
        self.update_nz(value)

    def op_jmp(self, addr: int) -> None:
        """Jump to address."""
        self.pc = addr

    def op_jsr(self, addr: int) -> None:
        """Jump to subroutine."""
        self.push_word((self.pc - 1) & 0xFFFF)
        self.pc = addr

    def op_lda(self, addr: int) -> None:
        """Load accumulator."""
        self.a = self.memory.read(addr)
        self.update_nz(self.a)

    def op_ldx(self, addr: int) -> None:
        """Load X register."""
        self.x = self.memory.read(addr)
        self.update_nz(self.x)

    def op_ldy(self, addr: int) -> None:
        """Load Y register."""
        self.y = self.memory.read(addr)
        self.update_nz(self.y)

    def op_lsr_acc(self) -> None:
        """Logical shift right (accumulator)."""
        self.set_flag(self.FLAG_C, (self.a & 0x01) != 0)
        self.a = self.a >> 1
        self.update_nz(self.a)

    def op_lsr_mem(self, addr: int) -> None:
        """Logical shift right (memory)."""
        value = self.memory.read(addr)
        self.set_flag(self.FLAG_C, (value & 0x01) != 0)
        value = value >> 1
        self.memory.write(addr, value)
        self.update_nz(value)

    def op_ora(self, addr: int) -> None:
        """Logical OR."""
        self.a |= self.memory.read(addr)
        self.update_nz(self.a)

    def op_rol_acc(self) -> None:
        """Rotate left (accumulator)."""
        carry = 1 if self.get_flag(self.FLAG_C) else 0
        self.set_flag(self.FLAG_C, (self.a & 0x80) != 0)
        self.a = ((self.a << 1) | carry) & 0xFF
        self.update_nz(self.a)

    def op_rol_mem(self, addr: int) -> None:
        """Rotate left (memory)."""
        value = self.memory.read(addr)
        carry = 1 if self.get_flag(self.FLAG_C) else 0
        self.set_flag(self.FLAG_C, (value & 0x80) != 0)
        value = ((value << 1) | carry) & 0xFF
        self.memory.write(addr, value)
        self.update_nz(value)

    def op_ror_acc(self) -> None:
        """Rotate right (accumulator)."""
        carry = 0x80 if self.get_flag(self.FLAG_C) else 0
        self.set_flag(self.FLAG_C, (self.a & 0x01) != 0)
        self.a = (self.a >> 1) | carry
        self.update_nz(self.a)

    def op_ror_mem(self, addr: int) -> None:
        """Rotate right (memory)."""
        value = self.memory.read(addr)
        carry = 0x80 if self.get_flag(self.FLAG_C) else 0
        self.set_flag(self.FLAG_C, (value & 0x01) != 0)
        value = (value >> 1) | carry
        self.memory.write(addr, value)
        self.update_nz(value)

    def op_rti(self) -> None:
        """Return from interrupt."""
        self.status = (self.pull() | self.FLAG_U) & ~self.FLAG_B
        self.pc = self.pull_word()

    def op_rts(self) -> None:
        """Return from subroutine."""
        self.pc = (self.pull_word() + 1) & 0xFFFF

    def op_sbc(self, addr: int) -> None:
        """Subtract with carry (borrow)."""
        value = self.memory.read(addr)
        carry = 1 if self.get_flag(self.FLAG_C) else 0
        result = self.a - value - (1 - carry)

        # Overflow: sign of result differs when subtracting
        self.set_flag(self.FLAG_V,
                      ((self.a ^ result) & (~value ^ result) & 0x80) != 0)
        self.set_flag(self.FLAG_C, result >= 0)
        self.a = result & 0xFF
        self.update_nz(self.a)

    def op_sta(self, addr: int) -> None:
        """Store accumulator."""
        self.memory.write(addr, self.a)

    def op_stx(self, addr: int) -> None:
        """Store X register."""
        self.memory.write(addr, self.x)

    def op_sty(self, addr: int) -> None:
        """Store Y register."""
        self.memory.write(addr, self.y)

    # --- Opcode table ---

    def _build_opcode_table(self) -> None:
        """Build the opcode dispatch table."""
        # Initialize all as invalid
        self.opcodes: list[Optional[Callable[[], None]]] = [None] * 256

        # ADC
        self.opcodes[0x69] = lambda: self.op_adc(self.addr_immediate())
        self.opcodes[0x65] = lambda: self.op_adc(self.addr_zero_page())
        self.opcodes[0x75] = lambda: self.op_adc(self.addr_zero_page_x())
        self.opcodes[0x6D] = lambda: self.op_adc(self.addr_absolute())
        self.opcodes[0x7D] = lambda: self.op_adc(self.addr_absolute_x())
        self.opcodes[0x79] = lambda: self.op_adc(self.addr_absolute_y())
        self.opcodes[0x61] = lambda: self.op_adc(self.addr_indexed_indirect())
        self.opcodes[0x71] = lambda: self.op_adc(self.addr_indirect_indexed())

        # AND
        self.opcodes[0x29] = lambda: self.op_and(self.addr_immediate())
        self.opcodes[0x25] = lambda: self.op_and(self.addr_zero_page())
        self.opcodes[0x35] = lambda: self.op_and(self.addr_zero_page_x())
        self.opcodes[0x2D] = lambda: self.op_and(self.addr_absolute())
        self.opcodes[0x3D] = lambda: self.op_and(self.addr_absolute_x())
        self.opcodes[0x39] = lambda: self.op_and(self.addr_absolute_y())
        self.opcodes[0x21] = lambda: self.op_and(self.addr_indexed_indirect())
        self.opcodes[0x31] = lambda: self.op_and(self.addr_indirect_indexed())

        # ASL
        self.opcodes[0x0A] = lambda: self.op_asl_acc()
        self.opcodes[0x06] = lambda: self.op_asl_mem(self.addr_zero_page())
        self.opcodes[0x16] = lambda: self.op_asl_mem(self.addr_zero_page_x())
        self.opcodes[0x0E] = lambda: self.op_asl_mem(self.addr_absolute())
        self.opcodes[0x1E] = lambda: self.op_asl_mem(self.addr_absolute_x())

        # Branches
        self.opcodes[0x90] = lambda: self.op_branch(not self.get_flag(self.FLAG_C))  # BCC
        self.opcodes[0xB0] = lambda: self.op_branch(self.get_flag(self.FLAG_C))      # BCS
        self.opcodes[0xF0] = lambda: self.op_branch(self.get_flag(self.FLAG_Z))      # BEQ
        self.opcodes[0x30] = lambda: self.op_branch(self.get_flag(self.FLAG_N))      # BMI
        self.opcodes[0xD0] = lambda: self.op_branch(not self.get_flag(self.FLAG_Z))  # BNE
        self.opcodes[0x10] = lambda: self.op_branch(not self.get_flag(self.FLAG_N))  # BPL
        self.opcodes[0x50] = lambda: self.op_branch(not self.get_flag(self.FLAG_V))  # BVC
        self.opcodes[0x70] = lambda: self.op_branch(self.get_flag(self.FLAG_V))      # BVS

        # BIT
        self.opcodes[0x24] = lambda: self.op_bit(self.addr_zero_page())
        self.opcodes[0x2C] = lambda: self.op_bit(self.addr_absolute())

        # BRK
        self.opcodes[0x00] = lambda: self.op_brk()

        # Flag operations
        self.opcodes[0x18] = lambda: self.set_flag(self.FLAG_C, False)  # CLC
        self.opcodes[0xD8] = lambda: self.set_flag(self.FLAG_D, False)  # CLD
        self.opcodes[0x58] = lambda: self.set_flag(self.FLAG_I, False)  # CLI
        self.opcodes[0xB8] = lambda: self.set_flag(self.FLAG_V, False)  # CLV
        self.opcodes[0x38] = lambda: self.set_flag(self.FLAG_C, True)   # SEC
        self.opcodes[0xF8] = lambda: self.set_flag(self.FLAG_D, True)   # SED
        self.opcodes[0x78] = lambda: self.set_flag(self.FLAG_I, True)   # SEI

        # CMP
        self.opcodes[0xC9] = lambda: self.op_cmp(self.addr_immediate(), self.a)
        self.opcodes[0xC5] = lambda: self.op_cmp(self.addr_zero_page(), self.a)
        self.opcodes[0xD5] = lambda: self.op_cmp(self.addr_zero_page_x(), self.a)
        self.opcodes[0xCD] = lambda: self.op_cmp(self.addr_absolute(), self.a)
        self.opcodes[0xDD] = lambda: self.op_cmp(self.addr_absolute_x(), self.a)
        self.opcodes[0xD9] = lambda: self.op_cmp(self.addr_absolute_y(), self.a)
        self.opcodes[0xC1] = lambda: self.op_cmp(self.addr_indexed_indirect(), self.a)
        self.opcodes[0xD1] = lambda: self.op_cmp(self.addr_indirect_indexed(), self.a)

        # CPX
        self.opcodes[0xE0] = lambda: self.op_cmp(self.addr_immediate(), self.x)
        self.opcodes[0xE4] = lambda: self.op_cmp(self.addr_zero_page(), self.x)
        self.opcodes[0xEC] = lambda: self.op_cmp(self.addr_absolute(), self.x)

        # CPY
        self.opcodes[0xC0] = lambda: self.op_cmp(self.addr_immediate(), self.y)
        self.opcodes[0xC4] = lambda: self.op_cmp(self.addr_zero_page(), self.y)
        self.opcodes[0xCC] = lambda: self.op_cmp(self.addr_absolute(), self.y)

        # DEC
        self.opcodes[0xC6] = lambda: self.op_dec_mem(self.addr_zero_page())
        self.opcodes[0xD6] = lambda: self.op_dec_mem(self.addr_zero_page_x())
        self.opcodes[0xCE] = lambda: self.op_dec_mem(self.addr_absolute())
        self.opcodes[0xDE] = lambda: self.op_dec_mem(self.addr_absolute_x())

        # DEX, DEY
        self.opcodes[0xCA] = lambda: (setattr(self, 'x', (self.x - 1) & 0xFF), self.update_nz(self.x))
        self.opcodes[0x88] = lambda: (setattr(self, 'y', (self.y - 1) & 0xFF), self.update_nz(self.y))

        # EOR
        self.opcodes[0x49] = lambda: self.op_eor(self.addr_immediate())
        self.opcodes[0x45] = lambda: self.op_eor(self.addr_zero_page())
        self.opcodes[0x55] = lambda: self.op_eor(self.addr_zero_page_x())
        self.opcodes[0x4D] = lambda: self.op_eor(self.addr_absolute())
        self.opcodes[0x5D] = lambda: self.op_eor(self.addr_absolute_x())
        self.opcodes[0x59] = lambda: self.op_eor(self.addr_absolute_y())
        self.opcodes[0x41] = lambda: self.op_eor(self.addr_indexed_indirect())
        self.opcodes[0x51] = lambda: self.op_eor(self.addr_indirect_indexed())

        # INC
        self.opcodes[0xE6] = lambda: self.op_inc_mem(self.addr_zero_page())
        self.opcodes[0xF6] = lambda: self.op_inc_mem(self.addr_zero_page_x())
        self.opcodes[0xEE] = lambda: self.op_inc_mem(self.addr_absolute())
        self.opcodes[0xFE] = lambda: self.op_inc_mem(self.addr_absolute_x())

        # INX, INY
        self.opcodes[0xE8] = lambda: (setattr(self, 'x', (self.x + 1) & 0xFF), self.update_nz(self.x))
        self.opcodes[0xC8] = lambda: (setattr(self, 'y', (self.y + 1) & 0xFF), self.update_nz(self.y))

        # JMP
        self.opcodes[0x4C] = lambda: self.op_jmp(self.addr_absolute())
        self.opcodes[0x6C] = lambda: self.op_jmp(self.addr_indirect())

        # JSR
        self.opcodes[0x20] = lambda: self.op_jsr(self.addr_absolute())

        # LDA
        self.opcodes[0xA9] = lambda: self.op_lda(self.addr_immediate())
        self.opcodes[0xA5] = lambda: self.op_lda(self.addr_zero_page())
        self.opcodes[0xB5] = lambda: self.op_lda(self.addr_zero_page_x())
        self.opcodes[0xAD] = lambda: self.op_lda(self.addr_absolute())
        self.opcodes[0xBD] = lambda: self.op_lda(self.addr_absolute_x())
        self.opcodes[0xB9] = lambda: self.op_lda(self.addr_absolute_y())
        self.opcodes[0xA1] = lambda: self.op_lda(self.addr_indexed_indirect())
        self.opcodes[0xB1] = lambda: self.op_lda(self.addr_indirect_indexed())

        # LDX
        self.opcodes[0xA2] = lambda: self.op_ldx(self.addr_immediate())
        self.opcodes[0xA6] = lambda: self.op_ldx(self.addr_zero_page())
        self.opcodes[0xB6] = lambda: self.op_ldx(self.addr_zero_page_y())
        self.opcodes[0xAE] = lambda: self.op_ldx(self.addr_absolute())
        self.opcodes[0xBE] = lambda: self.op_ldx(self.addr_absolute_y())

        # LDY
        self.opcodes[0xA0] = lambda: self.op_ldy(self.addr_immediate())
        self.opcodes[0xA4] = lambda: self.op_ldy(self.addr_zero_page())
        self.opcodes[0xB4] = lambda: self.op_ldy(self.addr_zero_page_x())
        self.opcodes[0xAC] = lambda: self.op_ldy(self.addr_absolute())
        self.opcodes[0xBC] = lambda: self.op_ldy(self.addr_absolute_x())

        # LSR
        self.opcodes[0x4A] = lambda: self.op_lsr_acc()
        self.opcodes[0x46] = lambda: self.op_lsr_mem(self.addr_zero_page())
        self.opcodes[0x56] = lambda: self.op_lsr_mem(self.addr_zero_page_x())
        self.opcodes[0x4E] = lambda: self.op_lsr_mem(self.addr_absolute())
        self.opcodes[0x5E] = lambda: self.op_lsr_mem(self.addr_absolute_x())

        # NOP
        self.opcodes[0xEA] = lambda: None

        # ORA
        self.opcodes[0x09] = lambda: self.op_ora(self.addr_immediate())
        self.opcodes[0x05] = lambda: self.op_ora(self.addr_zero_page())
        self.opcodes[0x15] = lambda: self.op_ora(self.addr_zero_page_x())
        self.opcodes[0x0D] = lambda: self.op_ora(self.addr_absolute())
        self.opcodes[0x1D] = lambda: self.op_ora(self.addr_absolute_x())
        self.opcodes[0x19] = lambda: self.op_ora(self.addr_absolute_y())
        self.opcodes[0x01] = lambda: self.op_ora(self.addr_indexed_indirect())
        self.opcodes[0x11] = lambda: self.op_ora(self.addr_indirect_indexed())

        # Stack operations
        self.opcodes[0x48] = lambda: self.push(self.a)                                    # PHA
        self.opcodes[0x08] = lambda: self.push(self.status | self.FLAG_B | self.FLAG_U)   # PHP
        self.opcodes[0x68] = lambda: (setattr(self, 'a', self.pull()), self.update_nz(self.a))  # PLA
        self.opcodes[0x28] = lambda: setattr(self, 'status', (self.pull() | self.FLAG_U) & ~self.FLAG_B)  # PLP

        # ROL
        self.opcodes[0x2A] = lambda: self.op_rol_acc()
        self.opcodes[0x26] = lambda: self.op_rol_mem(self.addr_zero_page())
        self.opcodes[0x36] = lambda: self.op_rol_mem(self.addr_zero_page_x())
        self.opcodes[0x2E] = lambda: self.op_rol_mem(self.addr_absolute())
        self.opcodes[0x3E] = lambda: self.op_rol_mem(self.addr_absolute_x())

        # ROR
        self.opcodes[0x6A] = lambda: self.op_ror_acc()
        self.opcodes[0x66] = lambda: self.op_ror_mem(self.addr_zero_page())
        self.opcodes[0x76] = lambda: self.op_ror_mem(self.addr_zero_page_x())
        self.opcodes[0x6E] = lambda: self.op_ror_mem(self.addr_absolute())
        self.opcodes[0x7E] = lambda: self.op_ror_mem(self.addr_absolute_x())

        # RTI, RTS
        self.opcodes[0x40] = lambda: self.op_rti()
        self.opcodes[0x60] = lambda: self.op_rts()

        # SBC
        self.opcodes[0xE9] = lambda: self.op_sbc(self.addr_immediate())
        self.opcodes[0xE5] = lambda: self.op_sbc(self.addr_zero_page())
        self.opcodes[0xF5] = lambda: self.op_sbc(self.addr_zero_page_x())
        self.opcodes[0xED] = lambda: self.op_sbc(self.addr_absolute())
        self.opcodes[0xFD] = lambda: self.op_sbc(self.addr_absolute_x())
        self.opcodes[0xF9] = lambda: self.op_sbc(self.addr_absolute_y())
        self.opcodes[0xE1] = lambda: self.op_sbc(self.addr_indexed_indirect())
        self.opcodes[0xF1] = lambda: self.op_sbc(self.addr_indirect_indexed())

        # STA
        self.opcodes[0x85] = lambda: self.op_sta(self.addr_zero_page())
        self.opcodes[0x95] = lambda: self.op_sta(self.addr_zero_page_x())
        self.opcodes[0x8D] = lambda: self.op_sta(self.addr_absolute())
        self.opcodes[0x9D] = lambda: self.op_sta(self.addr_absolute_x())
        self.opcodes[0x99] = lambda: self.op_sta(self.addr_absolute_y())
        self.opcodes[0x81] = lambda: self.op_sta(self.addr_indexed_indirect())
        self.opcodes[0x91] = lambda: self.op_sta(self.addr_indirect_indexed())

        # STX
        self.opcodes[0x86] = lambda: self.op_stx(self.addr_zero_page())
        self.opcodes[0x96] = lambda: self.op_stx(self.addr_zero_page_y())
        self.opcodes[0x8E] = lambda: self.op_stx(self.addr_absolute())

        # STY
        self.opcodes[0x84] = lambda: self.op_sty(self.addr_zero_page())
        self.opcodes[0x94] = lambda: self.op_sty(self.addr_zero_page_x())
        self.opcodes[0x8C] = lambda: self.op_sty(self.addr_absolute())

        # Transfers
        self.opcodes[0xAA] = lambda: (setattr(self, 'x', self.a), self.update_nz(self.x))      # TAX
        self.opcodes[0xA8] = lambda: (setattr(self, 'y', self.a), self.update_nz(self.y))      # TAY
        self.opcodes[0xBA] = lambda: (setattr(self, 'x', self.sp), self.update_nz(self.x))     # TSX
        self.opcodes[0x8A] = lambda: (setattr(self, 'a', self.x), self.update_nz(self.a))      # TXA
        self.opcodes[0x9A] = lambda: setattr(self, 'sp', self.x)                               # TXS
        self.opcodes[0x98] = lambda: (setattr(self, 'a', self.y), self.update_nz(self.a))      # TYA

    # --- Disassembly for tracing ---

    OPCODE_NAMES = {
        0x69: ("ADC", "#"), 0x65: ("ADC", "zp"), 0x75: ("ADC", "zp,x"),
        0x6D: ("ADC", "abs"), 0x7D: ("ADC", "abs,x"), 0x79: ("ADC", "abs,y"),
        0x61: ("ADC", "(zp,x)"), 0x71: ("ADC", "(zp),y"),
        0x29: ("AND", "#"), 0x25: ("AND", "zp"), 0x35: ("AND", "zp,x"),
        0x2D: ("AND", "abs"), 0x3D: ("AND", "abs,x"), 0x39: ("AND", "abs,y"),
        0x21: ("AND", "(zp,x)"), 0x31: ("AND", "(zp),y"),
        0x0A: ("ASL", "A"), 0x06: ("ASL", "zp"), 0x16: ("ASL", "zp,x"),
        0x0E: ("ASL", "abs"), 0x1E: ("ASL", "abs,x"),
        0x90: ("BCC", "rel"), 0xB0: ("BCS", "rel"), 0xF0: ("BEQ", "rel"),
        0x30: ("BMI", "rel"), 0xD0: ("BNE", "rel"), 0x10: ("BPL", "rel"),
        0x50: ("BVC", "rel"), 0x70: ("BVS", "rel"),
        0x24: ("BIT", "zp"), 0x2C: ("BIT", "abs"),
        0x00: ("BRK", ""), 0x18: ("CLC", ""), 0xD8: ("CLD", ""),
        0x58: ("CLI", ""), 0xB8: ("CLV", ""),
        0xC9: ("CMP", "#"), 0xC5: ("CMP", "zp"), 0xD5: ("CMP", "zp,x"),
        0xCD: ("CMP", "abs"), 0xDD: ("CMP", "abs,x"), 0xD9: ("CMP", "abs,y"),
        0xC1: ("CMP", "(zp,x)"), 0xD1: ("CMP", "(zp),y"),
        0xE0: ("CPX", "#"), 0xE4: ("CPX", "zp"), 0xEC: ("CPX", "abs"),
        0xC0: ("CPY", "#"), 0xC4: ("CPY", "zp"), 0xCC: ("CPY", "abs"),
        0xC6: ("DEC", "zp"), 0xD6: ("DEC", "zp,x"),
        0xCE: ("DEC", "abs"), 0xDE: ("DEC", "abs,x"),
        0xCA: ("DEX", ""), 0x88: ("DEY", ""),
        0x49: ("EOR", "#"), 0x45: ("EOR", "zp"), 0x55: ("EOR", "zp,x"),
        0x4D: ("EOR", "abs"), 0x5D: ("EOR", "abs,x"), 0x59: ("EOR", "abs,y"),
        0x41: ("EOR", "(zp,x)"), 0x51: ("EOR", "(zp),y"),
        0xE6: ("INC", "zp"), 0xF6: ("INC", "zp,x"),
        0xEE: ("INC", "abs"), 0xFE: ("INC", "abs,x"),
        0xE8: ("INX", ""), 0xC8: ("INY", ""),
        0x4C: ("JMP", "abs"), 0x6C: ("JMP", "(abs)"),
        0x20: ("JSR", "abs"),
        0xA9: ("LDA", "#"), 0xA5: ("LDA", "zp"), 0xB5: ("LDA", "zp,x"),
        0xAD: ("LDA", "abs"), 0xBD: ("LDA", "abs,x"), 0xB9: ("LDA", "abs,y"),
        0xA1: ("LDA", "(zp,x)"), 0xB1: ("LDA", "(zp),y"),
        0xA2: ("LDX", "#"), 0xA6: ("LDX", "zp"), 0xB6: ("LDX", "zp,y"),
        0xAE: ("LDX", "abs"), 0xBE: ("LDX", "abs,y"),
        0xA0: ("LDY", "#"), 0xA4: ("LDY", "zp"), 0xB4: ("LDY", "zp,x"),
        0xAC: ("LDY", "abs"), 0xBC: ("LDY", "abs,x"),
        0x4A: ("LSR", "A"), 0x46: ("LSR", "zp"), 0x56: ("LSR", "zp,x"),
        0x4E: ("LSR", "abs"), 0x5E: ("LSR", "abs,x"),
        0xEA: ("NOP", ""),
        0x09: ("ORA", "#"), 0x05: ("ORA", "zp"), 0x15: ("ORA", "zp,x"),
        0x0D: ("ORA", "abs"), 0x1D: ("ORA", "abs,x"), 0x19: ("ORA", "abs,y"),
        0x01: ("ORA", "(zp,x)"), 0x11: ("ORA", "(zp),y"),
        0x48: ("PHA", ""), 0x08: ("PHP", ""), 0x68: ("PLA", ""), 0x28: ("PLP", ""),
        0x2A: ("ROL", "A"), 0x26: ("ROL", "zp"), 0x36: ("ROL", "zp,x"),
        0x2E: ("ROL", "abs"), 0x3E: ("ROL", "abs,x"),
        0x6A: ("ROR", "A"), 0x66: ("ROR", "zp"), 0x76: ("ROR", "zp,x"),
        0x6E: ("ROR", "abs"), 0x7E: ("ROR", "abs,x"),
        0x40: ("RTI", ""), 0x60: ("RTS", ""),
        0xE9: ("SBC", "#"), 0xE5: ("SBC", "zp"), 0xF5: ("SBC", "zp,x"),
        0xED: ("SBC", "abs"), 0xFD: ("SBC", "abs,x"), 0xF9: ("SBC", "abs,y"),
        0xE1: ("SBC", "(zp,x)"), 0xF1: ("SBC", "(zp),y"),
        0x38: ("SEC", ""), 0xF8: ("SED", ""), 0x78: ("SEI", ""),
        0x85: ("STA", "zp"), 0x95: ("STA", "zp,x"), 0x8D: ("STA", "abs"),
        0x9D: ("STA", "abs,x"), 0x99: ("STA", "abs,y"),
        0x81: ("STA", "(zp,x)"), 0x91: ("STA", "(zp),y"),
        0x86: ("STX", "zp"), 0x96: ("STX", "zp,y"), 0x8E: ("STX", "abs"),
        0x84: ("STY", "zp"), 0x94: ("STY", "zp,x"), 0x8C: ("STY", "abs"),
        0xAA: ("TAX", ""), 0xA8: ("TAY", ""), 0xBA: ("TSX", ""),
        0x8A: ("TXA", ""), 0x9A: ("TXS", ""), 0x98: ("TYA", ""),
    }

    def disassemble(self, addr: int) -> tuple[str, int]:
        """Disassemble instruction at addr. Returns (text, length)."""
        opcode = self.memory.read(addr)
        if opcode not in self.OPCODE_NAMES:
            return f"???  (${opcode:02X})", 1

        name, mode = self.OPCODE_NAMES[opcode]

        if mode == "":
            return name, 1
        elif mode == "A":
            return f"{name} A", 1
        elif mode == "#":
            val = self.memory.read(addr + 1)
            return f"{name} #${val:02X}", 2
        elif mode == "zp":
            val = self.memory.read(addr + 1)
            return f"{name} ${val:02X}", 2
        elif mode == "zp,x":
            val = self.memory.read(addr + 1)
            return f"{name} ${val:02X},X", 2
        elif mode == "zp,y":
            val = self.memory.read(addr + 1)
            return f"{name} ${val:02X},Y", 2
        elif mode == "abs":
            val = self.memory.read_word(addr + 1)
            return f"{name} ${val:04X}", 3
        elif mode == "abs,x":
            val = self.memory.read_word(addr + 1)
            return f"{name} ${val:04X},X", 3
        elif mode == "abs,y":
            val = self.memory.read_word(addr + 1)
            return f"{name} ${val:04X},Y", 3
        elif mode == "(abs)":
            val = self.memory.read_word(addr + 1)
            return f"{name} (${val:04X})", 3
        elif mode == "(zp,x)":
            val = self.memory.read(addr + 1)
            return f"{name} (${val:02X},X)", 2
        elif mode == "(zp),y":
            val = self.memory.read(addr + 1)
            return f"{name} (${val:02X}),Y", 2
        elif mode == "rel":
            offset = self.memory.read(addr + 1)
            if offset & 0x80:
                offset -= 0x100
            target = (addr + 2 + offset) & 0xFFFF
            return f"{name} ${target:04X}", 2
        else:
            return f"{name} ???", 1

    def format_state(self) -> str:
        """Format current CPU state for tracing."""
        flags = ""
        flags += "N" if self.get_flag(self.FLAG_N) else "n"
        flags += "V" if self.get_flag(self.FLAG_V) else "v"
        flags += "-"
        flags += "B" if self.get_flag(self.FLAG_B) else "b"
        flags += "D" if self.get_flag(self.FLAG_D) else "d"
        flags += "I" if self.get_flag(self.FLAG_I) else "i"
        flags += "Z" if self.get_flag(self.FLAG_Z) else "z"
        flags += "C" if self.get_flag(self.FLAG_C) else "c"
        return f"A=${self.a:02X} X=${self.x:02X} Y=${self.y:02X} SP=${self.sp:02X} [{flags}]"

    def add_pc_hook(self, addr: int, hook: Callable[[], None]) -> None:
        """Add a hook that's called when PC reaches a specific address."""
        self.pc_hooks[addr] = hook

    # --- Execution ---

    def step(self) -> bool:
        """Execute one instruction. Returns False if halted."""
        if self.halted:
            return False

        # Check for success termination
        if self.pc == self.SUCCESS_ADDR:
            self.halted = True
            self.success = True
            return False

        # Check for PC hooks (e.g., hard drive interception)
        if self.pc in self.pc_hooks:
            self.pc_hooks[self.pc]()
            self.instruction_count += 1
            return True

        # Fetch opcode
        pc_before = self.pc
        opcode = self.memory.read(self.pc)
        self.pc = (self.pc + 1) & 0xFFFF

        # Check for invalid opcode
        if self.opcodes[opcode] is None:
            raise InvalidOpcodeError(
                f"Invalid opcode ${opcode:02X} at ${pc_before:04X}"
            )

        # Trace before execution if enabled
        if self.trace_enabled:
            disasm, _ = self.disassemble(pc_before)
            state = self.format_state()
            self.trace_log.append(f"${pc_before:04X}: {disasm:20s}  {state}")

        # Execute
        self.opcodes[opcode]()
        self.instruction_count += 1

        return True

    def run(self, max_instructions: int = 1000) -> bool:
        """Run until halted or max instructions reached.

        Returns True if terminated successfully at $FFF9.
        """
        while self.instruction_count < max_instructions:
            if not self.step():
                break

        if not self.halted and self.instruction_count >= max_instructions:
            raise RuntimeError(
                f"Instruction limit ({max_instructions}) reached at PC=${self.pc:04X}"
            )

        return self.success
