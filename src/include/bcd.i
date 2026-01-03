;*****************************************************************************
; Rune 3 (bcd) vectors
bcd_fromstr	= $C60+(0*3)	; call bcd_fromstr src, dst
  bcd_fromstr_arg0 = bcd_ptr1
bcd_print	= $C60+(1*3)
bcd_inc		= $C60+(2*3)
bcd_dec		= $C60+(3*3)
bcd_cmp		= $C60+(4*3)
  bcd_cmp_arg0	= bcd_ptr1
bcd_add		= $C60+(5*3)
  bcd_add_arg0	= bcd_ptr1
  bcd_add_arg1	= bcd_ptr2
bcd_sub		= $C60+(6*3)
  bcd_sub_arg0	= bcd_ptr1
  bcd_sub_arg1	= bcd_ptr2
bcd_mul		= $C60+(7*3)
  bcd_mul_arg0	= bcd_ptr1
  bcd_mul_arg1	= bcd_ptr2

; Load a BCD number from a string. Call like this:
;	bcd_load "123", &mynum
.macro bcd_load str, dst
	ldstr str
	call bcd_fromstr, ax, dst
.endmacro
