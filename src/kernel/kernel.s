; Runix kernel
; Loads at $0E00

        .org $0E00

        lda #$C1
        sta $7E0
        rts
