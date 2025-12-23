; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd:\n"

	; compare add - same len
	print "T13: 123+456->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "456"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len
	print "T14: 99999+3->"
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len aligned differently
	print "T15: 999999+3->"
	ldstr "999999"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len the other direction
	print "T16: 4+9999->"
	ldstr "4"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "9999"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len the other direction
	print "T17: 5+99999->"
	ldstr "5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare sub - same len
	print "T18: 456-123->"
	ldstr "456"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare sub - diff len
	print "T19: 1000-3->"
	ldstr "1000"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare sub - diff len aligned differently
	print "T20: 10000-4->"
	ldstr "10000"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "4"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; short multiply
	print "T21: 23*45->"
	ldstr "23"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "45"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; short multiply
	print "T22: 93*84->"
	ldstr "93"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "84"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; longer multiply
	print "T23: 123*45->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "45"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; longer multiply
	print "T24: 12*345->"
	ldstr "12"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "345"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; big ol multiply
	print "T25: 12345*87654->"
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
