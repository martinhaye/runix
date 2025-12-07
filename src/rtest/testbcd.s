; BCD Rune Test Program

.include "base.i"

	.org $2000

;*****************************************************************************
; Test bcd_fromstr - convert string to BCD
;*****************************************************************************
test_fromstr:
	print "\nTesting bcd_fromstr:\n"

	; Test 1: Simple number "123"
	print "Test 1: '123' -> "
	ldstr "123"
	call bcd_fromstr, bcd_ptr, bcd_result
	jsr print_bcd
	print "\n"

	; Test 2: Single digit "5"
	print "Test 2: '5' -> "
	ldstr "5"
	call bcd_fromstr, bcd_ptr, bcd_result
	jsr print_bcd
	print "\n"

	; Test 3: Larger number "456789"
	print "Test 3: '456789' -> "
	ldstr "456789"
	call bcd_fromstr, bcd_ptr, bcd_result
	jsr print_bcd
	print "\n"

	; Test 4: Even number of digits "1234"
	print "Test 4: '1234' -> "
	ldstr "1234"
	call bcd_fromstr, bcd_ptr, bcd_result
	jsr print_bcd
	print "\n"

	; Test 5: Zero
	print "Test 5: '0' -> "
	ldstr "0"
	call bcd_fromstr, bcd_ptr, bcd_result
	jsr print_bcd
	print "\n"

	print "\nAll tests complete.\n"
	jmp $FFF9		; halt simulation

;*****************************************************************************
; print_bcd - Print BCD number in hex format
; Input: bcd_result contains BCD number (FF-terminated)
;*****************************************************************************
.proc print_bcd
	ldx #0
loop:	lda bcd_result,x
	cmp #$FF
	beq done
	; Print byte in hex
	pha
	lsr
	lsr
	lsr
	lsr
	jsr print_hex_digit
	pla
	and #$0F
	jsr print_hex_digit
	inx
	cpx #16			; safety limit
	bne loop
done:	rts
.endproc

;*****************************************************************************
; print_hex_digit - Print a single hex digit (0-F)
; Input: A = digit (0-15)
;*****************************************************************************
.proc print_hex_digit
	cmp #10
	bcc is_digit
	; A-F
	adc #('A'-11)	; carry is set, so this adds ('A'-10)
	jmp print_char
is_digit:
	adc #'0'
print_char:
	ldx #0
	print "%c"
	rts
.endproc

;*****************************************************************************
; Data storage
;*****************************************************************************
.segment "BSS"
bcd_result:	.res 16		; Space for BCD result (FF-terminated)
