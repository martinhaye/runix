; Runix bootloader - Block 0
; Loads at $2000 (Apple ///) or $800 (Apple II) and boots the system

	.org $2000

tmp	= $6
ptmp	= $8
jblkdrv = $A
blkdrv  = $B

cmd     = $42
unit    = $43
bufptr  = $44
blknum  = $46

krnorg	= $E00

	.byt 1,"Runix"	; magic header, happens to be safely executable

	; On entry, whoever read this block puts Slot*16 into X reg
	stx unit
	; Set up vector to call ProDOS block driver
	txa
	lsr
	lsr
	lsr
	lsr
	ora #$C0
	sta blkdrv+1
	lda #0
	sta blkdrv
	ldy #$FF
	lda (blkdrv),y
	sta blkdrv
	lda #$4C	; jmp
	sta jblkdrv

	; Read the root directory block
	lda #1
	sta blknum
	lda #0
	sta blknum+1
	sta bufptr
	lda #>dirbuf
	sta bufptr+1
	lda #1		; CMD_READ
	sta cmd
	jsr jblkdrv
	bcc gotdir
err:	lda #'E'	; display "E" in lower-left corner of screen
	sta $7D0
	bne *		; hang the system
gotdir: lda #$60	; figure out where we are
	sta tmp
	jsr tmp
	tsx
	lda $100,x
	sta ptmp+1
	lda #<kernfn
	sta ptmp
	ldy #0
	lda (ptmp),y
	tax
fnlup:	lda dirbuf+2,y
	cmp (ptmp),y
	bne err
	iny
	dex
	bpl fnlup	; includes len byte
match:	lda dirbuf+2,y	; blk num lo
	sta blknum
	iny
	lda dirbuf+2,y	; blk num hi
	sta blknum+1
	iny
	lda #>krnorg
	sta bufptr+1
	lda dirbuf+2,y	; # pages
	clc
	adc #1
	lsr		; div 2, rounded up, to get # blks
	; read in the kernel blocks
rdkrn:	pha		; save blk count
	jsr jblkdrv
	bcs err
	inc bufptr+1
	inc bufptr+1
	inc blknum
	bne :+
	inc blknum+1
:	pla
	sec
	sbc #1
	bne rdkrn
	; and jump to the kernel to continue the boot process
	jmp krnorg	

kernfn:	.byte 5		; len
	.byte "runix"

	.align 256
dirbuf	= *
