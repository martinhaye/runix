; Runix kernel

.include "base.i"

; Always loads at $0E00
	.org $0E00

; Zero-page - keep minimal for kernel!
txtptre	= $F2
txtptro	= $F4

; Hardware addresses
CWRTON	= $C0DB
CWRTOFF	= $C0DA
CB2CTRL	= $FFEC
CB2INT	= $FFED

; ROM locations
a2mon	= $FF65
a3mon	= $F901

; Constants
NDIRBLKS = 4

;*****************************************************************************
.proc startup
	; grab vector to HDD block routine (it was set up by our boot loader)
	lda $B
	sta callhdd+1
	lda $C
	sta callhdd+2
	; also grab the unit #
	lda $43
	sta hddunit

	; identify the platform (Apple /// or not)
	ldx #0
	lda a3mon
	cmp #$BA	; TSX on Apple /// rom
	bne @gotpl
	ldx #$80
@gotpl:	stx a3flg
	
	; set up the BRK handler
	txa
	bpl @a2brk
	lda #$4C	; Apple III jumps to $FFCD on BRK/IRQ
	sta $FFCD
	lda #<brkhnd
	sta $FFCE
	lda #>brkhnd
	sta $FFCF
	bne @welcm	; always taken
@a2brk:	lda #<a2brk
	sta $3F0	; Apple II does "JMP ($3F0)" on BRK/IRQ
	lda #>a2brk
	sta $3F1

@welcm: ; display the welcome message and set initial rune vecs
	jsr _clrscr
	print "Welcome to Runix 0.1\n"
	jsr _resetrunes
	; set cwd = root dir (block 1)
	ldx #1
	stx cwdblk
	dex
	stx cwdblk+1
	; find the "runes" subdir
	ldstr "runes"
	jsr _dirscan
	bcc_or_die "no runes dir"
	sta runesdirblk
	stx runesdirblk+1

	; load the default font
	jsr $C40	; rune 2, vector 0: this will shock-load rune 2

	; we don't have a shell yet - start system monitor for inspection
	jmp gosysmon
.endproc

;*****************************************************************************
.proc _resetrunes
	; set up the dummy rune API vectors
	lda #0
	sta ptmp
	lda #$C
	sta ptmp+1
	ldy #0
	sty tmp
@crune:	lda rune0vecs,y	; rune0 is the kernel naturally
	sta (ptmp),y
	iny
	cpy #$40	; cover rune1 as well (text services)
	bne @crune
	; remaining runes are all stubs
@outer:	ldx #10
@dum:	lda #$20	; it's a JSR so we can capture the vector addr
	sta (ptmp),y
	iny
	lda #<shockload
	sta (ptmp),y
	iny
	lda #>shockload
	sta (ptmp),y
	iny
	dex
	bne @dum
	lda #$EA	; nop
	sta (ptmp),y
	iny
	sta (ptmp),y
	iny
	bne @outer	; 10 vec * 3 bytes + 2 nops = 32; 32*8 runes = 256
	inc ptmp+1
	lda ptmp+1
	cmp #$E
	bne @outer
	; reset the rune allocation page; start with kernelend .. $2000
	lda #>kernelend
	sta nextrunepg
	lda #$20
	sta limitrunepg
	rts
.endproc

;*****************************************************************************
; Shock-load a rune
.proc shockload
	sta asav
	stx xsav
	sty ysav
	pla		; retadr lo
	sec
	sbc #2		; back to start of jump vec
	sta @jgo+1	; modifies code below
	and #$E0	; 00, 20, 40, etc.
	sta @rvec+1	; ptr to start of rune vecs, for later
	tay		; save temporarily
	lda $102,x	; retadr hi
	sbc #0
	sta @jgo+2	; modifies code below
	sta @rvec+2	; ptr hi for start of rune vecs, for later
	sta tmp
	tya		; get ret lo back
	ldx #5		; div 32 (shift right 5)
:	lsr tmp
	ror
	dex
	bne :-
	and #$F		; rune number now in A
	ora #'0'	; form filename prefix
	sta runefn+2
	; switch to rune subdir
	ldx #1
:	lda cwdblk,x
	pha
	lda runesdirblk,x
	sta cwdblk,x
	dex
	bne :-
	; search for the rune with wildcard
	lda #<runefn
	ldx #>runefn
	jsr wildscan
	bcc_or_die "missing rune"
	pha		; save blk num on stk
	txa
	pha
	sty @ldnpg+1	; modify code - # pages
	; allocate memory for the rune code
	jsr @runealloc	; allocate Y pages, result pg in X
	stx @ldtpg+1	; modify code - target page
	stx @cpvec+2	; mod code below for vector copy later
	; read the rune
	pla		; we stashed blk num on stack earlier
	tax
	pla
	; y already contains target page
	jsr _readblks	; read in the rune code
	; process the code relocation
	lda #$20	; rune code is always org $2000
@ldtpg:	ldx #$11	; target page, self-mod above
@ldnpg:	ldy #$22	; number of pages, self-mod above
	jsr reloc
	; copy the rune's vectors to their place in the table
	ldx #$1F
@cpvec:	lda $1100,x	; self-modified above
@rvec:	sta $C00,x	; self-modified earlier
	dey
	bpl @cpvec
	; restore orig cwd
	pla
	sta cwdblk
	pla
	sta cwdblk+1
	; finally, execute the original rune call
	lda asav
	ldx xsav
	ldy ysav
@jgo:	jmp $1122	; self-mod above

; allocate Y pages, result pg in X
@runealloc:
	tya			; page count
	clc			; round up to full blks for scan
	adc #1
	lsr
	sta zarg		; save blk count for later
	asl
	sta tmp
@loop:	lda limitrunepg
	sec
	sbc nextrunepg		; calculate how many remain in this area
	cmp tmp
	bcc @next
	ldx nextrunepg		; save page to allocate
	tya			; get back real # pages
	clc
	adc nextrunepg		; bump up the next rune pg
	sta nextrunepg
	rts
@next:	lda limitrunepg
	cmp #$20
	bne @out
	; Exhausted the space up to $2000; switch to $A000.BFFF
	lda #$A0
	sta nextrunepg
	lda #$C0
	sta limitrunepg
	bne @loop		; always taken
@out:	fatal "out of rune space"

.endproc

;*****************************************************************************
_readblk:
	lda #1		; alt entry point to read just one block
	sta zarg
.proc _readblks
@cmd     = $42
@unit    = $43
@bufptr  = $44
@blknum  = $46
	sta @ld1+1	; mod code below
	stx @ld2+1	; mod code below
	; save contents of $42-47 on stack
	ldx #0
:	lda $42,x
	pha
	inx
	cpx #6
	bne :-
	; set up parameters
	lda #1		; read
	sta @cmd
	lda hddunit
	sta @unit
	lda #0
	sta @bufptr
	sty @bufptr+1	; target page still in Y
@ld1:	lda #$11	; self-modified above
	sta @blknum
@ld2:	lda #$22	; self-modified above
	sta @blknum+1
@lup:	jsr callhdd
	bcc_or_die "hdd read fail"
	inc @blknum
	bne :+
	inc @blknum+1
:	inc @bufptr+1
	inc @bufptr+1
	dec zarg	; more blocks?
	bne @lup	; read more
	; restore $42-47 from stack
	ldx #5
:	pla
	sta $42,x
	dex
	bpl :-
	rts
.endproc
callhdd: jmp $CF0A	; self-modified by startup

;*****************************************************************************
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
@go:	ldy #>dirbuf
	sta curdirblk	; cache for next time
	stx curdirblk+1
	jmp _readblk
.endproc

;*****************************************************************************
; Scan directory for a file - optional wildcard at end
; In:
; 	A/X - pascal-style (len-prefixed) filename to scan for
; Out:
;	clc on success, sec if not found
;	A/X - blk num
;	Y - length in pages
wildscan:
	ldy #$80
	bne *+4		; skip ldy below
.proc _dirscan
	ldy #0
@fname	= ptmp		; len 2
@pscan	= ptmp2		; len 2
@wflg	= tmp		; len 1
@nblks	= tmp+1		; len 1
@nmlen	= tmp2		; len 1
@blknum	= tmp3		; len 2
@setw:	sty @wflg
	sta @fname
	stx @fname+1
	lda cwdblk	; cwd = current directory
	sta @blknum
	lda cwdblk+1
	sta @blknum+1
	lda #NDIRBLKS	; always 4
	sta @nblks
	lda #2
@nxtbk:	sta @pscan	; skip over dir block header (2 bytes first, 0 bytes subsq)
	ldy #>dirbuf
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
	bcc :+
	inc @pscan+1
:	ldy #0
	lda (@pscan),y	; blk num lo
	pha
	iny
	lda (@pscan),y	; blk num hi
	tax
	iny	
	lda (@pscan),y	; length in pages
	tay
	pla		; get blk num lo back
	clc		; signal success
	rts
@skip:	lda @nmlen
	clc
	adc #4		; adjust past len byte itself, plus @blknum and filelen
	adc @pscan
	sta @pscan
	bcc @ckent
	lda @pscan+1
	inc @pscan+1
	cmp #>dirbuf	; were we still on first pg of blk?
	beq @ckent	; if so, keep checking
@nofnd:	sec		; not found, error out
	rts
.endproc

;*****************************************************************************
_gotoxy:
	stx cursx
	sty cursy
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
.proc _clrscr
; Clear entire screen
; leaves with cursx=0, cursy=0
	jsr @zero
@loop:	jsr clreol
	inc cursy
	jsr bascalc
	lda cursy
	cmp #24
	bne @loop
@zero:	ldx #0
	ldy #0
	jmp gotoxy
.endproc

;*****************************************************************************
_prspc:	lda #' '
	; fall into...
.proc _cout
; Write one character to the text screen. Advances cursx (and cursy if end of
; line)
; In:	A - char to write (hi bit ignored)
; Out:	Preserves A/X/Y
	stx xsav
	sty ysav
	pha
	ldy cursx
	and #$7F	; ignore hi-bits if present
	cmp #$D		; traditional Apple II carriage-return ('\r')
	beq crout2
	cmp #$A		; '\n' c-style newline
	beq crout2
	ora #$80	; set hi-bit for normal non-inverse text
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
_crout:	stx xsav
	sty ysav
	pha
	; fall into...
.proc crout2
	ldx #0
	stx cursx
	inc cursy
	lda cursy
	cmp #24
	beq @scrl
	jsr bascalc
	jmp restregs
	; end of screen - scroll it up
@scrl:	ldy #0
	jsr _gotoxy	; x is already zero
@sc1:	lda txtptre
	sta @st+1	; modifies code below
	lda txtptre+1
	sta @st+2
	inc cursy
	jsr bascalc
	ldy #39
@cp:	lda (txtptre),y
@st:	sta $1111,y	; self-modified above
	dey
	bpl @cp
	lda cursy
	cmp #23
	bne @sc1
	jsr clreol
	jmp restregs
.endproc

;*****************************************************************************
.proc _prbyte
	pha
	lsr
	lsr
	lsr
	lsr
	jsr @prdig
	pla
	and #$F
@prdig:	cmp #$A
	bcs @letr
	adc #'0'
	jmp cout
@letr:	clc
	adc #'A'-$A
	jmp cout
.endproc

;*****************************************************************************
.proc reloc
; Relocator
; Input:
;	A=src page
;	X=dst/current page
;	Y=num pages
@srcpage = tmp
@dstpage = tmp+1
@npages = tmp2
@pscan = ptmp
	sta @srcpage
	stx @dstpage
	stx @pscan+1
	sty @npages
	lda #0
	sta @pscan
	tay		; Y is normally zero
@inst:	lda (@pscan),y	; read next instruction
	beq @sbrk	; special case for brk
	tax
	lda inslen_t,x
	cmp #3
	beq @len3
	; len < 3, so carry is now clear
@adv:	;clc		; carry is already clear when we arrive here
	adc @pscan
	sta @pscan
	bcc @inst
	inc @pscan+1
	lda @pscan+1
	sec
	sbc @dstpage
	cmp @npages
	bcc @inst
@stop:	rts

@len3:	;sec		; fyi we got here via beq, so carry is already set
	ldy #2
	lda (@pscan),y	; high byte of operand
	sbc @srcpage	; find page offset; carry already set
	bcc @skip	; before range? skip
	cmp @npages	; after range? skip
	bcs @skip
	; carry is now clear
	adc @dstpage	; adjust for new location
	sta (@pscan),y	; and store it
@skip:	lda #3		; back to 3-byte len
	ldy #0		; normal state again
	clc
	bcc @adv	; always taken

@sbrk:	iny
	lda (@pscan),y	; check 1st byte of str
	beq @bbrk	; if zero, it's a normal brk (or maybe start-of-data)
	cmp #$20
	bcc @lpfx	; if < $20, it's length-prefixed
@chkz:	iny
	lda (@pscan),y
	bne @chkz	; scan for zero-terminator
	iny		; and one past for next ins
	tya		; now we have the len
	ldy #0
	clc
	bcc @adv	; always taken

@lpfx:	sec
	adc #2		; brk + len + bytes; always clears carry since len < $20
	ldy #0		; normal mode
	bcc @adv	; always taken

@bbrk:	iny
	lda (@pscan),y	; one more byte
	beq @stop	; 3 zeros in a row --> stop relocation, data section begun
	ldy #0
	lda #2
	clc
	bcc @adv	; otherwise, a real 2-byte brk (always taken)
.endproc

;*****************************************************************************
a2brk:	; put things back the way native brk would be
	lda $3B		; pc h
	pha
	lda $3A		; pc l
	pha
	lda $48		; preg
	pha
	lda $45
	ldx $46
	ldy $47
.proc brkhnd
	sta areg
	stx xreg
	sty yreg
	pla
	pha		; leave preg on stack
	and #$10
	beq @irq	; for now, do nothing on real IRQ
	tsx
	lda $102,x
	sec
	sbc #1
	sta @ld1+1	; mod self below
	sta @ld2+1
	lda $103,x
	sbc #0
	sta @ld1+1	; mod self below
	sta @ld2+1
	ldx #0
@ld1:	lda $1111	; first byte
	beq @bkpnt	; BRK 00 means actual breakpoint
	cmp #$20
	bcs @scanz	; >= $20 means to print zero-terminated string
	lda @ld1+1	; len-prefixed str - put its ptr in A/X
	sta areg
	lda @ld2+1
	sta xreg
	bcs @adv	; always taken
@scanz:	jsr _cout	; print char
	inx
@ld2:	lda $1111,x	; find terminator
	bne @scanz
	txa
@adv:	sec		; advance over the terminator (or over the len pfx)
	adc $102,x	; ret adr lo
	sta $102,x
	bcc :+
	inc $103,x	; ret adr hi
:	lda areg
	ldx xreg
	ldy yreg
@irq:	rti

; breakpoint (BRK 00) - print location and registers
@bkpnt:	ldy #22
	ldx #0
	jsr _gotoxy
	pla		; p reg
	tay		; save it aside
	pla		; PC lo
	sbc #1		; brk advances as if a 2-byte instr
	tax
	pla		; PC hi
	sbc #0
	jsr _prbyte
	txa
	jsr _prbyte
	lda #':'
	jsr _cout
	jsr _prspc
	; print all registers
	ldx areg
	lda #'A'
	jsr @preg
	ldx xreg
	lda #'X'
	jsr @preg
	ldx yreg
	lda #'Y'
	jsr @preg
	tya		; get back p-reg val, saved all the way up there
	tax
	lda #'P'
	jsr @preg
	tsx		; happily we've popped everything, so this is the real caller S reg
	lda #'S'
	jsr @preg
	jsr _crout
	; jump to platform-specific system monitor for now
	jmp gosysmon

@preg:	jsr _cout
	lda #'='
	jsr _cout
	txa
	jsr _prbyte
	jmp _prspc
.endproc

;*****************************************************************************
.proc _fatal
; On last line, print "Fatal error: ", then pstring in A/X, then go to monitor
	sta ptmp
	stx ptmp+1
	ldx #0
	ldy #23
	jsr _gotoxy
	jsr _crout
	print "Fatal error: "
	ldy #0
	lda (ptmp),y	; str len
	tax
	iny
@lup:	lda (ptmp),y
	jsr _cout
	iny
	dex
	bne @lup
	jsr _crout
	jmp gosysmon
.endproc

;*****************************************************************************
.proc gosysmon
	bit a3flg
	bpl @a2
@a3:	lda #23
	sta $5D
	jsr $FBC7	; a3 bascalc
	jmp a3mon
@a2:	lda #21
	sta $25
	jsr $FD8E	; a2 crout
	jmp a2mon
.endproc

;*****************************************************************************
; data
a3flg:	.byte 0
cursx:	.byte 0
cursy:	.byte 0
; reg saves used by cout and other routines
asav:	.byte 0
xsav:	.byte 0
ysav:	.byte 0
; reg saves used by brkhnd
areg:	.byte 0
xreg:	.byte 0
yreg:	.byte 0

; rune allocation global vars
nextrunepg:	.byte 0
limitrunepg:	.byte 0
lastrunepg:	.byte 0

; directory global vars
hddunit:	.byte 0
cwdblk:		.word 0
curdirblk:	.word 0
runesdirblk:	.word 0

runefn:		.byte 2, "00" ; length + 2 digits

;*****************************************************************************
	.align 32
rune0vecs:	; rune 0 = kernel services
	jmp _resetrunes
	jmp _fatal
	jmp _readblks
	jmp _dirscan
	.align 32,$EA	; rune vecs always total 32 bytes
rune1vecs:	; rune 1 = text services
	jmp _clrscr
	jmp _gotoxy
	jmp _cout
	jmp _crout
	jmp _prbyte
	.align 32,$EA	; rune vecs always total 32 bytes

;*****************************************************************************
	.align 256
inslen_t:
	.byte 1,2,1,1,1,2,2,1,1,2,1,1,1,3,3,1
	.byte 2,2,1,1,1,2,2,1,1,3,1,1,1,3,3,1
	.byte 3,2,1,1,2,2,2,1,1,2,1,1,3,3,3,1
	.byte 2,2,1,1,1,2,2,1,1,3,1,1,1,3,3,1
	.byte 1,2,1,1,1,2,2,1,1,2,1,1,3,3,3,1
	.byte 2,2,1,1,1,2,2,1,1,3,1,1,1,3,3,1
	.byte 1,2,1,1,1,2,2,1,1,2,1,1,3,3,3,1
	.byte 2,2,1,1,1,2,2,1,1,3,1,1,1,3,3,1
	.byte 1,2,1,1,2,2,2,1,1,1,1,1,3,3,3,1
	.byte 2,2,1,1,2,2,2,1,1,3,1,1,1,3,1,1
	.byte 2,2,2,1,2,2,2,1,1,2,1,1,3,3,3,1
	.byte 2,2,1,1,2,2,2,1,1,3,1,1,3,3,3,1
	.byte 2,2,1,1,2,2,2,1,1,2,1,1,3,3,3,1
	.byte 2,2,1,1,1,2,2,1,1,3,1,1,1,3,3,1
	.byte 2,2,1,1,2,2,2,1,1,2,1,1,3,3,3,1
	.byte 2,2,1,1,1,2,2,1,1,3,1,1,1,3,3,1

dirbuf	= *
kernelend = dirbuf+$200