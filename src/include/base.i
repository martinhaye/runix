; Runix base include

ptmp2	= $4
tmp	= $6
ptmp	= $8
tmp2	= $A
tmp3	= $C
zarg	= $E

; Kernel-specific zero-page
txtptre	= $F2
txtptro	= $F4

;*****************************************************************************
; Rune 0 (kernel) vectors
resetrunes	= $C00+(0*3)
kfatal		= $C00+(1*3)
rdblks		= $C00+(2*3)
dirscan		= $C00+(3*3)
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
; String macros
.feature string_escapes	; mostly so "\n" works in strings

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