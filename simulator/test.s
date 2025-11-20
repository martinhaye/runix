; Simple 6502 test program for sim65
; Includes proper header for sim65

.setcpu "6502"

; Export the header symbol
.export __EXEHDR__: absolute = 1

; Header segment
.segment "EXEHDR"
    .byte   $73, $69, $6D, $36, $35        ; "sim65" signature (5 bytes, no null)
    .byte   $02                            ; Version (must be 2)
    .byte   $00                            ; CPU type (6502)
    .byte   $FF                            ; Stack pointer page ($01FF)
    .word   $0200                          ; Load address
    .word   $0200                          ; Reset address (start of code)

; Code segment
.segment "CODE"
start:
    lda #$10        ; Load 16 into accumulator
    clc             ; Clear carry flag
    adc #$20        ; Add 32 (result should be 48/$30)
    sta result      ; Store the result

    lda #$00        ; Load 0 (success code)
    rts             ; Return

; Data segment
.segment "BSS"
result: .res 1      ; Reserve 1 byte for result
