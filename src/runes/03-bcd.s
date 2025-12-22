; Rune 3 - BCD (Binary Coded Decimal)
; Jump vectors at $C60-$C7F

        .org $2000

.include "base.i"

	; API jump vectors
	jmp _bcd_fromstr
	jmp _bcd_debug
	jmp _bcd_print
	jmp _bcd_inc
	jmp _bcd_cmp
	jmp _bcd_add
	jmp _bcd_sub
	jmp _bcd_mul
	.align 32,$EA

;*****************************************************************************
.proc _bcd_fromstr
pstr	= bcd_ptr1
pnum	= bcd_ptr2
	stax pnum
	; scan for valid digits
	lda #$F0
	pha		; sentinel
	ldy #0		; Y - string pos
scan:	lda (pstr),y
	sec
	sbc #'0'
	bcc proc
	cmp #10
	bcs proc
	pha		; save digit for later
	iny
	bne scan	; always taken
	; digits are now on the stack, and we can pop least-to-most sig
proc:	ldy #0		; Y - dest byte pos
procl:	pla
	bmi done	; if sentinel encountered on lo, exit is easy
	sta orlo+1	; mod self
	pla
	asl
	asl
	asl
	asl		; A - high-order digit, C - sentinel bit
orlo:	ora #modn
store1:	sta (pnum),y
	iny
	bcc procl	; process until sentinel reached
done:	lda #$FF	; always end with terminator
store2:	sta (pnum),y
	rts
.endproc

;*****************************************************************************
.proc _bcd_print
ptr	= bcd_ptr1
	stax ptr
	ldy #0
	; find terminator
fterm:	lda (ptr),y
	iny
	cmp #$FF
	bne fterm
	dey
	dey
	ldx #0		; char count, for initial-zero suppression
prlup:	lda (ptr),y
	pha
	lsr
	lsr
	lsr
	lsr
	jsr dopr
	pla
	and #$F
	jsr dopr
	dey
	bpl prlup
	txa
	bne done
	lda #'0'
	jsr cout
done:	rts
dopr:	bne notz
	cpx #0
	beq skip
notz:	ora #$30
	jsr cout
	inx
skip:	rts
.endproc

;*****************************************************************************
.proc _bcd_debug
ptr	= bcd_ptr1
	stax ptr
	ldy #0
fterm:	lda (ptr),y
	iny
	pha
	jsr prbyte
	lda #'.'
	jsr cout
	pla
	cmp #$FF
	bne fterm
	rts
.endproc

;*****************************************************************************
.proc _bcd_inc
pnum	= bcd_ptr1
	stax pnum
	ldy #0
lup:	lda (pnum),y
	cmp #$FF
	beq ext

	clc
	sed		; so fun to actually use 6502's decimal mode
	adc #1
	cld		; gotta clear decimal mode for normal use

	sta (pnum),y
	iny
	bcs lup
	rts
ext:	lda #1
	sta (pnum),y
	iny
	lda #$FF
	sta (pnum),y
	rts
.endproc

;*****************************************************************************
.proc _bcd_cmp
pnum1	= bcd_ptr1
pnum2	= bcd_ptr2
	stax pnum2
	; scan for the end of one or both numbers
	ldy #0
lup:	lda (pnum1),y
	cmp #$FF
	beq end1
	lda (pnum2),y
	cmp #$FF
	beq end2
	iny
	bne lup		; always taken
end1:	lda (pnum2),y
	cmp #$FF
	beq eqlen
	; num1 is shorter than num2; so num1 < num2
islt:	lda #$FF	; negative and not equal
	clc		; less than
	rts
end2:	; num2 is shorter than num1; so num1 > num2
isgt:	lda #1		; positive and not equal
	sec		; greater than (or equal)
	rts
	; numbers are the same length; start comparing, MSB to LSB order
eqlen:	dey
	bmi iseq	; if we reach the end of both nums, they must be equal
	lda (pnum1),y
	cmp (pnum2),y
	beq eqlen	; if this part is equal, keep checking
	bcs isgt	; otherwise, it's either greater or less
	bcc islt
iseq:	lda #0		; zero and equal
	sec		; greater than or equal
	rts		; once we find an inequality, we're done
.endproc

;*****************************************************************************
.proc _bcd_add
pnum1	= bcd_ptr1
pnum2	= bcd_ptr2
pout	= bcd_ptr3
	stax pout
	ldy #0
	clc
	sed
lup:	lda (pnum1),y
	sta ad1+1	; modify self below
	eor #$FF
	beq end1
	lda (pnum2),y
	eor #$FF
	beq end2
do1:	eor #$FF
ad1:	adc #modn	; self-modified above
	sta (pout),y
	iny
	bne lup		; always taken

