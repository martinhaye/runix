#!/usr/bin/env python3
"""Create a boot stub binary for pim65 testing."""

# Boot stub that:
# 1. Sets up IRQ handler at $FF00 that emulates Apple II ROM BRK behavior
#    (saves A/X/Y/P to zero page, saves PC to $3A/$3B, then JMP ($3F0))
# 2. Sets IRQ vector at $FFFE to point to our handler
# 3. Loads block 0 to $2000
# 4. Jumps to it with X=$20 (slot 2)
#
# Apple II ROM BRK behavior saves:
#   $3A/$3B = return address (PC after BRK + signature byte)
#   $45 = A register
#   $46 = X register
#   $47 = Y register
#   $48 = P (processor status)

# IRQ handler at $FF00 - emulates Apple II ROM BRK handling
# Stack on entry: [... P, PCL, PCH] (P on top)
irq_handler = bytes([
    # STA $45       ; save A
    0x8D, 0x45, 0x00,
    # STX $46       ; save X
    0x8E, 0x46, 0x00,
    # STY $47       ; save Y
    0x8C, 0x47, 0x00,
    # PLA           ; get P from stack
    0x68,
    # STA $48       ; save P
    0x85, 0x48,
    # PHA           ; put P back on stack
    0x48,
    # TSX           ; get stack pointer
    0xBA,
    # LDA $0102,X   ; get PC low from stack (at SP+2)
    0xBD, 0x02, 0x01,
    # STA $3A       ; save PC low
    0x85, 0x3A,
    # LDA $0103,X   ; get PC high from stack (at SP+3)
    0xBD, 0x03, 0x01,
    # STA $3B       ; save PC high
    0x85, 0x3B,
    # JMP ($03F0)   ; jump to user's BRK handler
    0x6C, 0xF0, 0x03,
])

boot_stub = bytes([
    # First, set up the IRQ handler at $FF00
    # We need to copy irq_handler bytes to $FF00
])

# Build the boot stub dynamically
boot_code = []

# Copy IRQ handler to $FF00 byte by byte
for i, byte in enumerate(irq_handler):
    # LDA #byte
    boot_code.extend([0xA9, byte])
    # STA $FF00+i
    addr = 0xFF00 + i
    boot_code.extend([0x8D, addr & 0xFF, addr >> 8])

# Set IRQ vector at $FFFE to point to $FF00
# LDA #$00
boot_code.extend([0xA9, 0x00])
# STA $FFFE
boot_code.extend([0x8D, 0xFE, 0xFF])
# LDA #$FF
boot_code.extend([0xA9, 0xFF])
# STA $FFFF
boot_code.extend([0x8D, 0xFF, 0xFF])

# Now do the block load
boot_code.extend([
    # LDX #$20       ; slot 2 * 16
    0xA2, 0x20,
    # LDA #$01       ; read command
    0xA9, 0x01,
    # STA $42        ; cmd
    0x85, 0x42,
    # LDA #$20       ; unit $20
    0xA9, 0x20,
    # STA $43        ; unit
    0x85, 0x43,
    # LDA #$00       ; buf lo
    0xA9, 0x00,
    # STA $44
    0x85, 0x44,
    # LDA #$20       ; buf hi = $2000
    0xA9, 0x20,
    # STA $45
    0x85, 0x45,
    # LDA #$00       ; blk lo = 0
    0xA9, 0x00,
    # STA $46
    0x85, 0x46,
    # STA $47        ; blk hi = 0 (A still 0)
    0x85, 0x47,
    # JSR $C20A      ; call block driver
    0x20, 0x0A, 0xC2,
    # JMP $2000      ; jump to boot block
    0x4C, 0x00, 0x20,
])

boot_stub = bytes(boot_code)

if __name__ == "__main__":
    with open("tests/bootstub.bin", "wb") as f:
        f.write(boot_stub)
    print(f"Created tests/bootstub.bin ({len(boot_stub)} bytes)")
