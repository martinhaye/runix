; Runix shell
; Loads somewhere $2000-$AFFF; always org at $1000 so relocator knows what to do

        .org $1000

.include "base.i"
;*****************************************************************************
.proc main
	; input a command line
@repl:	jsr rdlin
	; zero-terminate the command line also, for later processing
	ldy inbuf
	lda #0
	sta inbuf+1,y
	; find space between program name and args
	ldy #0
@cksp:	lda inbuf+1,y
	cmp #' '
	beq @fnden
	iny
	cpy inbuf
	bne @cksp
@fnden:	sty inbuf	; truncate to just prog name
	ldx *-1		; cute way to get hi byte of inbuf ptr
	tya
	beq @repl	; handle blank line
	lda #0
	jsr progrun
	bcc @repl
	print "Error: command not found.\n"
	jmp @repl
.endproc

;*****************************************************************************
.proc rdlin
	lda #0
	sta inbuf	; buffer position/len at start of buf
@prpt:	ldx #0
:	lda prompt+1,x
	jsr cout
	inx
	cpx prompt
	bne :-
@lup:	jsr rdkey
	cmp #8
	beq @bksp
	cmp #$5C
	beq @bksp
	cmp #13
	beq @cr
	cmp #32
	bcc @lup
	jsr getxy
	cpx #39
	beq @lup	; don't go beyond right edge, for now
	ldx inbuf
	sta inbuf+1,x	; store the char (skip 1st byte - len)
	inc inbuf
	jsr cout	; display the new char
	jmp @lup
@bksp:	lda inbuf
	beq @lup	; ignore if already at start of buf
	dec inbuf
	jsr getxy
	dex		; back up one space
	jsr gotoxy
	jsr getxy
	lda #' '
	jsr cout	; overwrite the previous char
	jsr gotoxy	; and back up again
	jmp @lup	; and go get more
@cr:	jmp crout
.endproc

;*****************************************************************************
data:
	.res 3,0	; stops relocator here

prompt:	.byt 2, "# "

	.align 256
inbuf:	.res 256