"""Tests for CPU module."""

import pytest
from pim65.cpu import CPU, InvalidOpcodeError
from pim65.memory import Memory


class TestCPUBasics:
    """Basic CPU tests."""

    def setup_method(self):
        """Set up test fixtures."""
        self.mem = Memory()
        self.cpu = CPU(self.mem)

    def test_initial_state(self):
        """CPU should have correct initial state after reset."""
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()
        assert self.cpu.a == 0
        assert self.cpu.x == 0
        assert self.cpu.y == 0
        assert self.cpu.sp == 0xFD
        assert self.cpu.pc == 0x1000

    def test_invalid_opcode(self):
        """Invalid opcode should raise InvalidOpcodeError."""
        self.mem.set_reset_vector(0x1000)
        self.mem.write(0x1000, 0x02)  # Invalid opcode
        self.cpu.reset()
        with pytest.raises(InvalidOpcodeError):
            self.cpu.step()


class TestFlags:
    """Tests for flag operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)

    def test_set_clear_flags(self):
        """Test flag set/clear operations."""
        self.cpu.set_flag(CPU.FLAG_C, True)
        assert self.cpu.get_flag(CPU.FLAG_C)
        self.cpu.set_flag(CPU.FLAG_C, False)
        assert not self.cpu.get_flag(CPU.FLAG_C)

    def test_update_nz_zero(self):
        """N=0, Z=1 for zero value."""
        self.cpu.update_nz(0)
        assert self.cpu.get_flag(CPU.FLAG_Z)
        assert not self.cpu.get_flag(CPU.FLAG_N)

    def test_update_nz_positive(self):
        """N=0, Z=0 for positive value."""
        self.cpu.update_nz(0x42)
        assert not self.cpu.get_flag(CPU.FLAG_Z)
        assert not self.cpu.get_flag(CPU.FLAG_N)

    def test_update_nz_negative(self):
        """N=1, Z=0 for negative value (bit 7 set)."""
        self.cpu.update_nz(0x80)
        assert not self.cpu.get_flag(CPU.FLAG_Z)
        assert self.cpu.get_flag(CPU.FLAG_N)


class TestStack:
    """Tests for stack operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.cpu.sp = 0xFF

    def test_push_pull(self):
        """Test push and pull."""
        self.cpu.push(0x42)
        assert self.cpu.sp == 0xFE
        assert self.mem.read(0x01FF) == 0x42
        val = self.cpu.pull()
        assert val == 0x42
        assert self.cpu.sp == 0xFF

    def test_push_word(self):
        """Test push_word (high byte first)."""
        self.cpu.push_word(0x1234)
        assert self.cpu.sp == 0xFD
        assert self.mem.read(0x01FF) == 0x12  # High byte pushed first
        assert self.mem.read(0x01FE) == 0x34  # Low byte pushed second

    def test_pull_word(self):
        """Test pull_word."""
        self.mem.write(0x01FE, 0x34)  # Low byte
        self.mem.write(0x01FF, 0x12)  # High byte
        self.cpu.sp = 0xFD
        val = self.cpu.pull_word()
        assert val == 0x1234
        assert self.cpu.sp == 0xFF


