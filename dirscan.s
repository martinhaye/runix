
; Constants
NDIRBLKS	= 4		; directories are always 4 disk blocks ($800 bytes)

; Module-local variables
dirbufpg = *+1			; page of directory buffer
	ora $11

curdirblk = *+1			; last-read directory block
	ora $2222

cwdblk	= *+1			; current working directory
	ora $2222

; Read a directory block to dirbuf; use cached blk if same as last time.
; In:
;	A/X - block num to read
; Out: none (aborts on fail)
.proc readdirblk
	cmp curdirblk
	bne @go
	cpx curdirblk+1
	bne @go
	rts
@go:	ldy dirbufpg
	sta curdirblk	; cache for next time
	stx curdirblk+1
	jmp ReadBlk	; e.g. rune 00, func 0; aborts if err
.endproc

; Scan for a file - optional wildcard at end
; In:
; 	A/X - pascal-style filename to scan for
; 	Y - 0 for exact, $80 for wildcard at end
; Out:
;	clc on success, sec if not found
;	A/X - pointer to blknum (2-byte) and len (2-byte)
.proc scanfile
@fname	= ptmp1		; len 2
@pscan	= ptmp2		; len 2
@wflg	= tmp1		; len 1
@nblks	= tmp1+1	; len 1
@nmlen	= tmp2		; len 1
@blknum	= tmp3		; len 2
	sta @fname
	stx @fname+1
	sty @wflg
	lda cwdblk	; cwd = current directory
	sta @blknum
	lda cwdblk+1
	sta @blknum+1
	lda #NDIRBLKS	; always 4
	sta @nblks
	lda #2
@nxtbk:	sta @pscan	; skip over dir block header (2 bytes first, 0 bytes subsq)
	ldy dirbufpg
	sty @pscan+1
	dec @nblks
	bmi @nofnd	; limit 4 blks per dir
	lda @blknum
	ldx @blknum+1
	jsr readdirblk	; go read the blk (might be cached already)
	inc @blknum	; advance for next time
	bne @ckent
	inc @blknum+1
@ckent:	ldy #0
	lda (@pscan),y	; get entry's name len
	beq @nxtbk	; out of entries, read next dir blk
			; (and set @pscan to buf start since next blk doesn't have free-num)
	sta @nmlen	; save it for later
	tax		; count for non-wild name chk
	cmp (@fname),y
	beq @cknam	; if same len, do normal chk
	bcc @skip	; if entry name shorter than target name, skip.
	bit @wflg	; ent name is longer than target...
	bpl @skip	; ...so if no wild allowed, skip this ent
	lda (@fname),y	; len of *target* name
	tax		; ...is count for name chk
@cknam:	iny
	lda (@pscan),y
	cmp (@fname),y
	bne @skip
	dex
	bne @cknam
@match:	lda @nmlen	; length of name...
	sec		; 	+1 gets us to @blknum
	adc @pscan
	tay
	lda @pscan+1	; ptr to blk and len in A/X
	adc #0
	tax
	tya
	clc
	rts
@skip:	lda @nmlen
	clc
	adc #5		; adjust past len byte itself, plus @blknum and filelen
	adc @pscan
	sta @pscan
	bcc @ckent
	lda @pscan+1
	inc @pscan+1
	cmp dirbufpg	; were we still on first pg of blk?
	beq @ckent	; if so, keep checking
@nofnd:	sec		; not found, error out
	rts
.endproc