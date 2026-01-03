; Directory listing

.include "base.i"
.include "kernel.i"
.include "text.i"

        .org $1000	; relocated at load time

.proc chdir
	; check for ".."
	sta ptmp
	stx ptmp+1
	ldy #0
	lda (ptmp),y
	cmp #2
	bne ndots
	ldx #2
	iny
	lda (ptmp),y
	cmp #'.'
	bne ndots
	iny
	lda (ptmp),y
	cmp #'.'
	beq dotdot
ndots:	lda ptmp
	ldy #DIRSCAN_CWD
	clc
	jsr dirscan
	bcc found
	print "Error: directory not found.\n"
	rts
found:	cpy #$F8
	beq isdir
	print "Error: not a directory file.\n"
	rts
isdir:	sec
	jmp getsetcwd	; change working dir
dotdot:	clc
	jsr getsetcwd
	cmp #1
	bne noroot
	cpx #0
	beq isroot
noroot:	ldy #1
	sty zarg	; read 1 blk (the dir)
	bit blkbuf
	ldy *-1
	jsr rdblks
	lda blkbuf	; parent blk num
	ldx blkbuf+1
	sec
	jmp getsetcwd
isroot:	print "Error: already at /\n"
	rts
.endproc

	.align 256
blkbuf:	.res 512