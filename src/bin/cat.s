; Print contents of a file
; Usage: cat <filename>

.include "base.i"

        .org $1000	; relocated at load time

.proc cat
	; Save filename pointer for dirscan
	sta ptmp
	stx ptmp+1

	; Search for file in current working directory
	ldy #DIRSCAN_CWD
	jsr dirscan
	bcc_or_die "file not found"

	; dirscan returns: A/X = block number, Y = length in pages
	sta fileblk
	stx fileblk+1
	sty npages

	; Calculate number of 512-byte blocks needed
	; pages are 256 bytes, so divide by 2 (round up)
	tya
	clc
	adc #1		; round up
	lsr		; divide by 2
	sta nblks

	; Read all blocks of the file
	; First set zarg = number of blocks to read
	lda nblks
	sta zarg
	; Now load block number and target page
	lda fileblk
	ldx fileblk+1
	ldy #>buffer	; target page (hi byte of buffer)
	jsr rdblks

	; Calculate total bytes = npages * 256
	; We'll print all characters, stopping at end of data
	lda npages
	beq done	; zero pages = nothing to print

	; Set up loop through buffer
	lda #<buffer
	sta ptmp
	lda #>buffer
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
.endproc

	.align 256
buffer:	.res 2048	; 4 blocks = 2048 bytes max file size for now
