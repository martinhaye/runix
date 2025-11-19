; Multi-segment test program for sim65 version 3
; Main code segment at $0200

.setcpu "6502"
.org $0200

start:
    ; Call ROM routine at $C200
    jsr $C200

    ; Call ROM routine at $F800
    jsr $F800

    ; Exit
    lda #$00
    rts
