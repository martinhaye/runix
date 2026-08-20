; BCD Rune Test Program
; @test keys cd rtest\ntestbcd1\nhalt\n
; @test max_instructions 500000
; @test stop success
; @test expect T1: '123' = 123.
; @test expect T2: '-123' = -123.
; @test expect T3a: '00123' = 123.
; @test expect T3b: '0' = 0.
; @test expect T4a: inc 123 = 124.
; @test expect T4b: inc -123 = -122.
; @test expect T4c: inc -1 = 0.
; @test expect T5: inc 99 = 100.
; @test expect T6: inc 99999 = 100000.
; @test expect T7: dec 123 = 122.
; @test expect T8: dec 10000 = 9999.
; @test expect T9: dec 0 = -1.
; @test expect T10: cmp 123 vs 123 = $00.
; @test expect T11a: cmp 122 vs 123 = $FFFF.
; @test expect T11b: cmp -12 vs 12 = $FFFF.
; @test expect T12a: cmp 123 vs 122 = $01.
; @test expect T12b: cmp 12 vs -12 = $01.
; @test expect T12c: cmp -12 vs -13 = $01.

.include "base.i"
.include "text.i"
.include "bcd.i"

	.org $1000

;*****************************************************************************
; Test bcd
;*****************************************************************************
test_bcd:
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

;*****************************************************************************
; Data storage
;*****************************************************************************
		.align 256
bcd_result:	.res 16		; Space for BCD result (FF-terminated)
bcd_num1:	.res 16
bcd_num2:	.res 16
