; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd:\n"

	; short multiply
	print "Test 18: 23 * 45 -> "
	ldstr "23"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "45"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; short multiply
	print "Test 19: 93 * 84 -> "
	ldstr "93"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "84"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; longer multiply
	print "Test 20: 123 * 45 -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "45"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; longer multiply
	print "Test 21: 12 * 345 -> "
	ldstr "12"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "345"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; big ol multiply
	print "Test 22: 12345 * 87654 -> "
	ldstr "12345"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "87654"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	print "\nAll tests complete.\n"
	jmp $FFF9

;*****************************************************************************
; Data storage
;*****************************************************************************
		.align 256
bcd_result:	.res 16		; Space for BCD result (FF-terminated)
bcd_num1:	.res 16
bcd_num2:	.res 16
