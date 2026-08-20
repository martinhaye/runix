; Fatal-path characterization test
; @test keys cd rtest\ntestfatal\n
; @test max_instructions 100000
; @test expect Before fatal.
; @test expect Fatal error: fatal-path-ok

.include "base.i"
.include "kernel.i"

	.org $1000

.proc main
	print "Before fatal.\n"
	fatal "fatal-path-ok"
.endproc