class TestLoadStore:
    """Tests for load/store instructions."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_lda_immediate(self):
        """LDA #$42"""
        self.mem.write(0x1000, 0xA9)  # LDA #
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert self.cpu.a == 0x42
        assert self.cpu.pc == 0x1002

    def test_lda_zero_page(self):
        """LDA $10"""
        self.mem.write(0x1000, 0xA5)  # LDA zp
        self.mem.write(0x1001, 0x10)
        self.mem.write(0x0010, 0x42)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_lda_zero_page_x(self):
        """LDA $10,X"""
        self.cpu.x = 0x05
        self.mem.write(0x1000, 0xB5)  # LDA zp,x
        self.mem.write(0x1001, 0x10)
        self.mem.write(0x0015, 0x42)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_lda_absolute(self):
        """LDA $2000"""
        self.mem.write(0x1000, 0xAD)  # LDA abs
        self.mem.write(0x1001, 0x00)
        self.mem.write(0x1002, 0x20)
        self.mem.write(0x2000, 0x42)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_lda_absolute_x(self):
        """LDA $2000,X"""
        self.cpu.x = 0x05
        self.mem.write(0x1000, 0xBD)  # LDA abs,x
        self.mem.write(0x1001, 0x00)
        self.mem.write(0x1002, 0x20)
        self.mem.write(0x2005, 0x42)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_lda_absolute_y(self):
        """LDA $2000,Y"""
        self.cpu.y = 0x05
        self.mem.write(0x1000, 0xB9)  # LDA abs,y
        self.mem.write(0x1001, 0x00)
        self.mem.write(0x1002, 0x20)
        self.mem.write(0x2005, 0x42)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_lda_indexed_indirect(self):
        """LDA ($10,X)"""
        self.cpu.x = 0x05
        self.mem.write(0x1000, 0xA1)  # LDA (zp,x)
        self.mem.write(0x1001, 0x10)
        self.mem.write(0x0015, 0x00)  # Low byte of pointer
        self.mem.write(0x0016, 0x20)  # High byte of pointer
        self.mem.write(0x2000, 0x42)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_lda_indirect_indexed(self):
        """LDA ($10),Y"""
        self.cpu.y = 0x05
        self.mem.write(0x1000, 0xB1)  # LDA (zp),y
        self.mem.write(0x1001, 0x10)
        self.mem.write(0x0010, 0x00)  # Low byte of pointer
        self.mem.write(0x0011, 0x20)  # High byte of pointer
        self.mem.write(0x2005, 0x42)  # $2000 + Y
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_ldx_immediate(self):
        """LDX #$42"""
        self.mem.write(0x1000, 0xA2)
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert self.cpu.x == 0x42

    def test_ldy_immediate(self):
        """LDY #$42"""
        self.mem.write(0x1000, 0xA0)
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert self.cpu.y == 0x42

    def test_sta_zero_page(self):
        """STA $10"""
        self.cpu.a = 0x42
        self.mem.write(0x1000, 0x85)  # STA zp
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.mem.read(0x0010) == 0x42

    def test_stx_zero_page(self):
        """STX $10"""
        self.cpu.x = 0x42
        self.mem.write(0x1000, 0x86)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.mem.read(0x0010) == 0x42

    def test_sty_zero_page(self):
        """STY $10"""
        self.cpu.y = 0x42
        self.mem.write(0x1000, 0x84)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.mem.read(0x0010) == 0x42


