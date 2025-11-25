; Print contents of a file
; Usage: cat <filename>

.include "base.i"

        .org $1000	; relocated at load time

.proc cat
	; Save filename pointer and search for file
	sta ptmp
	stx ptmp+1
	; dirscan expects filename in A/X, directory in Y
	ldy #DIRSCAN_CWD
	lda ptmp
	ldx ptmp+1
	jsr dirscan
	bcc_or_die "file not found"

	; dirscan returns: A/X = block number, Y = length in pages
	sta fileblk
	stx fileblk+1
	sty npages

	; Check for empty file
	beq done

	; Allocate buffer dynamically using progalloc
	; Input: Y = # pages; Output: X = page number
	tya		; Y already has npages from dirscan
	pha		; save npages for later
	jsr progalloc	; allocate Y pages, returns page in X
	stx bufpage	; save allocated page number
	pla		; restore npages
	sta npages

	; Calculate number of 512-byte blocks needed
	; pages are 256 bytes, so divide by 2 (round up)
	clc
	adc #1		; round up
	lsr		; divide by 2
	sta nblks

	; Read all blocks of the file
	; Set zarg = number of blocks to read
	sta zarg
	; Load block number and target page (from progalloc)
	lda fileblk
	ldx fileblk+1
	ldy bufpage	; target page from progalloc
	jsr rdblks

	; Set up pointer to buffer (page-aligned, so low byte = 0)
	lda #0
	sta ptmp
	lda bufpage
	sta ptmp+1

	; Y is byte offset within page, X is page counter
	ldx npages	; number of pages to scan
	ldy #0

printloop:
	lda (ptmp),y
	beq maybe_end	; null might signal end of text

	; Print if >= $20 (space) or if it's newline/CR
	cmp #$0D	; carriage return
	beq printit
	cmp #$0A	; newline
	beq printit
	cmp #$20	; space
	bcc skipchar	; skip if < space and not CR/LF

printit:
	jsr cout

skipchar:
	iny
	bne printloop	; continue until page done

	; Move to next page
	inc ptmp+1
	dex
	bne printloop

done:
	rts

maybe_end:
	; Could be end of file, or could be binary data
	; For now, just stop at first null
	rts

; Variables (using self-modifying code pattern)
fileblk = *+1
	bit $1111
npages  = *+1
	bit $11
nblks   = *+1
	bit $11
bufpage = *+1
	bit $11
.endproc
