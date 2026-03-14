; String formatting characterization test

.include "base.i"

	.org $1000

.proc main
	print "Testing strings:\n"

	ldstr "inline literal"
	print "T1: %s\n"

	ldax &p31
	print "T2: %s\n"

	ldax &p32
	print "T3: %s\n"

	jmp $FFF9
.endproc

	.byte 0,0,0
p31:	.byte 31, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
p32:	.byte 32, "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", '!', 0