class TestArithmetic:
    """Tests for arithmetic operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_adc_simple(self):
        """ADC without carry."""
        self.cpu.a = 0x10
        self.cpu.set_flag(CPU.FLAG_C, False)
        self.mem.write(0x1000, 0x69)  # ADC #
        self.mem.write(0x1001, 0x20)
        self.cpu.step()
        assert self.cpu.a == 0x30
        assert not self.cpu.get_flag(CPU.FLAG_C)

    def test_adc_with_carry_in(self):
        """ADC with carry in."""
        self.cpu.a = 0x10
        self.cpu.set_flag(CPU.FLAG_C, True)
        self.mem.write(0x1000, 0x69)
        self.mem.write(0x1001, 0x20)
        self.cpu.step()
        assert self.cpu.a == 0x31

    def test_adc_carry_out(self):
        """ADC generating carry out."""
        self.cpu.a = 0xFF
        self.cpu.set_flag(CPU.FLAG_C, False)
        self.mem.write(0x1000, 0x69)
        self.mem.write(0x1001, 0x01)
        self.cpu.step()
        assert self.cpu.a == 0x00
        assert self.cpu.get_flag(CPU.FLAG_C)
        assert self.cpu.get_flag(CPU.FLAG_Z)

    def test_adc_overflow_positive(self):
        """ADC overflow: positive + positive = negative."""
        self.cpu.a = 0x50  # 80
        self.cpu.set_flag(CPU.FLAG_C, False)
        self.mem.write(0x1000, 0x69)
        self.mem.write(0x1001, 0x50)  # 80, total = 160 = $A0
        self.cpu.step()
        assert self.cpu.a == 0xA0
        assert self.cpu.get_flag(CPU.FLAG_V)

    def test_sbc_simple(self):
        """SBC without borrow."""
        self.cpu.a = 0x50
        self.cpu.set_flag(CPU.FLAG_C, True)  # No borrow
        self.mem.write(0x1000, 0xE9)  # SBC #
        self.mem.write(0x1001, 0x20)
        self.cpu.step()
        assert self.cpu.a == 0x30
        assert self.cpu.get_flag(CPU.FLAG_C)  # No borrow out

    def test_sbc_with_borrow(self):
        """SBC with borrow."""
        self.cpu.a = 0x50
        self.cpu.set_flag(CPU.FLAG_C, False)  # Borrow in
        self.mem.write(0x1000, 0xE9)
        self.mem.write(0x1001, 0x20)
        self.cpu.step()
        assert self.cpu.a == 0x2F

    def test_sbc_borrow_out(self):
        """SBC generating borrow."""
        self.cpu.a = 0x20
        self.cpu.set_flag(CPU.FLAG_C, True)
        self.mem.write(0x1000, 0xE9)
        self.mem.write(0x1001, 0x30)
        self.cpu.step()
        assert self.cpu.a == 0xF0
        assert not self.cpu.get_flag(CPU.FLAG_C)  # Borrow occurred


class TestLogical:
    """Tests for logical operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_and(self):
        """AND #$0F"""
        self.cpu.a = 0x5A
        self.mem.write(0x1000, 0x29)
        self.mem.write(0x1001, 0x0F)
        self.cpu.step()
        assert self.cpu.a == 0x0A

    def test_ora(self):
        """ORA #$0F"""
        self.cpu.a = 0x50
        self.mem.write(0x1000, 0x09)
        self.mem.write(0x1001, 0x0F)
        self.cpu.step()
        assert self.cpu.a == 0x5F

    def test_eor(self):
        """EOR #$FF"""
        self.cpu.a = 0x5A
        self.mem.write(0x1000, 0x49)
        self.mem.write(0x1001, 0xFF)
        self.cpu.step()
        assert self.cpu.a == 0xA5


class TestShiftRotate:
    """Tests for shift and rotate operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_asl_acc(self):
        """ASL A"""
        self.cpu.a = 0x40
        self.mem.write(0x1000, 0x0A)
        self.cpu.step()
        assert self.cpu.a == 0x80
        assert not self.cpu.get_flag(CPU.FLAG_C)

    def test_asl_acc_carry(self):
        """ASL A with carry out."""
        self.cpu.a = 0x81
        self.mem.write(0x1000, 0x0A)
        self.cpu.step()
        assert self.cpu.a == 0x02
        assert self.cpu.get_flag(CPU.FLAG_C)

    def test_lsr_acc(self):
        """LSR A"""
        self.cpu.a = 0x02
        self.mem.write(0x1000, 0x4A)
        self.cpu.step()
        assert self.cpu.a == 0x01
        assert not self.cpu.get_flag(CPU.FLAG_C)

    def test_lsr_acc_carry(self):
        """LSR A with carry out."""
        self.cpu.a = 0x03
        self.mem.write(0x1000, 0x4A)
        self.cpu.step()
        assert self.cpu.a == 0x01
        assert self.cpu.get_flag(CPU.FLAG_C)

    def test_rol_acc(self):
        """ROL A"""
        self.cpu.a = 0x40
        self.cpu.set_flag(CPU.FLAG_C, True)
        self.mem.write(0x1000, 0x2A)
        self.cpu.step()
        assert self.cpu.a == 0x81
        assert not self.cpu.get_flag(CPU.FLAG_C)

    def test_ror_acc(self):
        """ROR A"""
        self.cpu.a = 0x02
        self.cpu.set_flag(CPU.FLAG_C, True)
        self.mem.write(0x1000, 0x6A)
        self.cpu.step()
        assert self.cpu.a == 0x81
        assert not self.cpu.get_flag(CPU.FLAG_C)


class TestCompare:
    """Tests for compare operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_cmp_equal(self):
        """CMP when A == M."""
        self.cpu.a = 0x42
        self.mem.write(0x1000, 0xC9)
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_Z)
        assert self.cpu.get_flag(CPU.FLAG_C)
        assert not self.cpu.get_flag(CPU.FLAG_N)

    def test_cmp_greater(self):
        """CMP when A > M."""
        self.cpu.a = 0x50
        self.mem.write(0x1000, 0xC9)
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert not self.cpu.get_flag(CPU.FLAG_Z)
        assert self.cpu.get_flag(CPU.FLAG_C)

    def test_cmp_less(self):
        """CMP when A < M."""
        self.cpu.a = 0x30
        self.mem.write(0x1000, 0xC9)
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert not self.cpu.get_flag(CPU.FLAG_Z)
        assert not self.cpu.get_flag(CPU.FLAG_C)

    def test_cpx(self):
        """CPX immediate."""
        self.cpu.x = 0x42
        self.mem.write(0x1000, 0xE0)
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_Z)

    def test_cpy(self):
        """CPY immediate."""
        self.cpu.y = 0x42
        self.mem.write(0x1000, 0xC0)
        self.mem.write(0x1001, 0x42)
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_Z)


