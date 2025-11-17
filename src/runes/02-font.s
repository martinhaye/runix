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
.proc load_default_font
	bit basefont
	ldx *-1		; relocation-friendly way of getting base font page
	jmp backfill
.endproc

;*****************************************************************************
.proc backfill
; Backfills just the lower case character codes ($60-$7F) from a full font.
; in:	X - first page of font
	inx		; Fonts start at code $20, so we need to skip forward $40 codes x 8 bytes,
	inx		; or 512 bytes, i.e. 2 pages.
	stx ptmp+1
	lda #0
	sta ptmp
	lda #$60	; start with code $60
	sta tmp
@lup:	jsr send8
	lda ptmp
	clc
	adc #8*8
	sta ptmp
	bcc :+
	inc ptmp+1
:	lda tmp
	bpl @lup	; do all codes thru $7F
	rts
.endproc

;*****************************************************************************
; Notes on setting character set:
;   Slot 0:
; 	878:char0-code	478:char0-pixbyte0
; 	87C:"           47C:char0-pixbyte1
; 	8F8:"           4F8:char0-pixbyte2
; 	8FC:"           4FC:char0-pixbyte3
; 	978:"           578:char0-pixbyte4
; 	97C:"           57C:char0-pixbyte5
; 	9F8:"           5F8:char0-pixbyte6
; 	9FC:"           5FC:char0-pixbyte7
;   Slot 1:
; 	879:char1-code	479:char1-pixbyte0
; 	87D:"           47D:char1-pixbyte1
; 	8F9:"           4F9:char1-pixbyte2
; 	8FD:"           4FD:char1-pixbyte3
; 	979:"           579:char1-pixbyte4
; 	97D:"           57D:char1-pixbyte5
; 	9F9:"           5F9:char1-pixbyte6
; 	9FD:"           5FD:char1-pixbyte7
;   Slot 2:
; 	87A:char2-code	47A:char2-pixbyte0
; 	87E:"           47E:char2-pixbyte1
; 	8FA:"           4FA:char2-pixbyte2
; 	8FE:"           4FE:char2-pixbyte3
; 	97A:"           57A:char2-pixbyte4
; 	97E:"           57E:char2-pixbyte5
; 	9FA:"           5FA:char2-pixbyte6
; 	9FE:"           5FE:char2-pixbyte7
;   Slot 3:
; 	87B:char3-code	47B:char3-pixbyte0
; 	87F:"           47F:char3-pixbyte1
; 	8FB:"           4FB:char3-pixbyte2
; 	8FF:"           4FF:char3-pixbyte3
; 	97B:"           57B:char3-pixbyte4
; 	97F:"           57F:char3-pixbyte5
; 	9FB:"           5FB:char3-pixbyte6
; 	9FF:"           5FF:char3-pixbyte7
;   ** break in pattern **
;   Slot 4:
; 	A78:char4-code	678:char4-pixbyte0
; 	A7C:"           67C:char4-pixbyte1
; 	AF8:"           6F8:char4-pixbyte2
; 	AFC:"           6FC:char4-pixbyte3
; 	B78:"           778:char4-pixbyte4
; 	B7C:"           77C:char4-pixbyte5
; 	BF8:"           7F8:char4-pixbyte6
; 	BFC:"           7FC:char4-pixbyte7
;   Slot 5:
; 	A79:char5-code	679:char5-pixbyte0
; 	A7D:"           67D:char5-pixbyte1
; 	AF9:"           6F9:char5-pixbyte2
; 	AFD:"           6FD:char5-pixbyte3
; 	B79:"           779:char5-pixbyte4
; 	B7D:"           77D:char5-pixbyte5
; 	BF9:"           7F9:char5-pixbyte6
; 	BFD:"           7FD:char5-pixbyte7
;   Slot 6:
; 	A7A:char6-code	67A:char6-pixbyte0
; 	A7E:"           67E:char6-pixbyte1
; 	AFA:"           6FA:char6-pixbyte2
; 	AFE:"           6FE:char6-pixbyte3
; 	B7A:"           77A:char6-pixbyte4
; 	B7E:"           77E:char6-pixbyte5
; 	BFA:"           7FA:char6-pixbyte6
; 	BFE:"           7FE:char6-pixbyte7
;   Slot 7:
; 	A7B:char7-code	67B:char7-pixbyte0
; 	A7F:"           67F:char7-pixbyte1
; 	AFB:"           6FB:char7-pixbyte2
; 	AFF:"           6FF:char7-pixbyte3
; 	B7B:"           77B:char7-pixbyte4
; 	B7F:"           77F:char7-pixbyte5
; 	BFB:"           7FB:char7-pixbyte6
; 	BFF:"           7FF:char7-pixbyte7

;*****************************************************************************
.proc send8
; Send 8 character bitmaps to the font RAM via screen holes.
; In:	ptmp - pointer to character bitmaps
;	tmp - character number (will be advanced 8 times)
	ldy #0		; index into char data
@outer:	ldx #0		; index into screen holes
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
	lda (ptmp),y
	iny
	sta $478,x
	lda (ptmp),y
	iny
	sta $47C,x
	lda (ptmp),y
	iny
	sta $4F8,x
	lda (ptmp),y
	iny
	sta $4FC,x
	lda (ptmp),y
	iny
	sta $578,x
	lda (ptmp),y
	iny
	sta $57C,x
	lda (ptmp),y
	iny
	sta $5F8,x
	lda (ptmp),y
	iny
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
	lda (ptmp),y
	iny
	sta $678,x
	lda (ptmp),y
	iny
	sta $67C,x
	lda (ptmp),y
	iny
	sta $6F8,x
	lda (ptmp),y
	iny
	sta $6FC,x
	lda (ptmp),y
	iny
	sta $778,x
	lda (ptmp),y
	iny
	sta $77C,x
	lda (ptmp),y
	iny
	sta $7F8,x
	lda (ptmp),y
	iny
	sta $7FC,x
	inc tmp
	inx
	cpx #4
	beq @go
	jmp @stoA	; too far for a relative branch
; Now trigger the hardware to pick up the data from the screen holes.
; Give it at least a scan between vertical retraces to complete.
; (at least, I think that's what we're doing here)
@go:	lda CWRTON
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
;.proc showallchars
;	jsr clrscr
;	lda #0
;	sta tmp
;@row:	ldy #0
;@rlup:	lda tmp
;	sta (txtptre),y
;	inc tmp
;	iny
;	cpy #16
;	bne @rlup
;	jsr crout
;	lda tmp
;	bne @row
;	rts
;.endproc

	.align 256
basefont:
.include "base_font.s"
