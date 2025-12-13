; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	nop
	print "Testing bcd_fromstr:\n"

	; Test 1: Simple number "123"
	print "Test 1: '123' -> "

	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_debug, &bcd_result
	jsr crout

	print "\nAll tests complete.\n"
	rts

;*****************************************************************************
; Data storage
;*****************************************************************************
bcd_result_p = *+1
	bit bcd_result

bcd_result:	.res 16		; Space for BCD result (FF-terminated)
