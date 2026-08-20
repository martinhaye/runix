; Halts the emulator (JMP $FFF9)

.include "base.i"

        .org $1000	; relocated at load time

	jmp $FFF9
