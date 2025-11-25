; Test the cat utility
; Runs: cat hello.txt

.include "base.i"

        .org $1000	; relocated at load time

.proc cattest
	; Run cat with "hello.txt" as argument
	ldstr "cat"
	lda #<argstr
	ldx #>argstr
	sta zarg
	stx zarg+1
	jsr progrun
	bcc ok
	print "Failed to run cat\n"
ok:	rts
.endproc

argstr:	.byte 9, "hello.txt"  ; length-prefixed string
