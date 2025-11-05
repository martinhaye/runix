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
resetrunes	= $C00
kfatal		= $C03
rdblks		= $C06
dirscan		= $C09
;*****************************************************************************
; Rune 1 (text) vectors
clrscr		= $C20
gotoxy		= $C23
cout		= $C26
crout		= $C29
prbyte		= $C2C

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