end1:	lda (pnum2),y
	eor #$FF
	beq fin
	eor #$FF
	adc #0
	sta (pout),y
	iny
	bcs end1
fin:	bcc fin2
	lda #1
	sta (pout),y
	iny
fin2:	lda #$FF
	sta (pout),y
	cld
	rts

end2:	lda (pnum1),y
	eor #$FF
	beq fin
	eor #$FF
	adc #0
	sta (pout),y
	iny
	bcs end2
	bcc fin2	; always taken
.endproc

;*****************************************************************************
.proc _bcd_sub
pnum1	= bcd_ptr1
pnum2	= bcd_ptr2
pout	= bcd_ptr3
	stax pout
	ldy #0
	sec
	sed
lup:	lda (pnum2),y
	sta ad1+1	; modify self below
	eor #$FF
	beq end2
	lda (pnum1),y
	eor #$FF
	beq end1
do1:	eor #$FF
ad1:	sbc #modn	; self-modified above
	sta (pout),y
	iny
	bne lup		; always taken

end1:	lda (pnum2),y
	eor #$FF
	beq fin
	eor #$FF
	sbc #0
	sta (pout),y
	iny
	bcc end1
fin:	bcs fin2
	fatal "underflow"
fin2:	lda #$FF
	sta (pout),y
	cld
	rts

end2:	lda (pnum1),y
	eor #$FF
	beq fin
	eor #$FF
	sbc #0
	sta (pout),y
	iny
	bcc end2
	bcs fin2	; always taken
.endproc

;*****************************************************************************
.proc _bcd_mul
pnum1	= bcd_ptr1
pnum2	= bcd_ptr2
pout	= bcd_ptr3
	stax pout

	; calculate the output len = sum of input lengths
	ldx #0
	ldy #$FF
	tya
clen1:	iny
	inx
	cmp (pnum1),y
	bne clen1
	ldy #$FF
clen2:	iny
	inx
	cmp (pnum2),y
	bne clen2

	; clear the output accumulator
	ldy #0
	tya
clr:	sta (pout),y
	iny
	dex
	bne clr
	lda #$FF		; with terminator at the end
	sta (pout),y

	; start at first byte of num1
	lda #0
	sta pos1
	sta outpos

outer:	ldy pos1
	sty outpos		; tricky
	lda (pnum1),y
	cmp #$FF
	beq fin
	; mul that byte against all bytes of num2
	lda #0
	sta pos2
inner:	ldy pos2
	lda (pnum2),y
	cmp #$FF
	beq next
	jsr mul_step
	; next byte of num1
	inc outpos
	inc pos2
	bne inner		; always taken
next:	inc pos1
	bne outer
fin:	jmp norm_out

mul_step:
	; calculate A+B
	ldy pos2
	lda (pnum2),y
	tax
	lda bcd_to_bin,x
	sta add1+1		; mod self below
	sta sub1+1		; mod self below
	ldy pos1
	lda (pnum1),y
	tax
	lda bcd_to_bin,x
	sta ld1+1		; mod self below
	clc
add1:	adc #modn		; self-mod above
	tay			; save for later
	; calculate |A-B|
ld1:	lda #modn		; self-mod above
	sec
sub1:	sbc #modn		; self-mod above
	bcs pos
	eor #$FF		; negative - invert to get abs
	adc #1
pos:	tax			; to index table
	; now calculate Qs[A+B] - Qs[|A-B|] - in BCD
	lda quarter_squares_low,y
	sec
	sed			; so fun to use decimal mode
	sbc quarter_squares_low,x
	pha
	lda quarter_squares_high,y
	sbc quarter_squares_high,x
	tax
	pla
	clc
	ldy outpos
	adc (pout),y
	sta (pout),y
	iny
	txa
	adc (pout),y
	sta (pout),y
	bcc :+
	iny
	lda (pout),y
	adc #0
	sta (pout),y
:	cld			; always gotta remember to turn off decimal mode tho
	rts

norm_out:
	ldy #$FF
	tya
scan:	iny
	cmp (pout),y		; scan for the $FF terminator
	bne scan
bkup:	dey
	beq done
	lda (pout),y		; if non-zero byte, we're done
	bne done
	lda #$FF		; shorten
	sta (pout),y
	bne bkup		; always taken
done:	rts

.endproc

	.byte 0,0,0
pos1:	.byte 0
pos2:	.byte 0
outpos:	.byte 0

; BCD to binary conversion table
; Entry at index $XY (where X and Y are BCD digits) contains decimal value XY

