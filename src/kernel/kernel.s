; Runix kernel
; Loads at $0E00

	.org $0E00

txtptre	= $F2
txtptro	= $F4

;*****************************************************************************
.proc startup
	jsr clrscr
@lup:	lda $E000
	jsr cout
	inc @lup+1
	bne @lup
	inc @lup+2
	bne @lup
	jmp *	; hang for now
.endproc

;*****************************************************************************
sety:	sta cursy
	; fall into bascalc...
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
@loop:	jsr sety
	jsr clreol
	lda cursy
	clc
	adc #1
	cmp #24
	bne @loop
	lda #0
	jmp sety
.endproc

;*****************************************************************************
.proc cout
; Write one character to the text screen. Advances cursx (and cursy if end of
; line)
; In:	A - char to write (hi bit ignored)
; Out:	For speed, does *not* preserve registers
	ldy cursx
	cmp #$D
	beq crout
	ora #$80
	sta (txtptre),y
	iny
	cpy #40
	sty cursx
	beq crout
	rts
.endproc

;*****************************************************************************
.proc crout
; Advance to start of next line - scrolls if end of screen reached.
; Trashes all regs
	lda #0
	sta cursx
	inc cursy
	lda cursy
	cmp #24
	beq @scrl
	jmp bascalc
@scrl:	lda #0
	jsr sety
@sc1:	lda txtptre
	sta @st+1		; self-modify target
	lda txtptre+1
	sta @st+2
	inc cursy
	jsr bascalc
	ldy #39
@cp:	lda (txtptre),y
@st:	sta $1111,y		; self-modified above
	dey
	bpl @cp
	lda cursy
	cmp #23
	bne @sc1
	jmp clreol
.endproc

;*****************************************************************************
; data
cursx:		.byte 0
cursy:		.byte 0