; Pool resize characterization test
; @test keys cd rtest\ntestpoolrz\nhalt\n
; @test max_instructions 100000
; @test stop success
; @test expect Testing pool resize:
; @test expect T1: HELLO
; @test expect T2: resize
; @test expect T3: unexpected success

.include "base.i"
.include "text.i"
.include "pool.i"

	.org $1000

main:
	print "Testing pool resize:\n"
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
	print "T2: resize\n"
	pool_resize obj1, #7
	pool_total
	print "T3: unexpected success\n"
	rts

	.byte 0,0,0
obj1:	.byte 0
