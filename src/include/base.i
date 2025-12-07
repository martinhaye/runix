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
bcd_ptr = $EE

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
bcd_len		= $C60+(0*3)
bcd_fromstr	= $C60+(1*3)
  bcd_fromstr_arg0 = bcd_ptr

;*****************************************************************************
; String macros
.feature string_escapes	; so that "\n" works in strings

.macro	print	str
	.byte 0, str, 0
.endmacro

; note! ldstr can only handle len 1-31, and I couldn't figure out how to
; get ca65 to enforce it
.macro	ldstr	str
	.byte 0, .strlen(str), str
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
.if (.match ({arg}, ax))
	; already in ax - no-op
.elseif (.match (.left (1, {arg}), #))
	; immediate mode
	lda #<(.right (.tcount ({arg})-1, {arg}))
	ldx #>(.right (.tcount ({arg})-1, {arg}))
.else
	; assume absolute or zero page
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

.macro	incw arg
.local	skip
	inc arg
	bne skip
	inc 1+(arg)
skip:
.endmacro

; Move one 16-bit to another. May scramble Y. Preserves AX
.macro	mov src, dst
.if (.match({src}, ax))
	; AX -> dst
	stax dst
.elseif (.match({dst}, ax))
	; src -> AX
	ldax src
.elseif (.match(.left(1, {src}), #))
	; immediate mode # -> dst
	ldy #<(.right(.tcount({src})-1, {src}))
	sty dst
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
