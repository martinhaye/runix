; Hello world demo

.include "base.i"

; all programs org at $1000 but are transparently relocated at load time
        .org $1000

	print	"Hello.\n"
        rts
