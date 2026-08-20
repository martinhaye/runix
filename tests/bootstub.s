; Boot stub for emulator tests.
; Loaded at $1000; loads disk block 0 to $2000 and jumps there with X=$20 (slot 2).
;
; Also installs an IRQ/BRK handler at $FF00 that mirrors Apple II ROM BRK
; bookkeeping ($3A/$3B PC, $45–$48 A/X/Y/P) then JMP ($03F0).

	.org $1000

;*****************************************************************************
; Copy IRQ handler to $FF00
;*****************************************************************************
	lda #$8D
	sta $FF00
	lda #$45
	sta $FF01
	lda #$00
	sta $FF02
	lda #$8E
	sta $FF03
	lda #$46
	sta $FF04
	lda #$00
	sta $FF05
	lda #$8C
	sta $FF06
	lda #$47
	sta $FF07
	lda #$00
	sta $FF08
	lda #$68
	sta $FF09
	lda #$85
	sta $FF0A
	lda #$48
	sta $FF0B
	lda #$68
	sta $FF0C
	lda #$85
	sta $FF0D
	lda #$3A
	sta $FF0E
	lda #$68
	sta $FF0F
	lda #$85
	sta $FF10
	lda #$3B
	sta $FF11
	lda #$6C
	sta $FF12
	lda #$F0
	sta $FF13
	lda #$03
	sta $FF14

; Set IRQ vector → $FF00
	lda #$00
	sta $FFFE
	lda #$FF
	sta $FFFF

;*****************************************************************************
; Load block 0 → $2000 via slot-2 ProDOS block device, then enter boot block
;*****************************************************************************
	ldx #$20		; slot 2 * 16
	lda #$01		; read
	sta $42			; cmd
	lda #$20
	sta $43			; unit
	lda #$00
	sta $44			; buf lo
	lda #$20
	sta $45			; buf hi = $2000
	lda #$00
	sta $46			; blk lo
	sta $47			; blk hi
	jsr $C20A
	jmp $2000
