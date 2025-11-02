; Runix kernel
; Loads at $0E00

	.org $0E00

tmp	= $6

txtptre	= $F2
txtptro	= $F4

CWRTON	= $C0DB
CWRTOFF	= $C0DA
CB2CTRL	= $FFEC
CB2INT	= $FFED

;*****************************************************************************
.proc startup
	jsr clrscr
	ldy #0
@lup:	lda welcome,y
	beq @done
	jsr cout
	iny
	bne @lup
	jsr showallchars
@done:	jsr trycharmap
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
.proc cout
; Write one character to the text screen. Advances cursx (and cursy if end of
; line)
; In:	A - char to write (hi bit ignored)
; Out:	Preserves A/X/Y
	stx xsav
	sty ysav
	pha
	ldy cursx
	cmp #$D
	beq crout2
	ora #$80
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
; data
cursx:		.byte 0
cursy:		.byte 0
xsav:		.byte 0
ysav:		.byte 0

welcome: .byte "RUNIX 1.0",$D,0