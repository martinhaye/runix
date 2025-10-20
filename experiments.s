; brk dispatch with optional str
brkvec:	sta areg
	stx xreg
	sty yreg
	pla
	sta preg
	and #$10
	beq irq
	tsx
	lda 101,x
	sta ptmp
	ldy 102,x
	dey
	sty ptmp+1
	ldy #$FF	; access byte before advanced PC
	lda (ptmp),y
	asl
	sta pvec
	bcs gotstr
pvec:	jmp vectbl

; just jsr STR_XX to set str of len XX
setstr:	pla
	sta pstr
	pla
	sta pstr+1
	ldy #0
	lda (pstr),y
	clc
	adc pstr
	tay
	lda pstr+1
	adc #0
	pha
	tya
	pha
	rts
