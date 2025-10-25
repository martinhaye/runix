; Runix kernel
; Loads at $0E00

	.org $0E00

txtptre	= $F2
txtptro	= $F4

;*****************************************************************************
.proc startup
	jsr clrscr
@lup:	jsr bascalc
	ldy cursy
	lda cursy
	clc
	adc #$C1
	sta (txtptre),y
	inc cursy
	lda cursy
	cmp #24
	bne @lup
	jmp *		; hang the system for now
.endproc

;*****************************************************************************
.proc bascalc
; Calculate base address for a text row
; In:	cursy - row num
; Out:	txtptre - even column address (400.7FF)
;	txtptro - odd column address (800.BFF)
;
; Algorithm: $400 + ((row//8) * $28) + ((row%2) * $80) + (((row//2)%4) * $100)
	lda cursy
	lsr		; divide by 2, row%2 to carry
	pha
	php
	lsr
	lsr		; now A = row//8 (range 0-2)
	tax
	lda #0
	plp
	ror		; C -> $80; clears carry
	dex
	bmi @got
	adc #$28
	dex
	bmi @got
	adc #$28
@got:	sta txtptre
	sta txtptro
	pla		; A = row//2
	and #3
	ora #4
	sta txtptre+1
	eor #$C
	sta txtptro+1
	rts
.endproc

;*****************************************************************************
.proc clreol
; Clear current line from curx to end
; Doesn't modify cursx
	ldy cursx
	lda #$A0
@lup:	sta (txtptre),y
	iny
	cpy #40
	bne @lup
	rts
.endproc

;*****************************************************************************
.proc clrscr
; Clear entire screen
; leaves with cursx=0, cursy=0
	lda #0
	sta cursx
@loop:	sta cursy
	jsr bascalc
	jsr clreol
	lda cursy
	clc
	adc #1
	cmp #24
	bne @loop
	lda #0
	sta cursy
	rts
.endproc

;*****************************************************************************
; data
cursx:	.byt 0
cursy:	.byt 0
