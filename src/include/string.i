
;*****************************************************************************
; str_len(pstr) -> X
; 	Calculate length of string, return in X reg
.macro str_len pstr
	ldax pstr
	jsr v_str_len
.endmacro

;*****************************************************************************
; str_cpy(instr, outstr) -> outstr (for chaining)
; 	Copy a string, up to 255 chars
.macro str_cpy instr, outstr
	ldax instr
	stax str_ptr1
	ldax outstr
	ldy #$FF	; max len
	jsr v_str_cpy
.endmacro

;*****************************************************************************
; str_ncpy(instr, outstr) -> outstr (for chaining)
; 	Copy a string with specified max buffer size
.macro str_ncpy instr, maxlen, outstr
	ldax instr
	stax str_ptr1
	ldy #maxlen
	ldax outstr
	jsr v_str_cpy
.endmacro

;*****************************************************************************
; str_split_first(instr, delim, outstr) -> nextpos, C (clc for more)
; str_split_next(nextpos, delim, outstr) -> nextpos, C (clc for more)
; 	Split a string on a single delimiter character. Use in this pattern:
;		str_split_first mybuf, '-', tokptr
;		bcs done
;	loop:	stax mynextpos
;		; do work with tokptr here
;		str_split_next mynextpos, '-', tokptr
;		bcc loop
;	done:	...
.macro str_split_first instr, delim, outstr
	ldax instr
	stax str_ptr1
	ldy #delim
	ldax outstr
	clc
	jsr v_str_split
.endmacro
.macro str_split_next nextpos, delim, outstr
	ldax nextpos
	stax str_ptr1
	ldy #delim
	ldax outstr
	sec
	jsr v_str_split
.endmacro

; vectors (don't call directly; use macros above)
v_str_len	= string_vecs + (0*3)
v_str_cpy	= string_vecs + (1*3)
v_str_split	= string_vecs + (2*3)
