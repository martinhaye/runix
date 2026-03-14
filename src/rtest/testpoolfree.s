; Pool free characterization test

.include "base.i"
.include "text.i"
.include "pool.i"

	.org $1000

main:
	print "Testing pool free:\n"
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
	pool_getptr obj1
	print "T1: %s\n"
	print "T2: free\n"
	pool_free obj1
	pool_total
	print "T3: unexpected success\n"
	rts

	.byte 0,0,0
obj1:	.byte 0
