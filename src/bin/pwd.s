; Print current working dir

.include "base.i"

        .org $1000	; relocated at load time

.proc printall
	clc
	jsr getsetcwd	; save original cwd
	pha
	txa
	pha
loop:	jsr printone
	bcc loop
	jsr crout
	pla		; back to original cwd
	tax
	pla
	jmp getsetcwd
.endproc

.proc printone
	lda #'/'
	jsr cout
	clc
	jsr getsetcwd
	cmp #1
	bne noroot
	cpx #0
	bne noroot
isroot:	sec
	rts
noroot:	sta subdirblk
	stx subdirblk+1
	ldy #1
	sty zarg
	bit blkbuf
	ldy *-1		; hi byte of blk buf
	jsr rdblks
	lda blkbuf	; read parent blk num
	ldx blkbuf+1
	sec
	jsr getsetcwd
	ldy #DIRSCAN_CWD
	clc
getent:	jsr getdirent
	bcs notfnd
scan:	sta ptmp
	stx ptmp+1
	iny
	lda (ptmp),y
	cmp subdirblk
	bne next
	iny
	lda (ptmp),y
	cmp subdirblk+1
	beq found
next:	sec
	bcs getent	; always taken
found:	ldy #0
	lda (ptmp),y
	tax
prchr:	iny
	lda (ptmp),y
	jsr cout
	dex
	bne prchr
	clc
	rts
notfnd:	fatal "dir not found in parent"
subdirblk = *+1
	bit $1111
.endproc

	.align 256
blkbuf:	.res 512
