; BCD Rune Test Program

.include "base.i"

	.org $1000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "Testing bcd_fromstr:\n"

	; Parsing a simple number "123"
	print "Test 1: '123' -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_debug, &bcd_result
	jsr crout

	; Printing a number
	print "Test 2: '123' -> "
	ldstr "123"
	call bcd_fromstr, ax, &bcd_result
	call bcd_print, &bcd_result
	jsr crout

	; Printing a number that has leading zeros
	print "Test 3: '00123' -> "
	ldstr "00123"
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
	call bcd_add, &bcd_num1, &bcd_num2
	call bcd_print, &bcd_num1

	print "\nAll tests complete.\n"
	jmp $FFF9

;*****************************************************************************
; Data storage
;*****************************************************************************
bcd_result:	.res 16		; Space for BCD result (FF-terminated)
bcd_num1:	.res 16
bcd_num2:	.res 16
