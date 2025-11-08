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
	; show the character set for now, so we can verify proper operation
	jsr showallchars
	bit basefont
	ldx *-1		; relocation-friendly way of getting base font page
	jsr backfill
	jmp *		; hang forever
.endproc

;*****************************************************************************
.proc backfill
; Backfills just the lower case character codes ($60-$7F) from a full font.
; in:	X - first page of font

; Fonts start at code $20, so we need to skip forward $40 codes x 8 bytes,
; or 512 bytes, or 2 pages.
	inx
	inx
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
	bne @lup	; do all codes thru $FF
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

	.align 256
basefont:
; Base font data - 8 bytes per character
; Characters 0x20-0x7F (96 characters)
; Each character is 8 rows, pixels stored left-to-right as low-bit to high-bit
    ; 0x20 ' '
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    ; 0x21 '!'
    .byte $08, $08, $08, $08, $00, $08, $00, $00
    ; 0x22 '"'
    .byte $28, $28, $00, $00, $00, $00, $00, $00
    ; 0x23 '#'
    .byte $00, $28, $7C, $28, $7C, $28, $00, $00
    ; 0x24 '$'
    .byte $08, $3C, $0A, $1C, $28, $1E, $08, $00
    ; 0x25 '%'
    .byte $0C, $4C, $10, $08, $64, $60, $00, $00
    ; 0x26 '&'
    .byte $18, $24, $1C, $14, $62, $5C, $00, $00
    ; 0x27 '\''
    .byte $10, $10, $00, $00, $00, $00, $00, $00
    ; 0x28 '('
    .byte $10, $08, $04, $04, $08, $10, $00, $00
    ; 0x29 ')'
    .byte $04, $08, $10, $10, $08, $04, $00, $00
    ; 0x2A '*'
    .byte $00, $10, $54, $10, $54, $10, $00, $00
    ; 0x2B '+'
    .byte $00, $10, $10, $7C, $10, $10, $00, $00
    ; 0x2C ','
    .byte $00, $00, $00, $00, $00, $08, $04, $00
    ; 0x2D '-'
    .byte $00, $00, $00, $7C, $00, $00, $00, $00
    ; 0x2E '.'
    .byte $00, $00, $00, $00, $08, $00, $00, $00
    ; 0x2F '/'
    .byte $40, $20, $10, $08, $04, $00, $00, $00
    ; 0x30 '0'
    .byte $38, $64, $54, $4C, $44, $38, $00, $00
    ; 0x31 '1'
    .byte $08, $0C, $08, $08, $08, $1C, $00, $00
    ; 0x32 '2'
    .byte $38, $44, $20, $10, $08, $7C, $00, $00
    ; 0x33 '3'
    .byte $38, $44, $30, $40, $44, $38, $00, $00
    ; 0x34 '4'
    .byte $20, $30, $28, $7C, $20, $20, $00, $00
    ; 0x35 '5'
    .byte $7C, $01, $3C, $40, $44, $38, $00, $00
    ; 0x36 '6'
    .byte $30, $08, $04, $3C, $44, $38, $00, $00
    ; 0x37 '7'
    .byte $3C, $20, $10, $10, $08, $08, $00, $00
    ; 0x38 '8'
    .byte $38, $44, $38, $44, $44, $38, $00, $00
    ; 0x39 '9'
    .byte $38, $44, $78, $40, $20, $18, $00, $00
    ; 0x3A ':'
    .byte $00, $00, $08, $00, $08, $00, $00, $00
    ; 0x3B ';'
    .byte $00, $00, $08, $00, $00, $08, $04, $00
    ; 0x3C '<'
    .byte $10, $08, $04, $08, $10, $20, $00, $00
    ; 0x3D '='
    .byte $00, $7C, $00, $7C, $00, $00, $00, $00
    ; 0x3E '>'
    .byte $08, $10, $20, $10, $08, $04, $00, $00
    ; 0x3F '?'
    .byte $38, $44, $20, $10, $00, $10, $00, $00
    ; 0x40 '@'
    .byte $1C, $22, $5A, $2A, $3A, $3C, $00, $00
    ; 0x41 'A'
    .byte $08, $14, $22, $3E, $22, $22, $00, $00
    ; 0x42 'B'
    .byte $1E, $22, $1E, $22, $22, $1E, $00, $00
    ; 0x43 'C'
    .byte $1C, $22, $02, $02, $22, $1C, $00, $00
    ; 0x44 'D'
    .byte $1E, $22, $22, $22, $22, $1E, $00, $00
    ; 0x45 'E'
    .byte $3E, $02, $1E, $02, $02, $3E, $00, $00
    ; 0x46 'F'
    .byte $3E, $02, $1E, $02, $02, $02, $00, $00
    ; 0x47 'G'
    .byte $1C, $22, $02, $32, $22, $1C, $00, $00
    ; 0x48 'H'
    .byte $22, $22, $3E, $22, $22, $22, $00, $00
    ; 0x49 'I'
    .byte $1C, $08, $08, $08, $08, $1C, $00, $00
    ; 0x4A 'J'
    .byte $20, $20, $20, $22, $22, $1C, $00, $00
    ; 0x4B 'K'
    .byte $12, $0A, $06, $0A, $12, $22, $00, $00
    ; 0x4C 'L'
    .byte $02, $02, $02, $02, $02, $3E, $00, $00
    ; 0x4D 'M'
    .byte $22, $36, $2A, $22, $22, $22, $00, $00
    ; 0x4E 'N'
    .byte $22, $26, $2A, $32, $22, $22, $00, $00
    ; 0x4F 'O'
    .byte $1C, $22, $22, $22, $22, $1C, $00, $00
    ; 0x50 'P'
    .byte $1E, $22, $22, $1E, $02, $02, $00, $00
    ; 0x51 'Q'
    .byte $1C, $22, $22, $2A, $12, $2C, $00, $00
    ; 0x52 'R'
    .byte $1E, $22, $1E, $0A, $12, $22, $00, $00
    ; 0x53 'S'
    .byte $3C, $02, $1C, $20, $20, $1E, $00, $00
    ; 0x54 'T'
    .byte $3E, $08, $08, $08, $08, $08, $00, $00
    ; 0x55 'U'
    .byte $22, $22, $22, $22, $22, $1C, $00, $00
    ; 0x56 'V'
    .byte $22, $22, $22, $14, $14, $08, $00, $00
    ; 0x57 'W'
    .byte $22, $22, $2A, $2A, $36, $22, $00, $00
    ; 0x58 'X'
    .byte $22, $14, $08, $08, $14, $22, $00, $00
    ; 0x59 'Y'
    .byte $22, $14, $08, $08, $08, $08, $00, $00
    ; 0x5A 'Z'
    .byte $3E, $10, $08, $04, $02, $3E, $00, $00
    ; 0x5B '['
    .byte $1C, $04, $04, $04, $04, $1C, $00, $00
    ; 0x5C '\\'
    .byte $02, $04, $08, $10, $20, $00, $00, $00
    ; 0x5D ']'
    .byte $1C, $10, $10, $10, $10, $1C, $00, $00
    ; 0x5E '^'
    .byte $08, $14, $22, $00, $00, $00, $00, $00
    ; 0x5F '_'
    .byte $00, $00, $00, $00, $00, $3E, $00, $00
    ; 0x60 '`'
    .byte $04, $08, $00, $00, $00, $00, $00, $00
    ; 0x61 'a'
    .byte $00, $1C, $20, $3C, $22, $3C, $00, $00
    ; 0x62 'b'
    .byte $02, $02, $1E, $22, $22, $1E, $00, $00
    ; 0x63 'c'
    .byte $00, $00, $1C, $02, $02, $1C, $00, $00
    ; 0x64 'd'
    .byte $20, $20, $1C, $22, $22, $1C, $00, $00
    ; 0x65 'e'
    .byte $00, $1C, $22, $3E, $02, $1C, $00, $00
    ; 0x66 'f'
    .byte $18, $04, $3C, $04, $04, $04, $00, $00
    ; 0x67 'g'
    .byte $00, $00, $1C, $22, $3C, $20, $1C, $00
    ; 0x68 'h'
    .byte $02, $02, $1E, $22, $22, $22, $00, $00
    ; 0x69 'i'
    .byte $08, $00, $0C, $08, $08, $1C, $00, $00
    ; 0x6A 'j'
    .byte $10, $00, $18, $10, $10, $12, $0C, $00
    ; 0x6B 'k'
    .byte $02, $12, $0A, $06, $0A, $12, $00, $00
    ; 0x6C 'l'
    .byte $0C, $08, $08, $08, $08, $1C, $00, $00
    ; 0x6D 'm'
    .byte $00, $00, $1E, $2A, $2A, $22, $00, $00
    ; 0x6E 'n'
    .byte $00, $00, $1E, $22, $22, $22, $00, $00
    ; 0x6F 'o'
    .byte $00, $00, $1C, $22, $22, $1C, $00, $00
    ; 0x70 'p'
    .byte $00, $00, $1E, $22, $1E, $02, $02, $00
    ; 0x71 'q'
    .byte $00, $00, $1C, $22, $3C, $20, $20, $00
    ; 0x72 'r'
    .byte $00, $00, $1A, $06, $02, $02, $00, $00
    ; 0x73 's'
    .byte $00, $3C, $02, $1C, $20, $1E, $00, $00
    ; 0x74 't'
    .byte $08, $08, $1E, $08, $08, $18, $00, $00
    ; 0x75 'u'
    .byte $00, $00, $22, $22, $22, $1C, $00, $00
    ; 0x76 'v'
    .byte $00, $00, $22, $14, $14, $08, $00, $00
    ; 0x77 'w'
    .byte $00, $00, $22, $2A, $2A, $14, $00, $00
    ; 0x78 'x'
    .byte $00, $22, $14, $08, $14, $22, $00, $00
    ; 0x79 'y'
    .byte $00, $00, $22, $3C, $20, $10, $0C, $00
    ; 0x7A 'z'
    .byte $00, $3E, $10, $08, $04, $3E, $00, $00
    ; 0x7B '{'
    .byte $30, $08, $04, $08, $08, $30, $00, $00
    ; 0x7C '|'
    .byte $08, $08, $08, $08, $08, $08, $00, $00
    ; 0x7D '}'
    .byte $06, $08, $10, $08, $08, $06, $00, $00
    ; 0x7E '~'
    .byte $24, $5A, $00, $00, $00, $00, $00, $00
    ; 0x7F DEL
    .byte $00, $2A, $14, $2A, $14, $2A, $00, $00

        rts