class TestIncDec:
    """Tests for increment/decrement operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_inc_mem(self):
        """INC $10"""
        self.mem.write(0x0010, 0x41)
        self.mem.write(0x1000, 0xE6)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.mem.read(0x0010) == 0x42

    def test_dec_mem(self):
        """DEC $10"""
        self.mem.write(0x0010, 0x43)
        self.mem.write(0x1000, 0xC6)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.mem.read(0x0010) == 0x42

    def test_inx(self):
        """INX"""
        self.cpu.x = 0x41
        self.mem.write(0x1000, 0xE8)
        self.cpu.step()
        assert self.cpu.x == 0x42

    def test_dex(self):
        """DEX"""
        self.cpu.x = 0x43
        self.mem.write(0x1000, 0xCA)
        self.cpu.step()
        assert self.cpu.x == 0x42

    def test_iny(self):
        """INY"""
        self.cpu.y = 0x41
        self.mem.write(0x1000, 0xC8)
        self.cpu.step()
        assert self.cpu.y == 0x42

    def test_dey(self):
        """DEY"""
        self.cpu.y = 0x43
        self.mem.write(0x1000, 0x88)
        self.cpu.step()
        assert self.cpu.y == 0x42

    def test_inx_wrap(self):
        """INX should wrap from $FF to $00."""
        self.cpu.x = 0xFF
        self.mem.write(0x1000, 0xE8)
        self.cpu.step()
        assert self.cpu.x == 0x00
        assert self.cpu.get_flag(CPU.FLAG_Z)


class TestBranch:
    """Tests for branch operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_bne_taken(self):
        """BNE taken when Z=0."""
        self.cpu.set_flag(CPU.FLAG_Z, False)
        self.mem.write(0x1000, 0xD0)  # BNE
        self.mem.write(0x1001, 0x10)  # +16
        self.cpu.step()
        assert self.cpu.pc == 0x1012

    def test_bne_not_taken(self):
        """BNE not taken when Z=1."""
        self.cpu.set_flag(CPU.FLAG_Z, True)
        self.mem.write(0x1000, 0xD0)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1002

    def test_beq_taken(self):
        """BEQ taken when Z=1."""
        self.cpu.set_flag(CPU.FLAG_Z, True)
        self.mem.write(0x1000, 0xF0)  # BEQ
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1012

    def test_branch_backward(self):
        """Branch with negative offset."""
        self.cpu.set_flag(CPU.FLAG_Z, False)
        self.mem.write(0x1000, 0xD0)  # BNE
        self.mem.write(0x1001, 0xFE)  # -2 (back to $1000)
        self.cpu.step()
        assert self.cpu.pc == 0x1000

    def test_bcc_taken(self):
        """BCC taken when C=0."""
        self.cpu.set_flag(CPU.FLAG_C, False)
        self.mem.write(0x1000, 0x90)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1012

    def test_bcs_taken(self):
        """BCS taken when C=1."""
        self.cpu.set_flag(CPU.FLAG_C, True)
        self.mem.write(0x1000, 0xB0)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1012

    def test_bmi_taken(self):
        """BMI taken when N=1."""
        self.cpu.set_flag(CPU.FLAG_N, True)
        self.mem.write(0x1000, 0x30)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1012

    def test_bpl_taken(self):
        """BPL taken when N=0."""
        self.cpu.set_flag(CPU.FLAG_N, False)
        self.mem.write(0x1000, 0x10)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1012

    def test_bvs_taken(self):
        """BVS taken when V=1."""
        self.cpu.set_flag(CPU.FLAG_V, True)
        self.mem.write(0x1000, 0x70)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1012

    def test_bvc_taken(self):
        """BVC taken when V=0."""
        self.cpu.set_flag(CPU.FLAG_V, False)
        self.mem.write(0x1000, 0x50)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.pc == 0x1012