bcd_to_bin:
    .byte   0 ; $00 -> 0
    .byte   1 ; $01 -> 1
    .byte   2 ; $02 -> 2
    .byte   3 ; $03 -> 3
    .byte   4 ; $04 -> 4
    .byte   5 ; $05 -> 5
    .byte   6 ; $06 -> 6
    .byte   7 ; $07 -> 7
    .byte   8 ; $08 -> 8
    .byte   9 ; $09 -> 9
    .byte 255 ; $0A (invalid BCD)
    .byte 255 ; $0B (invalid BCD)
    .byte 255 ; $0C (invalid BCD)
    .byte 255 ; $0D (invalid BCD)
    .byte 255 ; $0E (invalid BCD)
    .byte 255 ; $0F (invalid BCD)
    .byte  10 ; $10 -> 10
    .byte  11 ; $11 -> 11
    .byte  12 ; $12 -> 12
    .byte  13 ; $13 -> 13
    .byte  14 ; $14 -> 14
    .byte  15 ; $15 -> 15
    .byte  16 ; $16 -> 16
    .byte  17 ; $17 -> 17
    .byte  18 ; $18 -> 18
    .byte  19 ; $19 -> 19
    .byte 255 ; $1A (invalid BCD)
    .byte 255 ; $1B (invalid BCD)
    .byte 255 ; $1C (invalid BCD)
    .byte 255 ; $1D (invalid BCD)
    .byte 255 ; $1E (invalid BCD)
    .byte 255 ; $1F (invalid BCD)
    .byte  20 ; $20 -> 20
    .byte  21 ; $21 -> 21
    .byte  22 ; $22 -> 22
    .byte  23 ; $23 -> 23
    .byte  24 ; $24 -> 24
    .byte  25 ; $25 -> 25
    .byte  26 ; $26 -> 26
    .byte  27 ; $27 -> 27
    .byte  28 ; $28 -> 28
    .byte  29 ; $29 -> 29
    .byte 255 ; $2A (invalid BCD)
    .byte 255 ; $2B (invalid BCD)
    .byte 255 ; $2C (invalid BCD)
    .byte 255 ; $2D (invalid BCD)
    .byte 255 ; $2E (invalid BCD)
    .byte 255 ; $2F (invalid BCD)
    .byte  30 ; $30 -> 30
    .byte  31 ; $31 -> 31
    .byte  32 ; $32 -> 32
    .byte  33 ; $33 -> 33
    .byte  34 ; $34 -> 34
    .byte  35 ; $35 -> 35
    .byte  36 ; $36 -> 36
    .byte  37 ; $37 -> 37
    .byte  38 ; $38 -> 38
    .byte  39 ; $39 -> 39
    .byte 255 ; $3A (invalid BCD)
    .byte 255 ; $3B (invalid BCD)
    .byte 255 ; $3C (invalid BCD)
    .byte 255 ; $3D (invalid BCD)
    .byte 255 ; $3E (invalid BCD)
    .byte 255 ; $3F (invalid BCD)
    .byte  40 ; $40 -> 40
    .byte  41 ; $41 -> 41
    .byte  42 ; $42 -> 42
    .byte  43 ; $43 -> 43
    .byte  44 ; $44 -> 44
    .byte  45 ; $45 -> 45
    .byte  46 ; $46 -> 46
    .byte  47 ; $47 -> 47
    .byte  48 ; $48 -> 48
    .byte  49 ; $49 -> 49
    .byte 255 ; $4A (invalid BCD)
    .byte 255 ; $4B (invalid BCD)
    .byte 255 ; $4C (invalid BCD)
    .byte 255 ; $4D (invalid BCD)
    .byte 255 ; $4E (invalid BCD)
    .byte 255 ; $4F (invalid BCD)
    .byte  50 ; $50 -> 50
    .byte  51 ; $51 -> 51
    .byte  52 ; $52 -> 52
    .byte  53 ; $53 -> 53
    .byte  54 ; $54 -> 54
    .byte  55 ; $55 -> 55
    .byte  56 ; $56 -> 56
    .byte  57 ; $57 -> 57
    .byte  58 ; $58 -> 58
    .byte  59 ; $59 -> 59
    .byte 255 ; $5A (invalid BCD)
    .byte 255 ; $5B (invalid BCD)
    .byte 255 ; $5C (invalid BCD)
    .byte 255 ; $5D (invalid BCD)
    .byte 255 ; $5E (invalid BCD)
    .byte 255 ; $5F (invalid BCD)
    .byte  60 ; $60 -> 60
    .byte  61 ; $61 -> 61
    .byte  62 ; $62 -> 62
    .byte  63 ; $63 -> 63
    .byte  64 ; $64 -> 64
    .byte  65 ; $65 -> 65
    .byte  66 ; $66 -> 66
    .byte  67 ; $67 -> 67
    .byte  68 ; $68 -> 68
    .byte  69 ; $69 -> 69
    .byte 255 ; $6A (invalid BCD)
    .byte 255 ; $6B (invalid BCD)
    .byte 255 ; $6C (invalid BCD)
    .byte 255 ; $6D (invalid BCD)
    .byte 255 ; $6E (invalid BCD)
    .byte 255 ; $6F (invalid BCD)
    .byte  70 ; $70 -> 70
    .byte  71 ; $71 -> 71
    .byte  72 ; $72 -> 72
    .byte  73 ; $73 -> 73
    .byte  74 ; $74 -> 74
    .byte  75 ; $75 -> 75
    .byte  76 ; $76 -> 76
    .byte  77 ; $77 -> 77
    .byte  78 ; $78 -> 78
    .byte  79 ; $79 -> 79
    .byte 255 ; $7A (invalid BCD)
    .byte 255 ; $7B (invalid BCD)
    .byte 255 ; $7C (invalid BCD)
    .byte 255 ; $7D (invalid BCD)
    .byte 255 ; $7E (invalid BCD)
    .byte 255 ; $7F (invalid BCD)
    .byte  80 ; $80 -> 80
    .byte  81 ; $81 -> 81
    .byte  82 ; $82 -> 82
    .byte  83 ; $83 -> 83
    .byte  84 ; $84 -> 84
    .byte  85 ; $85 -> 85
    .byte  86 ; $86 -> 86
    .byte  87 ; $87 -> 87
    .byte  88 ; $88 -> 88
    .byte  89 ; $89 -> 89
    .byte 255 ; $8A (invalid BCD)
    .byte 255 ; $8B (invalid BCD)
    .byte 255 ; $8C (invalid BCD)
    .byte 255 ; $8D (invalid BCD)
    .byte 255 ; $8E (invalid BCD)
    .byte 255 ; $8F (invalid BCD)
    .byte  90 ; $90 -> 90
    .byte  91 ; $91 -> 91
    .byte  92 ; $92 -> 92
    .byte  93 ; $93 -> 93
    .byte  94 ; $94 -> 94
    .byte  95 ; $95 -> 95
    .byte  96 ; $96 -> 96
    .byte  97 ; $97 -> 97
    .byte  98 ; $98 -> 98
    .byte  99 ; $99 -> 99

