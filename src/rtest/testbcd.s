; BCD Rune Test Program

.include "base.i"

	.org $2000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd_fromstr:\n"

	; Test 1: Simple number "123"
	print "Test 1: '123' -> "
	;call bcd_fromstr, "123", &bcd_result
	;call bcd_debug, &bcd_result
	jsr crout

	print "\nAll tests complete.\n"
	jmp $FFF9		; halt simulation

;*****************************************************************************
; Data storage
;*****************************************************************************
bcd_result:	.res 16		; Space for BCD result (FF-terminated)
