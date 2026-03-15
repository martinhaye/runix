; Just echo a string

.include "base.i"
.include "text.i"

        .org $1000	; relocated at load time

.proc echo
	sta ptmp
	stx ptmp+1
	ldy #0
	lda (ptmp),y
	beq done
	tax
prchr:	iny
	lda (ptmp),y
	jsr cout
	dex
	bne prchr
done:	jmp crout
.endproc