; Quarter-squares table for BCD multiplication
; Entry n contains floor((n*n)/4) in BCD format

quarter_squares_low:
    .byte $00 ; 0*0/4 = 0
    .byte $00 ; 1*1/4 = 0
    .byte $01 ; 2*2/4 = 1
    .byte $02 ; 3*3/4 = 2
    .byte $04 ; 4*4/4 = 4
    .byte $06 ; 5*5/4 = 6
    .byte $09 ; 6*6/4 = 9
    .byte $12 ; 7*7/4 = 12
    .byte $16 ; 8*8/4 = 16
    .byte $20 ; 9*9/4 = 20
    .byte $25 ; 10*10/4 = 25
    .byte $30 ; 11*11/4 = 30
    .byte $36 ; 12*12/4 = 36
    .byte $42 ; 13*13/4 = 42
    .byte $49 ; 14*14/4 = 49
    .byte $56 ; 15*15/4 = 56
    .byte $64 ; 16*16/4 = 64
    .byte $72 ; 17*17/4 = 72
    .byte $81 ; 18*18/4 = 81
    .byte $90 ; 19*19/4 = 90
    .byte $00 ; 20*20/4 = 100
    .byte $10 ; 21*21/4 = 110
    .byte $21 ; 22*22/4 = 121
    .byte $32 ; 23*23/4 = 132
    .byte $44 ; 24*24/4 = 144
    .byte $56 ; 25*25/4 = 156
    .byte $69 ; 26*26/4 = 169
    .byte $82 ; 27*27/4 = 182
    .byte $96 ; 28*28/4 = 196
    .byte $10 ; 29*29/4 = 210
    .byte $25 ; 30*30/4 = 225
    .byte $40 ; 31*31/4 = 240
    .byte $56 ; 32*32/4 = 256
    .byte $72 ; 33*33/4 = 272
    .byte $89 ; 34*34/4 = 289
    .byte $06 ; 35*35/4 = 306
    .byte $24 ; 36*36/4 = 324
    .byte $42 ; 37*37/4 = 342
    .byte $61 ; 38*38/4 = 361
    .byte $80 ; 39*39/4 = 380
    .byte $00 ; 40*40/4 = 400
    .byte $20 ; 41*41/4 = 420
    .byte $41 ; 42*42/4 = 441
    .byte $62 ; 43*43/4 = 462
    .byte $84 ; 44*44/4 = 484
    .byte $06 ; 45*45/4 = 506
    .byte $29 ; 46*46/4 = 529
    .byte $52 ; 47*47/4 = 552
    .byte $76 ; 48*48/4 = 576
    .byte $00 ; 49*49/4 = 600
    .byte $25 ; 50*50/4 = 625
    .byte $50 ; 51*51/4 = 650
    .byte $76 ; 52*52/4 = 676
    .byte $02 ; 53*53/4 = 702
    .byte $29 ; 54*54/4 = 729
    .byte $56 ; 55*55/4 = 756
    .byte $84 ; 56*56/4 = 784
    .byte $12 ; 57*57/4 = 812
    .byte $41 ; 58*58/4 = 841
    .byte $70 ; 59*59/4 = 870
    .byte $00 ; 60*60/4 = 900
    .byte $30 ; 61*61/4 = 930
    .byte $61 ; 62*62/4 = 961
    .byte $92 ; 63*63/4 = 992
    .byte $24 ; 64*64/4 = 1024
    .byte $56 ; 65*65/4 = 1056
    .byte $89 ; 66*66/4 = 1089
    .byte $22 ; 67*67/4 = 1122
    .byte $56 ; 68*68/4 = 1156
    .byte $90 ; 69*69/4 = 1190
    .byte $25 ; 70*70/4 = 1225
    .byte $60 ; 71*71/4 = 1260
    .byte $96 ; 72*72/4 = 1296
    .byte $32 ; 73*73/4 = 1332
    .byte $69 ; 74*74/4 = 1369
    .byte $06 ; 75*75/4 = 1406
    .byte $44 ; 76*76/4 = 1444
    .byte $82 ; 77*77/4 = 1482
    .byte $21 ; 78*78/4 = 1521
    .byte $60 ; 79*79/4 = 1560
    .byte $00 ; 80*80/4 = 1600
    .byte $40 ; 81*81/4 = 1640
    .byte $81 ; 82*82/4 = 1681
    .byte $22 ; 83*83/4 = 1722
    .byte $64 ; 84*84/4 = 1764
    .byte $06 ; 85*85/4 = 1806
    .byte $49 ; 86*86/4 = 1849
    .byte $92 ; 87*87/4 = 1892
    .byte $36 ; 88*88/4 = 1936
    .byte $80 ; 89*89/4 = 1980
    .byte $25 ; 90*90/4 = 2025
    .byte $70 ; 91*91/4 = 2070
    .byte $16 ; 92*92/4 = 2116
    .byte $62 ; 93*93/4 = 2162
    .byte $09 ; 94*94/4 = 2209
    .byte $56 ; 95*95/4 = 2256
    .byte $04 ; 96*96/4 = 2304
    .byte $52 ; 97*97/4 = 2352
    .byte $01 ; 98*98/4 = 2401
    .byte $50 ; 99*99/4 = 2450
    .byte $00 ; 100*100/4 = 2500
    .byte $50 ; 101*101/4 = 2550
    .byte $01 ; 102*102/4 = 2601
    .byte $52 ; 103*103/4 = 2652
    .byte $04 ; 104*104/4 = 2704
    .byte $56 ; 105*105/4 = 2756
    .byte $09 ; 106*106/4 = 2809
    .byte $62 ; 107*107/4 = 2862
    .byte $16 ; 108*108/4 = 2916
    .byte $70 ; 109*109/4 = 2970
    .byte $25 ; 110*110/4 = 3025
    .byte $80 ; 111*111/4 = 3080
    .byte $36 ; 112*112/4 = 3136
    .byte $92 ; 113*113/4 = 3192
    .byte $49 ; 114*114/4 = 3249
    .byte $06 ; 115*115/4 = 3306
    .byte $64 ; 116*116/4 = 3364
    .byte $22 ; 117*117/4 = 3422
    .byte $81 ; 118*118/4 = 3481
    .byte $40 ; 119*119/4 = 3540
    .byte $00 ; 120*120/4 = 3600
    .byte $60 ; 121*121/4 = 3660
    .byte $21 ; 122*122/4 = 3721
    .byte $82 ; 123*123/4 = 3782
    .byte $44 ; 124*124/4 = 3844
    .byte $06 ; 125*125/4 = 3906
    .byte $69 ; 126*126/4 = 3969
    .byte $32 ; 127*127/4 = 4032
    .byte $96 ; 128*128/4 = 4096
    .byte $60 ; 129*129/4 = 4160
    .byte $25 ; 130*130/4 = 4225
    .byte $90 ; 131*131/4 = 4290
    .byte $56 ; 132*132/4 = 4356
    .byte $22 ; 133*133/4 = 4422
    .byte $89 ; 134*134/4 = 4489
    .byte $56 ; 135*135/4 = 4556
    .byte $24 ; 136*136/4 = 4624
    .byte $92 ; 137*137/4 = 4692
    .byte $61 ; 138*138/4 = 4761
    .byte $30 ; 139*139/4 = 4830
    .byte $00 ; 140*140/4 = 4900
    .byte $70 ; 141*141/4 = 4970
    .byte $41 ; 142*142/4 = 5041
    .byte $12 ; 143*143/4 = 5112
    .byte $84 ; 144*144/4 = 5184
    .byte $56 ; 145*145/4 = 5256
    .byte $29 ; 146*146/4 = 5329
    .byte $02 ; 147*147/4 = 5402
    .byte $76 ; 148*148/4 = 5476
    .byte $50 ; 149*149/4 = 5550
    .byte $25 ; 150*150/4 = 5625
    .byte $00 ; 151*151/4 = 5700
    .byte $76 ; 152*152/4 = 5776
    .byte $52 ; 153*153/4 = 5852
    .byte $29 ; 154*154/4 = 5929
    .byte $06 ; 155*155/4 = 6006
    .byte $84 ; 156*156/4 = 6084
    .byte $62 ; 157*157/4 = 6162
    .byte $41 ; 158*158/4 = 6241
    .byte $20 ; 159*159/4 = 6320
    .byte $00 ; 160*160/4 = 6400
    .byte $80 ; 161*161/4 = 6480
    .byte $61 ; 162*162/4 = 6561
    .byte $42 ; 163*163/4 = 6642
    .byte $24 ; 164*164/4 = 6724
    .byte $06 ; 165*165/4 = 6806
    .byte $89 ; 166*166/4 = 6889
    .byte $72 ; 167*167/4 = 6972
    .byte $56 ; 168*168/4 = 7056
    .byte $40 ; 169*169/4 = 7140
    .byte $25 ; 170*170/4 = 7225
    .byte $10 ; 171*171/4 = 7310
    .byte $96 ; 172*172/4 = 7396
    .byte $82 ; 173*173/4 = 7482
    .byte $69 ; 174*174/4 = 7569
    .byte $56 ; 175*175/4 = 7656
    .byte $44 ; 176*176/4 = 7744
    .byte $32 ; 177*177/4 = 7832
    .byte $21 ; 178*178/4 = 7921
    .byte $10 ; 179*179/4 = 8010
    .byte $00 ; 180*180/4 = 8100
    .byte $90 ; 181*181/4 = 8190
    .byte $81 ; 182*182/4 = 8281
    .byte $72 ; 183*183/4 = 8372
    .byte $64 ; 184*184/4 = 8464
    .byte $56 ; 185*185/4 = 8556
    .byte $49 ; 186*186/4 = 8649
    .byte $42 ; 187*187/4 = 8742
    .byte $36 ; 188*188/4 = 8836
    .byte $30 ; 189*189/4 = 8930
    .byte $25 ; 190*190/4 = 9025
    .byte $20 ; 191*191/4 = 9120
    .byte $16 ; 192*192/4 = 9216
    .byte $12 ; 193*193/4 = 9312
    .byte $09 ; 194*194/4 = 9409
    .byte $06 ; 195*195/4 = 9506
    .byte $04 ; 196*196/4 = 9604
    .byte $02 ; 197*197/4 = 9702
    .byte $01 ; 198*198/4 = 9801

