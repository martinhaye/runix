; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd:\n"

	; add - same len
	print "T13: 123 + 456 = "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "456"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; add - diff len
	print "T14: 99999 + 3 = "
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; add - diff len aligned differently
	print "T15: 999999 + 3 = "
	ldstr "999999"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; add - diff len the other direction
	print "T16: 4 + 9999 = "
	ldstr "4"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "9999"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; add - diff len the other direction
	print "T17: 5 + 99999 = "
	ldstr "5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; add - signed but both neg
	print "T18: -5 + -3 = "
	ldstr "-5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "-3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; add - signed dir1
	print "T19a: 5 + -3 = "
	ldstr "5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "-3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotsp

	; add - signed dir1 with underflow
	print "T19b: 5 + -8 = "
	ldstr "5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "-8"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; add - signed dir2
	print "T20a: -5 + 2 = "
	ldstr "-5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "2"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotsp

	; add - signed dir2 with underflow
	print "T20b: -5 + 8 = "
	ldstr "-5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "8"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; sub - same len
	print "T21: 456 - 123 = "
	ldstr "456"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; sub - diff len
	print "T22: 1000 - 3 = "
	ldstr "1000"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; sub - diff len aligned differently
	print "T23: 10000 - 4 = "
	ldstr "10000"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "4"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; sub - signed but both neg
	print "T24a: -5 - -3 = "
	ldstr "-5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "-3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotsp

	; sub - signed, both neg, with underflow
	print "T24b: -5 - -8 = "
	ldstr "-5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "-8"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; sub - signed dir1
	print "T25a: -5 - 3 = "
	ldstr "-5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotsp

	; sub - signed dir2
	print "T25b: 5 - -8 = "
	ldstr "5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "-8"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; multiply by short
	print "T26: 123 * 45 = "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "45"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; multiply by short the other way
	print "T27: 12 * 345 = "
	ldstr "12"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "345"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; big ol multiply
	print "T28: 12345 * 87654 = "
	ldstr "12345"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "87654"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; signed mul
	print "T29a: -2 * 3 = "
	ldstr "-2"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	; signed mul - both neg
	print "T29b: -2 * -3 = "
	ldstr "-2"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "-3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_mul, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr dotcr

	print "\nAll tests complete.\n"
	jmp $FFF9

.proc dotcr
	lda #'.'
	jsr cout
	jmp crout
.endproc

.proc dotsp
	lda #'.'
	jsr cout
	lda #' '
	jmp cout
.endproc

;*****************************************************************************
; Data storage
;*****************************************************************************
		.align 256
bcd_result:	.res 16		; Space for BCD result (FF-terminated)
bcd_num1:	.res 16
bcd_num2:	.res 16
