; Runix kernel
; Loads at $0E00

	.org $0E00

tmp	= $6
ptmp	= $8
tmp2	= $A
ptmp2	= $C
pstr	= $E

txtptre	= $F2
txtptro	= $F4

CWRTON	= $C0DB
CWRTOFF	= $C0DA
CB2CTRL	= $FFEC
CB2INT	= $FFED

a2mon	= $FF65
a3mon	= $F901

;*****************************************************************************
; String macros
.feature string_escapes	; mostly so "\n" works in strings

.macro	print	str
	.byte 0, str, 0
.endmacro

.macro	ldstr	str
	.if (strlen(str) >= 32) || (strlen(str) == 0)
	.error "ldstr can only handle lengths 1..31"
	.endif
	.byte 0, .strlen(str), str
.endmacro

;*****************************************************************************
.proc startup
	; identify the platform (Apple /// or not)
	ldx #0
	lda a3mon
	cmp #$BA	; TSX on Apple /// rom
	bne @gotpl
	ldx #$80
@gotpl:	stx a3flg
	txa
	bpl @a2brk
	lda #$4C	; Apple III jumps to $FFCD on BRK/IRQ
	stx $FFCD
	lda #<brkhnd
	sta $FFCE
	lda #>brkhnd
	sty $FFCF
	bne @brkdn	; always taken
@a2brk:	lda #<a2brk
	sta $3F0	; Apple II does "JMP ($3F0)" on BRK/IRQ
	lda #>a2brk
	sta $3F1
@brkdn: jsr clrscr
	ldy #0
@lup:	lda welcome,y
	beq @done
	jsr cout
	iny
	bne @lup
@done:	lda #$A1
	ldx #$B2
	ldy #$C3
	clc
	ldx #$E0
	txs
	brk 0
	jsr showallchars
	jsr trycharmap
	inc $7D0
	jmp @done
.endproc

;*****************************************************************************
sety:	sta cursy
	; fall into bascalc...
;*****************************************************************************
.proc bascalc
; Calculate base address for a text row
; In:	cursy - row num
; Out:	txtptre - even column address (400.7FF)
;	txtptro - odd column address (800.BFF)
;
; Algorithm: $400 + ((row//8) * $28) + ((row%2) * $80) + (((row//2)%4) * $100)
	lda cursy
	lsr		; divide by 2, row%2 to carry
	pha
	php
	lsr
	lsr		; now A = row//8 (range 0-2)
	tax
	lda #0
	plp
	ror		; C -> $80; clears carry
	dex
	bmi @got
	adc #$28
	dex
	bmi @got
	adc #$28
@got:	sta txtptre
	sta txtptro
	pla		; A = row//2
	and #3
	ora #4
	sta txtptre+1
	eor #$C
	sta txtptro+1
	rts
.endproc

;*****************************************************************************
.proc clreol
; Clear current line from curx to end
; Doesn't modify cursx
	ldy cursx
	lda #$A0
@lup:	sta (txtptre),y
	iny
	cpy #40
	bne @lup
	rts
.endproc

;*****************************************************************************
.proc clrscr
; Clear entire screen
; leaves with cursx=0, cursy=0
	lda #0
	sta cursx
@loop:	jsr sety
	jsr clreol
	lda cursy
	clc
	adc #1
	cmp #24
	bne @loop
	lda #0
	jmp sety
.endproc

;*****************************************************************************
prspc:	lda #' '
	; fall into...
.proc cout
; Write one character to the text screen. Advances cursx (and cursy if end of
; line)
; In:	A - char to write (hi bit ignored)
; Out:	Preserves A/X/Y
	stx xsav
	sty ysav
	pha
	ldy cursx
	and #$7F	; ignore hi-bits if present
	cmp #$D		; traditional Apple II carriage-return ('\r')
	beq crout2
	cmp #$A		; '\n' c-style newline
	beq crout2
	ora #$80	; set hi-bit for normal non-inverse text
	sta (txtptre),y
	iny
	cpy #40
	beq crout2
	sty cursx
.endproc
	; fall into...
restregs:
	ldx xsav
	ldy ysav
	pla
	rts

;*****************************************************************************
; Advance to start of next line - scrolls if end of screen reached.
; Preserves A/X/Y
crout:	stx xsav
	sty ysav
	pha
	; fall into...
.proc crout2
	lda #0
	sta cursx
	inc cursy
	lda cursy
	cmp #24
	beq @scrl
	jsr bascalc
	jmp restregs
@scrl:	lda #0
	jsr sety
@sc1:	lda txtptre
	sta @st+1		; self-modify target
	lda txtptre+1
	sta @st+2
	inc cursy
	jsr bascalc
	ldy #39
@cp:	lda (txtptre),y
@st:	sta $1111,y		; self-modified above
	dey
	bpl @cp
	lda cursy
	cmp #23
	bne @sc1
	jsr clreol
	jmp restregs
.endproc

;*****************************************************************************
.proc prbyte
	pha
	lsr
	lsr
	lsr
	lsr
	jsr @prdig
	pla
	and #$F
@prdig:	cmp #$A
	bcs @letr
	adc #'0'
	jmp cout
@letr:	clc
	adc #'A'-$A
	jmp cout
.endproc

;*****************************************************************************
; Notes on setting character set:
;   Slot 0:
; 	878:char0-code	478:char0-pix0
; 	87C:"           47C:char0-pix1
; 	8F8:"           4F8:char0-pix2
; 	8FC:"           4FC:char0-pix3
; 	978:"           578:char0-pix4
; 	97C:"           57C:char0-pix5
; 	9F8:"           5F8:char0-pix6
; 	9FC:"           5FC:char0-pix7
;   Slot 1:
; 	879:char1-code	479:char1-pix0
; 	87D:"           47D:char1-pix1
; 	8F9:"           4F9:char1-pix2
; 	8FD:"           4FD:char1-pix3
; 	979:"           579:char1-pix4
; 	97D:"           57D:char1-pix5
; 	9F9:"           5F9:char1-pix6
; 	9FD:"           5FD:char1-pix7
;   Slot 2:
; 	87A:char2-code	47A:char2-pix0
; 	87E:"           47E:char2-pix1
; 	8FA:"           4FA:char2-pix2
; 	8FE:"           4FE:char2-pix3
; 	97A:"           57A:char2-pix4
; 	97E:"           57E:char2-pix5
; 	9FA:"           5FA:char2-pix6
; 	9FE:"           5FE:char2-pix7
;   Slot 3:
; 	87B:char3-code	47B:char3-pix0
; 	87F:"           47F:char3-pix1
; 	8FB:"           4FB:char3-pix2
; 	8FF:"           4FF:char3-pix3
; 	97B:"           57B:char3-pix4
; 	97F:"           57F:char3-pix5
; 	9FB:"           5FB:char3-pix6
; 	9FF:"           5FF:char3-pix7
;   ** break in pattern **
;   Slot 4:
; 	A78:char4-code	678:char4-pix0
; 	A7C:"           67C:char4-pix1
; 	AF8:"           6F8:char4-pix2
; 	AFC:"           6FC:char4-pix3
; 	B78:"           778:char4-pix4
; 	B7C:"           77C:char4-pix5
; 	BF8:"           7F8:char4-pix6
; 	BFC:"           7FC:char4-pix7
;   Slot 5:
; 	A79:char5-code	679:char5-pix0
; 	A7D:"           67D:char5-pix1
; 	AF9:"           6F9:char5-pix2
; 	AFD:"           6FD:char5-pix3
; 	B79:"           779:char5-pix4
; 	B7D:"           77D:char5-pix5
; 	BF9:"           7F9:char5-pix6
; 	BFD:"           7FD:char5-pix7
;   Slot 6:
; 	A7A:char6-code	67A:char6-pix0
; 	A7E:"           67E:char6-pix1
; 	AFA:"           6FA:char6-pix2
; 	AFE:"           6FE:char6-pix3
; 	B7A:"           77A:char6-pix4
; 	B7E:"           77E:char6-pix5
; 	BFA:"           7FA:char6-pix6
; 	BFE:"           7FE:char6-pix7
;   Slot 7:
; 	A7B:char7-code	67B:char7-pix0
; 	A7F:"           67F:char7-pix1
; 	AFB:"           6FB:char7-pix2
; 	AFF:"           6FF:char7-pix3
; 	B7B:"           77B:char7-pix4
; 	B7F:"           77F:char7-pix5
; 	BFB:"           7FB:char7-pix6
; 	BFF:"           7FF:char7-pix7
;
; Sequence to fire:
;	bit $C0DB	; CWRTON
;	lda #$60
;	jsr vretrace
;	lda #$20
;	jsr vretrace
;	bit $C0DA	; CWRTOFF
;	rts
; vretrace:
;	sta tmp
;	lda $FFEC	; CB2CTRL
;	and #$3F
;	ora tmp
;	sta $FFEC	; CB2CTRL
;	lda #8
;	sta $FFED	; CB2INT
; @lup:	bit $FFED	; CB2INT
;	beq @lup
;	rts

.proc trycharmap
	lda $7d0
	sta tmp
@outer:	ldx #0
@stoA:	lda tmp
	; char num (all the same)
	sta $878,x
	sta $87C,x
	sta $8F8,x
	sta $8FC,x
	sta $978,x
	sta $97C,x
	sta $9F8,x
	sta $9FC,x
	; pattern
	sta $478,x
	rol
	sta $47C,x
	rol
	sta $4F8,x
	rol
	sta $4FC,x
	rol
	sta $578,x
	rol
	sta $57C,x
	rol
	sta $5F8,x
	rol
	sta $5FC,x
	inc tmp
@stoB:	lda tmp
	; char num (all the same)
	sta $A78,x
	sta $A7C,x
	sta $AF8,x
	sta $AFC,x
	sta $B78,x
	sta $B7C,x
	sta $BF8,x
	sta $BFC,x
	; pattern
	sta $678,x
	rol
	sta $67C,x
	rol
	sta $6F8,x
	rol
	sta $6FC,x
	rol
	sta $778,x
	rol
	sta $77C,x
	rol
	sta $7F8,x
	rol
	sta $7FC,x
	inc tmp
	inx
	cpx #4
	bne @stoA

	bit CWRTON
	lda #$60
	jsr vretrace
	lda #$20
	jsr vretrace
	bit CWRTOFF
	rts
.endproc

.proc vretrace
	sta tmp
	lda CB2CTRL
	and #$3F
	ora tmp
	sta CB2CTRL
	lda #8
	sta CB2INT
@lup:	bit CB2INT
	beq @lup
	rts
.endproc

.proc showallchars
	jsr clrscr
	lda #0
	sta tmp
@row:	ldy #0
@rlup:	lda tmp
	sta (txtptre),y
	inc tmp
	iny
	cpy #16
	bne @rlup
	inc cursy
	jsr bascalc
	lda cursy
	cmp #16
	bne @row
	rts
.endproc

;*****************************************************************************
.proc reloc
; Relocator
; Input:
;	A=src page
;	X=dst/current page
;	Y=num pages
@srcpage = tmp
@dstpage = tmp+1
@npages = tmp2
@pscan = ptmp
	sta @srcpage
	stx @dstpage
	stx @pscan+1
	sty @npages
	lda #0
	sta @pscan
	tay		; Y is normally zero
@inst:	lda (@pscan),y	; read next instruction
	and #$1F	; extract just bits bbbcc
	beq @spec	; special cases if bbbcc == 0
	tax
	lda inslen_t,x	
@gotln:	cmp #3
	beq @len3
	; len < 3, so carry is now clear
@adv:	;clc		; carry is already clear when we arrive here
	adc @pscan
	sta @pscan
	bcc @inst
	inc @pscan+1
	dec @npages
	bne @inst
@stop:	rts

@spec:	lda (@pscan),y
	beq @sbrk	; special handling for BRK strings
	and #$E0	; extract bits aaa
	cmp #$20	; aaa==001 -> JSR abs (3)
	beq @len3
	cmp #$A0	; aaa>=101 -> {LDY,CPY,CPX} #imm (2)
	bcs @len2
@len1:	lda #1
	; carry is already clear
	bcc @adv	; always taken
@len2:	lda #2
	clc
	bcc @adv	; always taken

@len3:	;sec		; fyi we got here via beq, so carry is already set
	ldy #2
	lda (@pscan),y	; high byte of operand
	sbc @srcpage	; find page offset; carry already set
	bcc @skip	; before range? skip
	cmp @npages	; after range? skip
	bcs @skip
	; carry is now clear
	adc @dstpage	; adjust for new location
	sta (@pscan),y	; and store it
@skip:	lda #3		; back to 3-byte len
	ldy #0		; normal state again
	clc
	bcc @adv	; always taken

@sbrk:	iny
	lda (@pscan),y	; check 1st byte of str
	beq @bbrk	; if zero, it's a normal brk (or maybe start-of-data)
	cmp #$20
	bcc @lpfx	; if < $20, it's length-prefixed
@chkz:	iny
	lda (@pscan),y
	bne @chkz	; scan for zero-terminator
	iny		; and one past for next ins
	tya		; now we have the len
	ldy #0
	clc
	bcc @adv	; always taken

@lpfx:	sec
	adc #2		; brk + len + bytes; always clears carry since len < $20
	ldy #0		; normal mode
	bcc @adv	; always taken

@bbrk:	iny
	lda (@pscan),y	; one more byte
	beq @stop	; 3 zeros in a row --> stop relocation, data section begun
	ldy #0
	beq @len2	; otherwise, a real 2-byte brk (always taken)
.endproc

;*****************************************************************************
a2brk:	; put things back the way native brk would be
	lda $3B		; pc h
	pha
	lda $3A		; pc l
	pha
	lda $48		; preg
	pha
	lda $45		; areg
	ldx $46
	ldy $47
.proc brkhnd
	sta areg
	stx xreg
	sty yreg
	pla
	pha		; leave preg on stack
	and #$10
	beq @irq	; for now, do nothing on real IRQ
	tsx
	lda $102,x
	sec
	sbc #1
	sta pstr
	lda $103,x
	sbc #0
	sta pstr+1
	ldy #0
	lda (pstr),y
	beq @rbrk	; BRK 00 means a real brk
	cmp #$20
	bcc @adv	; < $20 means len-prefixed string; skip over it
	; otherwise, print zero-terminated string
@scanz:	jsr cout
	iny
	lda (pstr),y	; find terminator
	bne @scanz
	tya
@adv:	sec		; advance over the terminator (or over the len pfx)
	adc pstr
	sta $102,x
	bcc @ret
	inc $103,x
@ret:	lda areg
	ldx xreg
	ldy yreg
@irq:	rti

; really brk (brk 00) - print location and registers
@rbrk:	lda #22
	jsr sety
	lda #0
	sta cursx
	pla		; p reg
	tay		; save it aside
	bit a3flg
	bmi @isa3
	lda #21
	sta $25
	jsr $FD8E	; a2 crout
@isa3:	pla		; PC lo
	sbc #1		; brk advances as if a 2-byte instr
	tax
	pla		; PC hi
	sbc #0
	jsr prbyte
	txa
	jsr prbyte
	lda #':'
	jsr cout
	jsr prspc
	; print all registers
	ldx areg
	lda #'A'
	jsr @preg
	ldx xreg
	lda #'X'
	jsr @preg
	ldx yreg
	lda #'Y'
	jsr @preg
	tya		; get back the preg val
	tax
	lda #'P'
	jsr @preg
	tsx
	lda #'S'
	jsr @preg
	jsr crout
	bit a3flg	; jump to platform-specific system monitor for now
	bpl @a2
	jmp a3mon
@a2:	jmp a2mon

@preg:	jsr cout
	lda #'='
	jsr cout
	txa
	jsr prbyte
	jmp prspc
.endproc

;*****************************************************************************
; data
a3flg:	.byte 0
cursx:	.byte 0
cursy:	.byte 0
; saves used by cout:
asav:	.byte 0
xsav:	.byte 0
ysav:	.byte 0
; saves used by brkhnd:
areg:	.byte 0
xreg:	.byte 0
yreg:	.byte 0

; 32-byte unified table, indexed by bbbcc = (opcode & $1F)
; For each bbb (0..7), entries are [cc=00, cc=01, cc=10, cc=11]
inslen_t:
        .byte 1,2,2,1	; bbb=000: impl | (zp,X) |  #   | ill
        .byte 2,2,2,1	; bbb=001:  zp  |   zp   |  zp  | ill
        .byte 1,2,1,1	; bbb=002: impl |   #    |  A   | ill
        .byte 3,3,3,1	; bbb=003:  abs |  abs   | abs  | ill
        .byte 2,2,2,1	; bbb=004:  bra | (zp),Y | zp,X | ill
        .byte 2,2,2,1	; bbb=005: zp,X |  zp,X  | zp,Y | ill
        .byte 1,3,1,1	; bbb=006: impl | abs,Y  | imp  | ill
        .byte 3,3,3,1	; bbb=007: abs,X| abs,X  | abs,X| ill

; Text of welcome message
welcome: .byte "RUNIX 1.0",$D,0