; ROM segment at $F800
; Simple routine that adds 2 to accumulator

.setcpu "6502"
.org $F800

rom_routine_2:
    clc
    adc #$02
    rts
