; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd_fromstr:\n"

	; Test 1: Parsing a simple number "123"
	print "Test 1: '123' -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_debug, &bcd_result
	jsr crout

	; Test 2: Printing a number
	print "Test 2: '123' -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Test 3: Printing a number that has leading zeros
	print "Test 3: '00123' -> "
	ldstr "00123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Test 4: simple increment
	print "Test 4: inc 123 -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Test 5: complex increment
	print "Test 5: inc 99 -> "
	ldstr "99"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	print "\nAll tests complete.\n"
	jmp $FFF9

;*****************************************************************************
; Data storage
;*****************************************************************************
bcd_result_p = *+1
	bit bcd_result

bcd_result:	.res 16		; Space for BCD result (FF-terminated)