class TestJumpCall:
    """Tests for jump and call operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_jmp_absolute(self):
        """JMP $2000"""
        self.mem.write(0x1000, 0x4C)  # JMP abs
        self.mem.write(0x1001, 0x00)
        self.mem.write(0x1002, 0x20)
        self.cpu.step()
        assert self.cpu.pc == 0x2000

    def test_jmp_indirect(self):
        """JMP ($2000)"""
        self.mem.write(0x1000, 0x6C)  # JMP (abs)
        self.mem.write(0x1001, 0x00)
        self.mem.write(0x1002, 0x20)
        self.mem.write(0x2000, 0x34)  # Target low
        self.mem.write(0x2001, 0x12)  # Target high
        self.cpu.step()
        assert self.cpu.pc == 0x1234

    def test_jmp_indirect_page_bug(self):
        """JMP indirect page boundary bug."""
        self.mem.write(0x1000, 0x6C)
        self.mem.write(0x1001, 0xFF)  # Pointer at $20FF
        self.mem.write(0x1002, 0x20)
        self.mem.write(0x20FF, 0x34)  # Low byte
        self.mem.write(0x2000, 0x12)  # High byte (wraps to $2000, not $2100)
        self.cpu.step()
        assert self.cpu.pc == 0x1234

    def test_jsr_rts(self):
        """JSR and RTS."""
        # JSR $2000
        self.mem.write(0x1000, 0x20)
        self.mem.write(0x1001, 0x00)
        self.mem.write(0x1002, 0x20)
        # RTS at $2000
        self.mem.write(0x2000, 0x60)

        self.cpu.step()  # JSR
        assert self.cpu.pc == 0x2000
        old_sp = self.cpu.sp

        self.cpu.step()  # RTS
        assert self.cpu.pc == 0x1003
        assert self.cpu.sp == old_sp + 2


class TestBIT:
    """Tests for BIT instruction."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_bit_zero(self):
        """BIT sets Z when A & M = 0."""
        self.cpu.a = 0x0F
        self.mem.write(0x0010, 0xF0)
        self.mem.write(0x1000, 0x24)  # BIT zp
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_Z)

    def test_bit_n_flag(self):
        """BIT copies bit 7 of memory to N."""
        self.cpu.a = 0xFF
        self.mem.write(0x0010, 0x80)
        self.mem.write(0x1000, 0x24)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_N)

    def test_bit_v_flag(self):
        """BIT copies bit 6 of memory to V."""
        self.cpu.a = 0xFF
        self.mem.write(0x0010, 0x40)
        self.mem.write(0x1000, 0x24)
        self.mem.write(0x1001, 0x10)
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_V)


