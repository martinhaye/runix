; Rune 2 - Font services
; Jump vectors at $C40-$C5F

        .org $2000

.include "base.i"

; Hardware addresses
CWRTON	= $C0DB
CWRTOFF	= $C0DA
CB2CTRL	= $FFEC
CB2INT	= $FFED

	; API jump vectors
	jmp load_default_font
	.align 32,$EA

;*****************************************************************************
load_default_font:
	; test code for now
	jsr showallchars
@try:	jsr trycharmap
	lda $7D0
	clc
	adc #8
	sta $7D0
	jmp @try	; loop forever

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

;*****************************************************************************
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

	lda CWRTON
	lda #$60
	jsr @vretr
	lda #$20
	jsr @vretr
	lda CWRTOFF
	rts

@vretr:	sta @or+1	; mod self below
	lda CB2CTRL
	and #$1F
@or:	ora #$22	; self-mod above
	sta CB2CTRL
	lda #8
	sta CB2INT
@lup:	lda CB2INT
	and #8
	beq @lup
	rts
.endproc

;*****************************************************************************
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
	jsr crout
	lda tmp
	bne @row
	rts
.endproc

        rts
