; BCD Rune Test Program

.include "base.i"
.include "text.i"
.include "pool.i"

	.org $1000

test_pool:
	print "Testing pool:\n"

	; Test 1: Init a pool and allocate one object
	print "T1: "
	pool_init
	pool_alloc #5
	pool_total
	; print total bytes and number of pages
	print "tot=%x "
	tya
	ldx #0
	print "np=%x\n"
	rts

;*****************************************************************************
; Data storage
;*****************************************************************************
	.byte 0,0,0