class TestBRK:
    """Tests for BRK instruction."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()
        self.cpu.sp = 0xFF

    def test_brk(self):
        """BRK pushes PC+2, status, and jumps via IRQ vector."""
        self.mem.write_word(0xFFFE, 0x2000)  # IRQ vector
        self.mem.write(0x1000, 0x00)  # BRK
        self.mem.write(0x1001, 0x42)  # Padding byte (skipped)

        old_status = self.cpu.status
        self.cpu.step()

        # PC should be at IRQ handler
        assert self.cpu.pc == 0x2000

        # Stack should have PC+2 and status
        assert self.cpu.sp == 0xFC
        # Status on stack should have B and U set
        pushed_status = self.mem.read(0x01FD)
        assert pushed_status & CPU.FLAG_B
        assert pushed_status & CPU.FLAG_U

        # Return address should be $1002 (BRK + padding)
        assert self.mem.read(0x01FE) == 0x02  # Low
        assert self.mem.read(0x01FF) == 0x10  # High

        # I flag should be set
        assert self.cpu.get_flag(CPU.FLAG_I)


class TestRTI:
    """Tests for RTI instruction."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()
        self.cpu.sp = 0xFF

    def test_rti(self):
        """RTI restores status and PC from stack."""
        # Push return state
        self.cpu.push_word(0x2000)  # Return PC
        self.cpu.push(0xFF)  # Status with all flags

        self.mem.write(0x1000, 0x40)  # RTI
        self.cpu.step()

        assert self.cpu.pc == 0x2000
        # B flag should NOT be set after RTI, U flag should be
        assert not self.cpu.get_flag(CPU.FLAG_B)
        assert self.cpu.get_flag(CPU.FLAG_U)
        assert self.cpu.get_flag(CPU.FLAG_N)
        assert self.cpu.get_flag(CPU.FLAG_V)
        assert self.cpu.get_flag(CPU.FLAG_C)


class TestTransfer:
    """Tests for transfer operations."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_tax(self):
        """TAX"""
        self.cpu.a = 0x42
        self.mem.write(0x1000, 0xAA)
        self.cpu.step()
        assert self.cpu.x == 0x42

    def test_tay(self):
        """TAY"""
        self.cpu.a = 0x42
        self.mem.write(0x1000, 0xA8)
        self.cpu.step()
        assert self.cpu.y == 0x42

    def test_txa(self):
        """TXA"""
        self.cpu.x = 0x42
        self.mem.write(0x1000, 0x8A)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_tya(self):
        """TYA"""
        self.cpu.y = 0x42
        self.mem.write(0x1000, 0x98)
        self.cpu.step()
        assert self.cpu.a == 0x42

    def test_tsx(self):
        """TSX"""
        self.cpu.sp = 0x42
        self.mem.write(0x1000, 0xBA)
        self.cpu.step()
        assert self.cpu.x == 0x42

    def test_txs(self):
        """TXS (does not affect flags)."""
        self.cpu.x = 0x42
        self.cpu.set_flag(CPU.FLAG_Z, True)
        self.cpu.set_flag(CPU.FLAG_N, True)
        self.mem.write(0x1000, 0x9A)
        self.cpu.step()
        assert self.cpu.sp == 0x42
        # TXS doesn't affect flags
        assert self.cpu.get_flag(CPU.FLAG_Z)
        assert self.cpu.get_flag(CPU.FLAG_N)


class TestStackOps:
    """Tests for PHA, PHP, PLA, PLP."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()
        self.cpu.sp = 0xFF

    def test_pha_pla(self):
        """PHA and PLA."""
        self.cpu.a = 0x42
        self.mem.write(0x1000, 0x48)  # PHA
        self.mem.write(0x1001, 0xA9)  # LDA #$00
        self.mem.write(0x1002, 0x00)
        self.mem.write(0x1003, 0x68)  # PLA

        self.cpu.step()  # PHA
        assert self.cpu.sp == 0xFE
        assert self.mem.read(0x01FF) == 0x42

        self.cpu.step()  # LDA #$00
        assert self.cpu.a == 0x00

        self.cpu.step()  # PLA
        assert self.cpu.a == 0x42
        assert self.cpu.sp == 0xFF

    def test_php_plp(self):
        """PHP and PLP."""
        self.cpu.set_flag(CPU.FLAG_C, True)
        self.cpu.set_flag(CPU.FLAG_Z, True)
        self.mem.write(0x1000, 0x08)  # PHP
        self.mem.write(0x1001, 0x18)  # CLC
        self.mem.write(0x1002, 0x28)  # PLP

        self.cpu.step()  # PHP
        pushed = self.mem.read(0x01FF)
        assert pushed & CPU.FLAG_C
        assert pushed & CPU.FLAG_Z
        assert pushed & CPU.FLAG_B  # PHP sets B
        assert pushed & CPU.FLAG_U

        self.cpu.step()  # CLC
        assert not self.cpu.get_flag(CPU.FLAG_C)

        self.cpu.step()  # PLP
        assert self.cpu.get_flag(CPU.FLAG_C)
        assert self.cpu.get_flag(CPU.FLAG_Z)
        # B flag should NOT be set after PLP
        assert not self.cpu.get_flag(CPU.FLAG_B)


