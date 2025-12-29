; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd:\n"

	; Printing a number
	print "T1: '123'"
	bcd_load "123", &bcd_result
	print " = %D.\n"

	; Printing negative number
	print "T2: '-123'"
	bcd_load "-123", &bcd_result
	print " = %D.\n"

	; Printing a number that has leading zeros
	print "T3a: '00123'"
	bcd_load "00123", &bcd_result
	print " = %D.\n"

	; Printing just zero
	print "T3b: '0'"
	bcd_load "0", &bcd_result
	print " = %D.\n"

	; simple increment
	print "T4a: inc 123"
	bcd_load "123", &bcd_result
	call bcd_inc, &bcd_result
	print " = %D.\n"

	; increment neg
	print "T4b: inc -123"
	bcd_load "-123", &bcd_result
	call bcd_inc, &bcd_result
	print " = %D.\n"

	; increment neg to zero
	print "T4c: inc -1"
	bcd_load "-1", &bcd_result
	call bcd_inc, &bcd_result
	print " = %D.\n"

	; complex increment
	print "T5: inc 99"
	bcd_load "99", &bcd_result
	call bcd_inc, &bcd_result
	print " = %D.\n"

	; bigger increment
	print "T6: inc 99999"
	bcd_load "99999", &bcd_result
	call bcd_inc, &bcd_result
	print " = %D.\n"

	; simple decrement
	print "T7: dec 123"
	bcd_load "123", &bcd_result
	call bcd_dec, &bcd_result
	print " = %D.\n"

	; bigger decrement
	print "T8: dec 10000"
	bcd_load "10000", &bcd_result
	call bcd_dec, &bcd_result
	print " = %D.\n"

	; decrement below zero
	print "T9: dec 0"
	bcd_load "0", &bcd_result
	call bcd_dec, &bcd_result
	print " = %D.\n"

	; compare eq
	print "T10: cmp 123 vs 123"
	bcd_load "123", &bcd_result
	call bcd_cmp, &bcd_result, &bcd_result
	print " = %x.\n"

	; compare lt
	print "T11a: cmp 122 vs 123"
	bcd_load "12", &bcd_num1
	bcd_load "123", &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	print " = %x.\n"

	; compare signed lt
	print "T11b: cmp -12 vs 12"
	bcd_load "-12", &bcd_num1
	bcd_load "12", &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	print " = %x.\n"

	; compare gt
	print "T12a: cmp 123 vs 122"
	bcd_load "123", &bcd_num1
	bcd_load "122", &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	print " = %x.\n"

	; compare signed gt
	print "T12b: cmp 12 vs -12"
	bcd_load "12", &bcd_num1
	bcd_load "-12", &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	print " = %x.\n"

	; compare both neg
	print "T12c: cmp -12 vs -13"
	bcd_load "-12", &bcd_num1
	bcd_load "-13", &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	print " = %x.\n"

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
