; Runix shell
; Loads somewhere $2000-$AFFF; always org at $1000 so relocator knows what to do

        .org $1000

.include "base.i"

;*****************************************************************************
.proc rdlin
	lda #0
	sta bufpos
@prpt:	ldx #0
:	lda prompt+1,x
	jsr cout
	inx
	cpx prompt
	bne :-
@lup:	jsr rdkey
	cmp #8
	beq @bksp
	cmp #13
	beq @cr
	cmp #32
	bcc @lup
	jsr getxy
	cpx #39
	beq @lup	; don't go beyond right edge, for now
	ldx bufpos
	sta inbuf+1,x	; store the char (skip 1st byte - len)
	jsr cout	; display the new char
	jmp @lup
@bksp:	lda bufpos
	beq @lup	; ignore if already at start of buf
	dec bufpos
	jsr getxy
	dex		; back up one space
	jsr gotoxy
	lda #' '
	jsr cout	; overwrite the previous char
	jsr gotoxy	; and back up again
	jmp @lup	; and go get more
@cr:	lda bufpos
	sta inbuf
	rts
.endproc

;*****************************************************************************
data:
	.res 3,0	; stops relocator here

prompt:	.byt 2, "# "
bufpos:	.byt 0

	.align 256
inbuf:	.res 256