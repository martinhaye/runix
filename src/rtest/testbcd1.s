; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd:\n"

	; Parsing a simple number "123"
	print "T1: '123'->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_debug, &bcd_result
	jsr crout

	; Parsing negative number
	print "T1b: '-1234'->"
	ldstr "-1234"
	call bcd_fromstr, ax, &bcd_result
	call bcd_debug, &bcd_result
	jsr crout

	; Printing a number
	print "T2: '123'->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Printing negative number
	print "T2b: '-123'->"
	ldstr "-123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Printing a number that has leading zeros
	print "T3: '00123'->"
	ldstr "00123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Printing just zero
	print "T3b: '0'->"
	ldstr "0"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; simple increment
	print "T4: inc 123->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; increment neg
	print "T4b: inc -123->"
	ldstr "-123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; increment neg to zero
	print "T4c: inc -1->"
	ldstr "-1"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; complex increment
	print "T5: inc 99->"
	ldstr "99"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; bigger increment
	print "T6: inc 99999->"
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; simple decrement
	print "T7: dec 123->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_dec, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; bigger decrement
	print "T8: dec 10000->"
	ldstr "10000"
	call bcd_fromstr, ax, &bcd_result
	call bcd_dec, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; decrement below zero
	print "T9: dec 0->"
	ldstr "0"
	call bcd_fromstr, ax, &bcd_result
	call bcd_dec, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare eq
	print "T10: cmp 123 vs 123->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_cmp, &bcd_result, &bcd_result
	jsr prbyte
	jsr crout

	; compare lt
	print "T11: cmp 122 vs 123->"
	ldstr "12"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	jsr prbyte
	jsr crout

	; compare gt
	print "T12: cmp 123 vs 122->"
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "122"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	jsr prbyte
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
