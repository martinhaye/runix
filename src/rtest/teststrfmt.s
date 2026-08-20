; String formatting characterization test
; @test keys cd rtest\nteststrfmt\nhalt\n
; @test max_instructions 100000
; @test stop success
; @test expect Testing strings:
; @test expect T1: inline literal
; @test expect T2: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
; @test expect T3: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB

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
p32:	.byte 32, "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", '!'
