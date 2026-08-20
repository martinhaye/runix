; Pool rune characterization test
; @test keys cd rtest\ntestpool\nhalt\n
; @test max_instructions 500000
; @test stop success
; @test expect T1: id=$01 tot=$06 np=$01
; @test expect T2: str=HELLO

.include "base.i"
.include "text.i"
.include "pool.i"

ptr2	= tmp3

	.org $1000

test_pool:
	print "Testing pool:\n"

	; Test 1: Init a pool and allocate one object
	print "T1: "
	pool_init
	pool_alloc #5
	sty obj1
	stax ptmp

	print "id="
	lda obj1
	ldx #0
	print "%x "

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

	jsr prtotal

	; Test 2: re-fetch the object via obj id
	print "T2: "
	pool_getptr obj1
	print "str=%s\n"

	; Test 3: Allocate a second object
	print "T3: "
	pool_alloc #3
	stax ptr2
	sty obj2
	tya
	ldx #0
	print "id=%x "
	ldax ptr2
	print "ptr=%x "

	; fill it in
	ldy #1
	lda #'A'
	sta (ptr2),y
	iny
	lda #'B'
	sta (ptr2),y
	iny
	lda #'C'
	sta (ptr2),y
	ldax ptr2
	print "str=%s\n"

	; Test 4: resize last obj
	print "T4: "
	pool_resize obj2, #4
	stax ptr2
	print "p=%x "
	ldy #4
	lda #'D'
	sta (ptr2),y
	ldax ptr2
	print "str=%s "
	jsr prtotal

	; Test 5: resize non-last obj
	print "T5a: "
	pool_resize obj1, #4
	stax ptmp
	print "p=%x "
	jsr prtotal
	print "T5b: "
	pool_getptr obj1
	print "p=%x "
	print "str=%s "
	jsr crout
	print "T5c: "
	pool_getptr obj2
	print "p2=%x "
	print "str=%s "
	jsr crout

	rts

.proc prtotal
	pool_total
	php
	sty tmp2
	print "tot=%x "
	lda tmp2
	ldx #0
	print "np=%x "
	print "C="
	pla
	and #1
	ora #$B0
	jsr cout
	jmp crout
.endproc

;*****************************************************************************
; Data storage
;*****************************************************************************
	.byte 0,0,0
obj1:	.byte 0
obj2:	.byte 0