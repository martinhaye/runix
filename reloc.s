; Relocator

; Input:
;	A=src page
;	X=dst/current page
;	Y=num pages

	sta srcpage
	stx dstpage
	stx pscan+1
	sty npages
	lda #0
	sta pscan
inst:	ldy #0
	lda (pscan),y	; read next instruction
	tax
	lda instbl,x
	and #$F		; mask to get just the length
	cmp #3		; we only adjust 3-byte instructions
	bne next
	; it is 3, so carry is set
got3:	ldy #2
	lda (pscan),y	; high byte of operand
	sbc srcpage	; find page offset; carry already set
	bcc skip	; before range? skip
	cmp npages	; after range? skip
	bcs skip
	; carry is now clear
	adc dstpage	; adjust for new location
	sta (pscan),y	; and store it
skip:	lda #3		; back to 3-byte len
next:	clc
	adc pscan
	sta pscan
	bcc inst
	inc pscan+1
	dec npages
	bne inst
	rts