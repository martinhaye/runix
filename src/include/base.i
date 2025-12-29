; Runix base include

ptmp2	= $4
tmp	= $6
ptmp	= $8
tmp2	= $A
tmp3	= $C
zarg	= $E

; Kernel-specific zero-page
txtptre	= $FC
txtptro	= $FE
; bcd zero-page
bcd_ptr1 = $EA
bcd_ptr2 = $EC
bcd_ptr3 = $EE

;*****************************************************************************
; Rune 0 (kernel) vectors
resetrunes	= $C00+(0*3)
kfatal		= $C00+(1*3)
rdblks		= $C00+(2*3)
getdirent	= $C00+(3*3)	; clc=first, Y=dir; sec=next; ret: A/X - ent, Y - name len
dirscan		= $C00+(4*3)	; A/X - name to scan for, Y - dir to scan
  DIRSCAN_ROOT	= 0
  DIRSCAN_CWD	= 2
  DIRSCAN_RUNES	= 4
  DIRSCAN_BIN	= 6
progalloc	= $C00+(5*3)
progrun		= $C00+(6*3)
getsetcwd	= $C00+(7*3)
;*****************************************************************************
; Rune 1 (text) vectors
clrscr		= $C20+(0*3)
gotoxy		= $C20+(1*3)
cout		= $C20+(2*3)
crout		= $C20+(3*3)
prbyte		= $C20+(4*3)
rdkey		= $C20+(5*3)
getxy		= $C20+(6*3)
;*****************************************************************************
; Rune 2 (font) vectors
font_loaddefault = $C40+(0*3)
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

;*****************************************************************************
; String macros
.feature string_escapes	; so that "\n" works in strings

.macro	print	str
	.byte 0, $CB, str, 0
.endmacro

.macro	ldstr	str
	.byte 0, $DB, str, 0
.endmacro

.macro	fatal	str
	ldstr str
	jmp kfatal
.endmacro

.macro bcc_or_die str
	bcc :+
	fatal str
:
.endmacro

.macro qfatal
	brk
	.byte 0
.endmacro

;*****************************************************************************
; Long branch macros (e.g. jeq)
.MACPACK longbranch

;*****************************************************************************
; Word-based macros
.macro  ldax arg
.if (.xmatch ({arg}, {ax}))
	; already in ax - no-op
	nop
.elseif (.match (.left(1, {arg}), #))
	; immediate mode
	lda #<(.right(.tcount({arg})-1, {arg}))
	ldx #>(.right(.tcount({arg})-1, {arg}))
.elseif (.match (.left(1, {arg}), &))
	; address mode
	lda #<(.right(.tcount({arg})-1, {arg}))
	cld	; special marker to get relocator's attention
	ldx #>(.right(.tcount({arg})-1, {arg}))
.else
	; abs or zp
	lda arg
	ldx 1+(arg)
.endif
.endmacro

.macro  stax arg
	sta arg
	stx 1+(arg)
.endmacro

.macro	phax
	pha
	txa
	pha
.endmacro

.macro  plax
	pla
	tax
	pla
.endmacro

; 16-bit increment. Scrambles NZ.
.macro	incw arg
.local	skip
	inc arg
	bne skip
	inc 1+(arg)
skip:
.endmacro

; 16-bit decrement. Scrambles A and NZ.
.macro	decw arg
.local	skip
	lda arg
	bne skip
	dec 1+(arg)
skip:	dec arg
.endmacro

; Move one 16-bit to another. May scramble Y. Preserves AX
.macro	mov src, dst
.if (.match({src}, {ax}))
	; AX -> dst
	stax dst
.elseif (.xmatch({dst}, {ax}))
	; src -> AX
	ldax src
.elseif (.match(.left(1, {src}), #))
	; immediate mode # -> dst
	ldy #<(.right(.tcount({src})-1, {src}))
	sty dst
	ldy #>(.right(.tcount({src})-1, {src}))
	sty 1+(dst)
.elseif (.match(.left(1, {src}), &))
	; address mode & -> dst
	ldy #<(.right(.tcount({src})-1, {src}))
	sty dst
	cld	; special marker for relocator
	ldy #>(.right(.tcount({src})-1, {src}))
	sty 1+(dst)
.else
	; abs or zp -> dst
	ldy src
	sty dst
	ldy 1+(src)
	sty 1+(dst)
.endif
.endmacro

; Call a function with 0-3 args.
; The right-most arg (i.e. last) will be in AX; the rest will be in {func}_arg0, {func}_arg1, etc.
; Does not support variadic functions.
; Functions place the return value (if any) in AX.
.macro call func, arg0, arg1, arg2
.local arg0dst
.local arg1dst
.if .paramcount >= 5
	.error "No support yet for calling func with more than 3 params"
.elseif .paramcount = 4
    arg0dst = .ident(.concat(.string(func), "_arg0"))
    arg1dst = .ident(.concat(.string(func), "_arg1"))
	mov arg0, arg0dst
	mov arg1, arg1dst
	ldax arg2
.elseif .paramcount = 3
    arg0dst = .ident(.concat(.string(func), "_arg0"))
	mov arg0, arg0dst
	ldax arg1
.elseif .paramcount = 2
	ldax arg0
.endif
	jsr func
.endmacro

;*****************************************************************************
; Markers for self-modded code
modaddr	= $1111
modn	= $11
