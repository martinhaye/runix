; ROM segment at $C200
; Simple routine that adds 1 to accumulator

.setcpu "6502"
.org $C200

rom_routine_1:
    clc
    adc #$01
    rts
