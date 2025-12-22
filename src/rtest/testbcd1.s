; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd:\n"

	; Parsing a simple number "123"
	print "Test 1: '123' -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_debug, &bcd_result
	jsr crout

	; Parsing negative number
	print "Test 1b: '-1234' -> "
	ldstr "-1234"
	call bcd_fromstr, ax, &bcd_result
	call bcd_debug, &bcd_result
	jsr crout

	; Printing a number
	print "Test 2: '123' -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Printing negative number
	print "Test 2b: '-123' -> "
	ldstr "-123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Printing a number that has leading zeros
	print "Test 3: '00123' -> "
	ldstr "00123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Printing just zero
	print "Test 3b: '0' -> "
	ldstr "0"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; simple increment
	print "Test 4: inc 123 -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; complex increment
	print "Test 5: inc 99 -> "
	ldstr "99"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; bigger increment
	print "Test 6: inc 99999 -> "
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_result
	call bcd_inc, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare eq
	print "Test 7: cmp 123 vs 123 -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_cmp, &bcd_result, &bcd_result
	jsr prbyte
	jsr crout

	; compare lt
	print "Test 8: cmp 122 vs 123 -> "
	ldstr "12"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	jsr prbyte
	jsr crout

	; compare gt
	print "Test 9: cmp 123 vs 122 -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "122"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_cmp, &bcd_num1, &bcd_num2
	jsr prbyte
	jsr crout

	; compare add - same len
	print "Test 10: 123 + 456 -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "456"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len
	print "Test 11: 99999 + 3 -> "
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len aligned differently
	print "Test 12: 999999 + 3 -> "
	ldstr "999999"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len the other direction
	print "Test 13: 4 + 9999 -> "
	ldstr "4"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "9999"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare add - diff len the other direction
	print "Test 14: 5 + 99999 -> "
	ldstr "5"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "99999"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_add, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare sub - same len
	print "Test 15: 456 - 123 -> "
	ldstr "456"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "123"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare sub - diff len
	print "Test 16: 1000 - 3 -> "
	ldstr "1000"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "3"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; compare sub - diff len aligned differently
	print "Test 17: 10000 - 4 -> "
	ldstr "10000"
	call bcd_fromstr, ax, &bcd_num1
	ldstr "4"
	call bcd_fromstr, ax, &bcd_num2
	call bcd_sub, &bcd_num1, &bcd_num2, &bcd_result
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
