; Advent of code, day 2, puzzle 2a

.include "base.i"

        .org $1000


pscan	= $50	; length 2

current	= $60	; length 16
lower	= $70	; "
upper	= $80	; "

.proc main
	lda #0
	sta pscan
	bit data
	lda *-1
	sta pscan+1
first:	ldy #0
	lda (pscan),y
	bne :+
	jmp finish
:
	
	ldx #lower
	jsr getnum
	pha
	lda #lower
	ldx #0
	print "lower=%s\n"
	pla

	cmp #'-'
	beq :+
	fatal "expecting -"
:

	ldx #upper
	jsr getnum
	pha
	lda #upper
	ldx #0
	print "upper=%s\n"
	pla

	bne :+
	jmp finish
:	cmp #','
	beq :+
	fatal "expecting ,"
:

	; start at lower
	ldx #15
:	lda lower,x
	sta current,x
	dex
	bpl :-

check:	print "chk\n"
	ldx #current
	ldy #lower
	jsr compare
	php
	lda #'*'
	jsr cout
	plp
	beq match
	bcc adv
match:	lda #current
	ldx #0
	print "match: %s\n"
adv:	jsr halve
	lda #current
	ldx #0
	print "halved='%s'\n"
	jsr incr
	lda #current
	ldx #0
	print "incr'd='%s'\n"
	jsr double
	lda #current
	ldx #0
	print "doubld='%s'\n"
	ldx #current
	ldy #upper
	jsr compare

	php
	lda #'c'
	bcc :+
	lda #'C'
:	jsr cout
	lda #'z'
	plp
	php
	bne :+
	lda #'Z'
:	jsr cout
	jsr crout
	plp
	
	beq ok
	bcs finish
ok:	jmp check

finish:	print "Done.\n"
	rts

.endproc

.proc compare
	lda 0,x
lup:	pha		; length to compare
	lda 0,x
	cmp 0,y
	bne done
	inx
	iny
	pla
	sec
	sbc #1
	bpl lup
	lda #0
	rts
done:	php
	pla
	tax
	pla
	txa
	pha
	plp
	rts
.endproc

.proc halve
	lda current
	lsr
	sta current
	rts
.endproc

.proc double
	ldx #0
	ldy current
lup:	cpx current
	beq done
	inx
	iny
	lda current,x
	sta current,y
	cpx current
	bcc lup
done:	asl current
	rts
.endproc

.proc incr
not9s:	ldx current
digit:	lda current,x
	clc
	adc #1
	sta current,x
	cmp #'9'+1
	bcc done
	dex
	bne digit
	fatal "handle all 9's"
done:	rts
.endproc

.proc getnum
	stx sub+1	; save start; self-modifies code below
lup:	jsr getchar
	cmp #'0'
	bcc done
	cmp #'9'+1
	bcs done
	inx
	sta 0,x
	bne lup		; always taken
done:	pha		; save last byte read
	txa
	sec
sub:	sbc #11		; self-mod above; calculate length
	ldx sub+1
	sta 0,x
	pla
	rts
.endproc

.proc getchar
	ldy #0
	lda (pscan),y
	inc pscan
	bne :+
	inc pscan+1
:	rts
.endproc

	.align 256
data:
	.byt "11-22,95-115,998-1012,1188511880-1188511890,222220-222224,"
	.byt "1698522-1698528,446443-446449,38593856-38593862,565653-565659,"
	.byt "824824821-824824827,2121212118-2121212124"
	.byt 0
