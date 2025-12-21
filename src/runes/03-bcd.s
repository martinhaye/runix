; Rune 3 - BCD (Binary Coded Decimal)
; Jump vectors at $C60-$C7F

        .org $2000

.include "base.i"

	; API jump vectors
	jmp _bcd_len
	jmp _bcd_fromstr
	jmp _bcd_debug
	jmp _bcd_print
	jmp _bcd_inc
	jmp _bcd_cmp
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
pstr	= bcd_ptr1
pnum	= bcd_ptr2
	stax pnum
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
proc:	ldy #0		; Y - dest byte pos
procl:	pla
	bmi done	; if sentinel encountered on lo, exit is easy
	sta orlo+1	; mod self
	pla
	asl
	asl
	asl
	asl		; A - high-order digit, C - sentinel bit
orlo:	ora #modn
store1:	sta (pnum),y
	iny
	bcc procl	; process until sentinel reached
done:	lda #$FF	; always end with terminator
store2:	sta (pnum),y
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
	cpx #0
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

;*****************************************************************************
.proc _bcd_inc
pnum	= bcd_ptr1
	stax pnum
	ldy #0
lup:	lda (pnum),y
	cmp #$FF
	beq ext

	clc
	sed		; so fun to actually use 6502's decimal mode
	adc #1
	cld		; gotta clear decimal mode for normal use

	sta (pnum),y
	iny
	bcs lup
	rts
ext:	lda #1
	sta (pnum),y
	iny
	lda #$FF
	sta (pnum),y
	rts
.endproc

;*****************************************************************************
.proc _bcd_cmp
pnum1	= bcd_ptr1
pnum2	= bcd_ptr2
	stax pnum2
	; scan for the end of one or both numbers
	ldy #0
lup:	lda (pnum1),y
	cmp #$FF
	beq end1
	lda (pnum2),y
	cmp #$FF
	beq end2
	iny
	bne lup		; always taken
end1:	lda (pnum2),y
	cmp #$FF
	beq eqlen
	; num1 is shorter than num2; so num1 < num2
	lda #$80	; negative and not equal
	clc		; less than
	rts
end2:	; num2 is shorter than num1; so num1 > num2
	lda #1		; positive and not equal
	sec		; greater than (or equal)
	rts
	; numbers are the same length; start comparing, MSB to LSB order
eqlen:	dey
	bmi equal	; if we reach the end of both nums, they must be equal
	lda (pnum1),y
	cmp (pnum2),y
	beq eqlen	; if this part is equal, keep checking
equal:	lda #0		; zero and equal
	sec		; greater than or equal
	rts		; once we find an inequality, we're done
.endproc