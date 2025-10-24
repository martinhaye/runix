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

; fastest brk dispatch, no other IRQs expected
.proc brkvec
; note: this routine runs on zero page
	sta areg	; "free"
	stx xreg	; "free"
	sty yreg	; "free"-ish?
	tsx		; 2
	ldy $103,x	; +4=6
	dey		; +2=8
	sty @ld+2	; +3=11
	ldy $102,x	; +4=14
@ld:	lda $11FF,y	; +5=19
	sta @jmp+1	; +3=21
@jmp:	jmp brktbl	; +3=24
.endproc

; interesting variant - all 256 opcodes, but they have to share
.proc brkvec
; note: this routine runs on zero page
	sta areg	; "free"
	stx xreg	; "free"
	sty yreg	; "free"
	tsx		; 2
	ldy $103,x	; +4=6
	dey		; +2=8
	sty @ld+2	; +3=11
	ldy $102,x	; +4=14
@ld:	ldx $11FF,y	; +5=19
	lda brktbl,x	; +4=23
	sta @jmp+1	; +3=26
@jmp:	jmp brkdisps	; +3=29
.endproc

; More flexible (supports all 256 opcodes) but slower
.proc brkvec
	sta areg	; "free"
	stx xreg	; "free"
	sty yreg	; "free"
	tsx		; 2
	ldy $103,x	; +4=6
	dey		; +2=8
	sty @ld+2	; +3=11
	ldy $102,x	; +4=15
@ld:	lda $11FF,y	; +5=20
	asl		; +2=22
	bcs @hi		; +2=24
	sta @loj+1	; +3=27
@loj:	jmp (lotbl)	; +5=32
@hi:	sta @hij+1
@hij:	jmp (hitbl)	; 33
.endproc

; alternate using pla
	pla		; 4
	pla		; +4=8
	sec		; +2=10
	sbc #1		; +2=12
	sta @ld+1	; +3=15
	tax		; +2=17
	pla		; +4=21
	sbc #0		; +2=23
	sta @ld+2	; +3=26
	pha		; +3=29
	txa		; +2=31
	pha		; +3=34
@ld:	lda $1111	; +4=38
	sta @jmp+1	; +3=41
@jmp:	jmp brktbl	; +3=44

; slight variant
; alternate using pla
	tsx		; 2
	pla		; +4=6
	pla		; +4=10
	tay		; +2=12
	pla		; +4=16
	sec		; +2=18
	sbc #0		; +2=20
	sta @ld+2	; +3=23
	txs		; +2=25
@ld:	lda $11FF,y	; +5=30
	sta @jmp+1	; +3=33
@jmp:	jmp brktbl	; +3=36
