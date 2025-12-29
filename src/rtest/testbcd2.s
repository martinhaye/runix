; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd:\n"

	; add - same len
	print "T13: 123 + 456"
	bcd_load "123", &bcd_num1
	bcd_load "456", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; add - diff len
	print "T14: 99999 + 3"
	bcd_load "99999", &bcd_num1
	bcd_load "3", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; add - diff len aligned differently
	print "T15: 999999 + 3"
	bcd_load "999999", &bcd_num1
	bcd_load "3", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; add - diff len the other direction
	print "T16: 4 + 9999"
	bcd_load "4", &bcd_num1
	bcd_load "9999", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; add - diff len the other direction
	print "T17: 5 + 99999"
	bcd_load "5", &bcd_num1
	bcd_load "99999", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; add - signed but both neg
	print "T18: -5 + -3"
	bcd_load "-5", &bcd_num1
	bcd_load "-3", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; add - signed dir1
	print "T19a: 5 + -3"
	bcd_load "5", &bcd_num1
	bcd_load "-3", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D. "

	; add - signed dir1 with underflow
	print "T19b: 5 + -8"
	bcd_load "5", &bcd_num1
	bcd_load "-8", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; add - signed dir2
	print "T20a: -5 + 2"
	bcd_load "-5", &bcd_num1
	bcd_load "2", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D. "

	; add - signed dir2 with underflow
	print "T20b: -5 + 8"
	bcd_load "-5", &bcd_num1
	bcd_load "8", &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; sub - same len
	print "T21: 456 - 123"
	bcd_load "456", &bcd_num1
	bcd_load "123", &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; sub - diff len
	print "T22: 1000 - 3"
	bcd_load "1000", &bcd_num1
	bcd_load "3", &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; sub - diff len aligned differently
	print "T23: 10000 - 4"
	bcd_load "10000", &bcd_num1
	bcd_load "4", &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; sub - signed but both neg
	print "T24a: -5 - -3"
	bcd_load "-5", &bcd_num1
	bcd_load "-3", &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D. "

	; sub - signed, both neg, with underflow
	print "T24b: -5 - -8"
	bcd_load "-5", &bcd_num1
	bcd_load "-8", &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; sub - signed dir1
	print "T25a: -5 - 3"
	bcd_load "-5", &bcd_num1
	bcd_load "3", &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D. "

	; sub - signed dir2
	print "T25b: 5 - -8"
	bcd_load "5", &bcd_num1
	bcd_load "-8", &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; multiply by short
	print "T26: 123 * 45"
	bcd_load "123", &bcd_num1
	bcd_load "45", &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; multiply by short the other way
	print "T27: 12 * 345"
	bcd_load "12", &bcd_num1
	bcd_load "345", &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; big ol multiply
	print "T28: 12345 * 87654"
	bcd_load "12345", &bcd_num1
	bcd_load "87654", &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; signed mul
	print "T29a: -2 * 3"
	bcd_load "-2", &bcd_num1
	bcd_load "3", &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	; signed mul - both neg
	print "T29b: -2 * -3"
	bcd_load "-2", &bcd_num1
	bcd_load "-3", &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	print " = %D.\n"

	print "\nAll tests complete.\n"
	jmp $FFF9

;*****************************************************************************
; Data storage
;*****************************************************************************
		.align 256
bcd_result:	.res 16		; Space for BCD result (FF-terminated)
bcd_num1:	.res 16
bcd_num2:	.res 16
