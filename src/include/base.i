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
; string zero-page
str_ptr1 = $E6
str_ptr2 = $E8
; pool zero-page
_pool_zp = $E2	; len 4

;*****************************************************************************
; Rune vectors
kernel_vecs	= $C00
text_vecs	= $C20
font_vecs	= $C40
bcd_vecs	= $C60
str_vecs	= $C80
pool_vecs	= $CA0

;*****************************************************************************
; Essential printing/loading of strings
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

; Get a value into the A reg
.macro	ld_a src
    .if (.xmatch({src}, {a}))
	; already in A - do nothing
    .elseif (.xmatch({src}, {x}))
	txa
    .elseif (.xmatch({src}, {y}))
	tya
    .else
	lda src
    .endif
.endmacro

; Get a value into the X reg
.macro	ld_x src
    .if (.xmatch({src}, {x}))
	; already in X - do nothing
    .elseif (.xmatch({src}, {a}))
	tax
    .elseif (.xmatch({src}, {y}))
	tya
	tax
    .else
	ldx src
    .endif
.endmacro

; Get a value into the Y reg
.macro	ld_y src
    .if (.xmatch({src}, {y}))
	; already in Y - do nothing
    .elseif (.xmatch({src}, {a}))
	tay
    .elseif (.xmatch({src}, {x}))
	txa
	tay
    .else
	ldy src
    .endif
.endmacro

;*****************************************************************************
; Markers for self-modded code
modaddr	= $1100
modn	= $11

;*****************************************************************************
; Set the V flag
k_fixed_rts = $E01	; kernel starts with "bit $60" for this purpose
.macro set_v
	bit k_fixed_rts
.endmacro
