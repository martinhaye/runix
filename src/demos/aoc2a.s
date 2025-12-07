; Advent of code, day 2, puzzle 2a

.include "base.i"

        .org $1000


pscan	= $50	; length 2
nmatch	= $52	; length 2

current	= $60	; length 16
lower	= $70	; "
upper	= $80	; "
sum	= $90	; "

.proc main
	lda #0
	sta pscan
	sta nmatch
	sta nmatch+1
	bit data
	lda *-1
	sta pscan+1

	lda #1
	sta sum
	lda #'0'
	sta sum+1

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
	print "----------\n"
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
	; if both ranges have odd length, no matches are possible
	lda lower
	and #1
	beq even
	lda upper
	and #1
	beq even
	print "Skipping odd range.\n"
	jmp first
even:
	; start at lower
	ldx #15
:	lda lower,x
	sta current,x
	dex
	bpl :-
	jsr halve
	jsr double

check:	print "chk\n"
	ldx #current
	ldy #lower
	jsr compare
	beq oklo
	bcc adv
oklo:	ldx #current
	ldy #upper
	jsr compare
	bcs adv
match:	inc nmatch
	bne :+
	inc nmatch+1
:
	lda #current
	ldx #0
	print "match: %s\n"
	jsr accum
	lda #sum
	ldx #0
	print "sum: %s\n"
	jsr rdkey
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
	
	beq ok
	bcs gonx
ok:	jmp check
gonx:	jmp first

finish:	lda nmatch
	ldx nmatch+1
	print "nmatch=%x\n"
	lda #sum
	ldx #0
	print "final sum=%s\n"
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
done:	php	; preserve P while popping A from stack
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
	lda #'0'
	sta current,x
	dex
	bne digit
all9:	ldx #current
	jsr ripple
	ldx #1
	bne digit	; always taken
done:	rts
.endproc

.proc ripple
	stx lup+1	; adjust loop stores
	stx st+1
	lda 0,x
	tay		; get length
lup:	lda 0,y
	iny
st:	sta 0,y
	dey
	dey
	bne lup
	lda #'0'
	sta 1,x
	inc 0,x
	rts
.endproc

.proc accum
	; adjust sum so it has current digits plus 1
adj:	lda current
	cmp sum
	bcc noadj
	ldx #sum
	jsr ripple
	jmp adj
noadj:	; now add
	ldx current
	ldy sum
	clc
lup:	lda current,x
	and #$F
	adc sum,y
	cmp #'9'+1
	bcc nocar
	sec
	sbc #10
	sec
nocar:	sta sum,y
	dey
	dex
	bne lup
	lda sum,y
	adc #0
	sta sum,y
	rts
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
