; Rune 3 - BCD (Binary Coded Decimal)
; Jump vectors at $C60-$C7F

        .org $2000

.include "base.i"

	; API jump vectors
	jmp _bcd_len
	jmp _bcd_fromstr
	.align 32,$EA

;*****************************************************************************
.proc _bcd_len
	stax ld+1	; mod self
	ldx #0		; byte offset
ld:	lda modaddr,x
	cmp #$FF	; check for end-of-num
	beq fin
	tay		; track last non-terminator value
	inx
	bne ld		; always taken
fin:	txa
	asl		; double # bytes
	cpy #$80	; sub 1 if last had no hi-ord digit
	sbc #0
	ldx #0
	rts
.endproc

;*****************************************************************************
.proc _bcd_fromstr
pstr	= bcd_fromstr_arg0
	stax store1+1
	stax store2+1
	; scan for valid digits
	lda #$F0
	pha		; sentinel
	ldy #0		; Y - string pos
scan:	lda (pstr),y
	sec
	sbc #'0'
	bcc proc
	cmp #10
	bcs proc
	pha		; save digit for later
	iny
	bne scan	; always taken
	; digits are now on the stack, and we can pop least-to-most sig
proc:	pla
	bmi done	; if sentinel encountered on lo, exit is easy
	sta orlo+1	; mod self
	pla
	asl
	asl
	asl
	asl		; A - high-order digit, C - sentinel bit
orlo:	ora #modn
store1:	sta modaddr,x
	inx
	bcc proc	; process until sentinel reached
done:	lda #$FF	; always end with terminator
store2:	sta modaddr,x
	rts
.endproc

;*****************************************************************************
.proc _bcd_print
ptr	= bcd_ptr1
	stax ptr
	ldy #0
	; find terminator
fterm:	lda (ptr),y
	iny
	cmp #$FF
	bne fterm
	dey
	dey
	ldx #0		; char count, for initial-zero suppression
prlup:	lda (ptr),y
	pha
	lsr
	lsr
	lsr
	lsr
	jsr dopr
	pla
	and #$F
	jsr dopr
	dey
	bpl prlup
	rts
dopr:	bne notz
	txa
	beq skip
notz:	ora #$30
	jsr cout
	inx
skip:	rts
.endproc

;*****************************************************************************
.proc _bcd_debug
ptr	= bcd_ptr1
	stax ptr
	ldy #0
fterm:	lda (ptr),y
	iny
	pha
	jsr prbyte
	lda #'.'
	jsr cout
	pla
	cmp #$FF
	bne fterm
	rts
.endproc
