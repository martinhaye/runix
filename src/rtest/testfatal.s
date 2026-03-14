; Fatal-path characterization test

.include "base.i"
.include "kernel.i"

	.org $1000

.proc main
	print "Before fatal.\n"
	fatal "fatal-path-ok"
.endproc
