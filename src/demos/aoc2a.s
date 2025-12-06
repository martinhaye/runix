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
	beq finish
	ldx #lower
	jsr getnum
	ldx #upper
	jsr getnum


.endproc

.proc getnum
	stx sub+1	; self-modifies code below
lup:	jsr getchar
	cmp #'0'
	bcc done
	cmp #'9'+1
	bcs done
	sta 0,x
	inx
	bne lup		; always taken
done:	txa
	sec
sub:	sbc #11		; self-mod above; calculate length
	ldx sub+1
	sta 0,x
	rts

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