quarter_squares_high:
    .byte $00 ; 0*0/4 = 0
    .byte $00 ; 1*1/4 = 0
    .byte $00 ; 2*2/4 = 1
    .byte $00 ; 3*3/4 = 2
    .byte $00 ; 4*4/4 = 4
    .byte $00 ; 5*5/4 = 6
    .byte $00 ; 6*6/4 = 9
    .byte $00 ; 7*7/4 = 12
    .byte $00 ; 8*8/4 = 16
    .byte $00 ; 9*9/4 = 20
    .byte $00 ; 10*10/4 = 25
    .byte $00 ; 11*11/4 = 30
    .byte $00 ; 12*12/4 = 36
    .byte $00 ; 13*13/4 = 42
    .byte $00 ; 14*14/4 = 49
    .byte $00 ; 15*15/4 = 56
    .byte $00 ; 16*16/4 = 64
    .byte $00 ; 17*17/4 = 72
    .byte $00 ; 18*18/4 = 81
    .byte $00 ; 19*19/4 = 90
    .byte $01 ; 20*20/4 = 100
    .byte $01 ; 21*21/4 = 110
    .byte $01 ; 22*22/4 = 121
    .byte $01 ; 23*23/4 = 132
    .byte $01 ; 24*24/4 = 144
    .byte $01 ; 25*25/4 = 156
    .byte $01 ; 26*26/4 = 169
    .byte $01 ; 27*27/4 = 182
    .byte $01 ; 28*28/4 = 196
    .byte $02 ; 29*29/4 = 210
    .byte $02 ; 30*30/4 = 225
    .byte $02 ; 31*31/4 = 240
    .byte $02 ; 32*32/4 = 256
    .byte $02 ; 33*33/4 = 272
    .byte $02 ; 34*34/4 = 289
    .byte $03 ; 35*35/4 = 306
    .byte $03 ; 36*36/4 = 324
    .byte $03 ; 37*37/4 = 342
    .byte $03 ; 38*38/4 = 361
    .byte $03 ; 39*39/4 = 380
    .byte $04 ; 40*40/4 = 400
    .byte $04 ; 41*41/4 = 420
    .byte $04 ; 42*42/4 = 441
    .byte $04 ; 43*43/4 = 462
    .byte $04 ; 44*44/4 = 484
    .byte $05 ; 45*45/4 = 506
    .byte $05 ; 46*46/4 = 529
    .byte $05 ; 47*47/4 = 552
    .byte $05 ; 48*48/4 = 576
    .byte $06 ; 49*49/4 = 600
    .byte $06 ; 50*50/4 = 625
    .byte $06 ; 51*51/4 = 650
    .byte $06 ; 52*52/4 = 676
    .byte $07 ; 53*53/4 = 702
    .byte $07 ; 54*54/4 = 729
    .byte $07 ; 55*55/4 = 756
    .byte $07 ; 56*56/4 = 784
    .byte $08 ; 57*57/4 = 812
    .byte $08 ; 58*58/4 = 841
    .byte $08 ; 59*59/4 = 870
    .byte $09 ; 60*60/4 = 900
    .byte $09 ; 61*61/4 = 930
    .byte $09 ; 62*62/4 = 961
    .byte $09 ; 63*63/4 = 992
    .byte $10 ; 64*64/4 = 1024
    .byte $10 ; 65*65/4 = 1056
    .byte $10 ; 66*66/4 = 1089
    .byte $11 ; 67*67/4 = 1122
    .byte $11 ; 68*68/4 = 1156
    .byte $11 ; 69*69/4 = 1190
    .byte $12 ; 70*70/4 = 1225
    .byte $12 ; 71*71/4 = 1260
    .byte $12 ; 72*72/4 = 1296
    .byte $13 ; 73*73/4 = 1332
    .byte $13 ; 74*74/4 = 1369
    .byte $14 ; 75*75/4 = 1406
    .byte $14 ; 76*76/4 = 1444
    .byte $14 ; 77*77/4 = 1482
    .byte $15 ; 78*78/4 = 1521
    .byte $15 ; 79*79/4 = 1560
    .byte $16 ; 80*80/4 = 1600
    .byte $16 ; 81*81/4 = 1640
    .byte $16 ; 82*82/4 = 1681
    .byte $17 ; 83*83/4 = 1722
    .byte $17 ; 84*84/4 = 1764
    .byte $18 ; 85*85/4 = 1806
    .byte $18 ; 86*86/4 = 1849
    .byte $18 ; 87*87/4 = 1892
    .byte $19 ; 88*88/4 = 1936
    .byte $19 ; 89*89/4 = 1980
    .byte $20 ; 90*90/4 = 2025
    .byte $20 ; 91*91/4 = 2070
    .byte $21 ; 92*92/4 = 2116
    .byte $21 ; 93*93/4 = 2162
    .byte $22 ; 94*94/4 = 2209
    .byte $22 ; 95*95/4 = 2256
    .byte $23 ; 96*96/4 = 2304
    .byte $23 ; 97*97/4 = 2352
    .byte $24 ; 98*98/4 = 2401
    .byte $24 ; 99*99/4 = 2450
    .byte $25 ; 100*100/4 = 2500
    .byte $25 ; 101*101/4 = 2550
    .byte $26 ; 102*102/4 = 2601
    .byte $26 ; 103*103/4 = 2652
    .byte $27 ; 104*104/4 = 2704
    .byte $27 ; 105*105/4 = 2756
    .byte $28 ; 106*106/4 = 2809
    .byte $28 ; 107*107/4 = 2862
    .byte $29 ; 108*108/4 = 2916
    .byte $29 ; 109*109/4 = 2970
    .byte $30 ; 110*110/4 = 3025
    .byte $30 ; 111*111/4 = 3080
    .byte $31 ; 112*112/4 = 3136
    .byte $31 ; 113*113/4 = 3192
    .byte $32 ; 114*114/4 = 3249
    .byte $33 ; 115*115/4 = 3306
    .byte $33 ; 116*116/4 = 3364
    .byte $34 ; 117*117/4 = 3422
    .byte $34 ; 118*118/4 = 3481
    .byte $35 ; 119*119/4 = 3540
    .byte $36 ; 120*120/4 = 3600
    .byte $36 ; 121*121/4 = 3660
    .byte $37 ; 122*122/4 = 3721
    .byte $37 ; 123*123/4 = 3782
    .byte $38 ; 124*124/4 = 3844
    .byte $39 ; 125*125/4 = 3906
    .byte $39 ; 126*126/4 = 3969
    .byte $40 ; 127*127/4 = 4032
    .byte $40 ; 128*128/4 = 4096
    .byte $41 ; 129*129/4 = 4160
    .byte $42 ; 130*130/4 = 4225
    .byte $42 ; 131*131/4 = 4290
    .byte $43 ; 132*132/4 = 4356
    .byte $44 ; 133*133/4 = 4422
    .byte $44 ; 134*134/4 = 4489
    .byte $45 ; 135*135/4 = 4556
    .byte $46 ; 136*136/4 = 4624
    .byte $46 ; 137*137/4 = 4692
    .byte $47 ; 138*138/4 = 4761
    .byte $48 ; 139*139/4 = 4830
    .byte $49 ; 140*140/4 = 4900
    .byte $49 ; 141*141/4 = 4970
    .byte $50 ; 142*142/4 = 5041
    .byte $51 ; 143*143/4 = 5112
    .byte $51 ; 144*144/4 = 5184
    .byte $52 ; 145*145/4 = 5256
    .byte $53 ; 146*146/4 = 5329
    .byte $54 ; 147*147/4 = 5402
    .byte $54 ; 148*148/4 = 5476
    .byte $55 ; 149*149/4 = 5550
    .byte $56 ; 150*150/4 = 5625
    .byte $57 ; 151*151/4 = 5700
    .byte $57 ; 152*152/4 = 5776
    .byte $58 ; 153*153/4 = 5852
    .byte $59 ; 154*154/4 = 5929
    .byte $60 ; 155*155/4 = 6006
    .byte $60 ; 156*156/4 = 6084
    .byte $61 ; 157*157/4 = 6162
    .byte $62 ; 158*158/4 = 6241
    .byte $63 ; 159*159/4 = 6320
    .byte $64 ; 160*160/4 = 6400
    .byte $64 ; 161*161/4 = 6480
    .byte $65 ; 162*162/4 = 6561
    .byte $66 ; 163*163/4 = 6642
    .byte $67 ; 164*164/4 = 6724
    .byte $68 ; 165*165/4 = 6806
    .byte $68 ; 166*166/4 = 6889
    .byte $69 ; 167*167/4 = 6972
    .byte $70 ; 168*168/4 = 7056
    .byte $71 ; 169*169/4 = 7140
    .byte $72 ; 170*170/4 = 7225
    .byte $73 ; 171*171/4 = 7310
    .byte $73 ; 172*172/4 = 7396
    .byte $74 ; 173*173/4 = 7482
    .byte $75 ; 174*174/4 = 7569
    .byte $76 ; 175*175/4 = 7656
    .byte $77 ; 176*176/4 = 7744
    .byte $78 ; 177*177/4 = 7832
    .byte $79 ; 178*178/4 = 7921
    .byte $80 ; 179*179/4 = 8010
    .byte $81 ; 180*180/4 = 8100
    .byte $81 ; 181*181/4 = 8190
    .byte $82 ; 182*182/4 = 8281
    .byte $83 ; 183*183/4 = 8372
    .byte $84 ; 184*184/4 = 8464
    .byte $85 ; 185*185/4 = 8556
    .byte $86 ; 186*186/4 = 8649
    .byte $87 ; 187*187/4 = 8742
    .byte $88 ; 188*188/4 = 8836
    .byte $89 ; 189*189/4 = 8930
    .byte $90 ; 190*190/4 = 9025
    .byte $91 ; 191*191/4 = 9120
    .byte $92 ; 192*192/4 = 9216
    .byte $93 ; 193*193/4 = 9312
    .byte $94 ; 194*194/4 = 9409
    .byte $95 ; 195*195/4 = 9506
    .byte $96 ; 196*196/4 = 9604
    .byte $97 ; 197*197/4 = 9702
    .byte $98 ; 198*198/4 = 9801
