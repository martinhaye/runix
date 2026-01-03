; Directory listing

.include "base.i"
.include "text.i"
.include "kernel.i"

        .org $1000	; relocated at load time

.proc listdir
	ldy #DIRSCAN_CWD
	clc
next:	jsr getdirent
	bcs done
prname:	sta ptmp
	stx ptmp+1
	tya
	tax
	ldy #1
prchr:	lda (ptmp),y
	iny
	jsr cout
	dex
	bne prchr
tab:	lda #' '
	jsr cout
	jsr getxy
	txa
	and #7
	bne tab
	sec
	bcs next	; always taken
done:	jsr getxy
	txa		; already at start of line? skip cr
	beq ret
	jsr crout
ret:	rts
.endproc