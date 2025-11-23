; Directory listing

.include "base.i"

        .org $1000	; relocated at load time

.proc chdir
	; A/X is already pointing to the arg - scan for it
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
.endproc
