; Pool rune characterization test

.include "base.i"
.include "text.i"
.include "pool.i"

	.org $1000

test_pool:
	print "Testing pool:\n"

	; Test 1: Init a pool and allocate one object
	pool_init
	pool_alloc #5
	sty obj1
	stax ptmp
	ldy #1
	lda #'H'
	sta (ptmp),y
	iny
	lda #'E'
	sta (ptmp),y
	iny
	lda #'L'
	sta (ptmp),y
	iny
	lda #'L'
	sta (ptmp),y
	iny
	lda #'O'
	sta (ptmp),y
	pool_total
	sta tmp
	stx tmp+1
	sty tmp2
	print "T1: id="
	lda obj1
	ldx #0
	print "%x "
	lda tmp
	ldx tmp+1
	print "tot=%x "
	lda tmp2
	ldx #0
	print "np=%x\n"

	; Test 2: re-fetch the object via obj id
	pool_getptr obj1
	print "T2: %s\n"

	rts

;*****************************************************************************
; Data storage
;*****************************************************************************
	.byte 0,0,0
obj1:	.byte 0