class TestFlagInstructions:
    """Tests for flag manipulation instructions."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_clc_sec(self):
        """CLC and SEC."""
        self.cpu.set_flag(CPU.FLAG_C, True)
        self.mem.write(0x1000, 0x18)  # CLC
        self.cpu.step()
        assert not self.cpu.get_flag(CPU.FLAG_C)

        self.mem.write(0x1001, 0x38)  # SEC
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_C)

    def test_cli_sei(self):
        """CLI and SEI."""
        self.mem.write(0x1000, 0x58)  # CLI
        self.cpu.step()
        assert not self.cpu.get_flag(CPU.FLAG_I)

        self.mem.write(0x1001, 0x78)  # SEI
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_I)

    def test_cld_sed(self):
        """CLD and SED."""
        self.cpu.set_flag(CPU.FLAG_D, True)
        self.mem.write(0x1000, 0xD8)  # CLD
        self.cpu.step()
        assert not self.cpu.get_flag(CPU.FLAG_D)

        self.mem.write(0x1001, 0xF8)  # SED
        self.cpu.step()
        assert self.cpu.get_flag(CPU.FLAG_D)

    def test_clv(self):
        """CLV."""
        self.cpu.set_flag(CPU.FLAG_V, True)
        self.mem.write(0x1000, 0xB8)  # CLV
        self.cpu.step()
        assert not self.cpu.get_flag(CPU.FLAG_V)


class TestNOP:
    """Tests for NOP instruction."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)
        self.mem.set_reset_vector(0x1000)
        self.cpu.reset()

    def test_nop(self):
        """NOP does nothing but advance PC."""
        old_a = self.cpu.a
        old_x = self.cpu.x
        old_y = self.cpu.y
        old_status = self.cpu.status
        self.mem.write(0x1000, 0xEA)
        self.cpu.step()
        assert self.cpu.pc == 0x1001
        assert self.cpu.a == old_a
        assert self.cpu.x == old_x
        assert self.cpu.y == old_y
        assert self.cpu.status == old_status


class TestSuccessTermination:
    """Tests for success termination at $FFF9."""

    def setup_method(self):
        self.mem = Memory()
        self.cpu = CPU(self.mem)

    def test_success_on_jmp(self):
        """Simulation succeeds when PC reaches $FFF9."""
        self.mem.set_reset_vector(0x1000)
        self.mem.write(0x1000, 0x4C)  # JMP $FFF9
        self.mem.write(0x1001, 0xF9)
        self.mem.write(0x1002, 0xFF)
        self.cpu.reset()

        result = self.cpu.run(100)
        assert result is True
        assert self.cpu.success is True
        assert self.cpu.halted is True
