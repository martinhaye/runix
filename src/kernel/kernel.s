; Runix kernel

.include "base.i"

; Always loads at $0E00
	.org $0E00

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
	bne gotpl
	ldx #$80
gotpl:	stx a3flg
	
	; set up the BRK handler
	txa
	bpl a2
	lda #$4C	; Apple III jumps to $FFCD on BRK/IRQ
	sta $FFCD
	lda #<brkhnd
	sta $FFCE
	lda #>brkhnd
	sta $FFCF
	bne welcm	; always taken
a2:	lda #<a2brk
	sta $3F0	; Apple II does "JMP ($3F0)" on BRK/IRQ
	lda #>a2brk
	sta $3F1

welcm: ; display the welcome message and set initial rune vecs
	jsr _clrscr
	print "Welcome to Runix 0.1\n"
	jsr _resetrunes
	; find the "runes" subdir
	lda #<s_runes
	ldx #>s_runes
	ldy #DIRSCAN_ROOT
	jsr _dirscan
	bcc_or_die "no runes dir"
	sta runesdirblk
	stx runesdirblk+1
	; Also find the "bin" subdir
	lda #<s_bin
	ldx #>s_bin
	ldy #DIRSCAN_ROOT
	jsr _dirscan
	bcc_or_die "no bin dir"
	sta bindirblk
	stx bindirblk+1
	; On the Apple III, we need to back-fill lowercase font
	bit a3flg
	bpl :+
	jsr $C40	; rune 2, vector 0: this will shock-load rune 2
:	; Now run the shell
	ldx #$20	; start allocating program space at $2000
	stx nextprogpg
	lda #<s_shell
	ldx #>s_shell
	jsr _progrun
	fatal "shell not found"
.endproc

;*****************************************************************************
.proc _resetrunes
	; set up the dummy rune API vectors
	lda #$C
	sta ptmp+1
	ldy #0
	sty ptmp
	sty tmp
crune:	lda rune0vecs,y	; rune0 is the kernel naturally
	sta (ptmp),y
	iny
	cpy #$40	; cover rune1 as well (text services)
	bne crune
	; remaining runes are all stubs
outer:	ldx #10
dum:	lda #$20	; it's a JSR so we can capture the vector addr
	sta (ptmp),y
	iny
	lda #<shockload
	sta (ptmp),y
	iny
	lda #>shockload
	sta (ptmp),y
	iny
	dex
	bne dum
	lda #$EA	; nop
	sta (ptmp),y
	iny
	sta (ptmp),y
	iny
	bne outer	; 10 vec * 3 bytes + 2 nops = 32; 32*8 runes = 256
	inc ptmp+1
	lda ptmp+1
	cmp #$E
	bne outer
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
	sta jgo+1	; modifies code below
	and #$E0	; 00, 20, 40, etc.
	sta rvec+1	; ptr to start of rune vecs, for later
	tay		; save temporarily
	pla
	sbc #0
	sta jgo+2	; modifies code below
	sta rvec+2	; ptr hi for start of rune vecs, for later
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
	; search for the rune with wildcard
	lda #<runefn
	ldx #>runefn
	ldy #DIRSCAN_RUNES
	jsr wildscan
	bcc_or_die "missing rune"
	pha		; save blk num on stk
	txa
	pha
	sty ldnpg+1	; modify code - # pages
	; allocate memory for the rune code
	jsr runealloc	; allocate Y pages, result pg in X
	stx ldtpg+1	; modify code - target page
	stx cpvec+2	; mod code below for vector copy later
	; read the rune
	txa
	tay		; target page now in Y
	pla		; we stashed blk num on stack earlier
	tax
	pla
	jsr _readblks	; read in the rune code
	; process the code relocation
	lda #$20	; rune code is always org $2000
ldtpg:	ldx #$11	; target page, self-mod above
ldnpg:	ldy #$22	; number of pages, self-mod above
	jsr reloc
	; copy the rune's vectors to their place in the table
	ldx #$1F
cpvec:	lda $1100,x	; self-modified above
rvec:	sta $C00,x	; self-modified earlier
	dex
	bpl cpvec
	; finally, execute the original rune call
	lda asav
	ldx xsav
	ldy ysav
jgo:	jmp $1122	; self-mod above

; allocate Y pages for rune space, result pg in X
; guarantees safety of reading by block until the next
; allocation - while it doesn't allocate double-pages, 
; it ensures it could have.
runealloc:
	tya			; page count
	clc			; round up to full blks for scan
	adc #1
	lsr
	sta zarg		; save blk count for later
	asl
	sta tmp
loop:	lda limitrunepg
	sec
	sbc nextrunepg		; calculate how many remain in this area
	cmp tmp
	bcc next
	ldx nextrunepg		; save page to allocate
	tya			; get back real # pages
	clc
	adc nextrunepg		; bump up the next rune pg
	sta nextrunepg
	rts
next:	lda limitrunepg
	cmp #$20
	bne out
	; Exhausted the space up to $2000; switch to $A000.BFFF
	lda #$A0
	sta nextrunepg
	lda #$C0
	sta limitrunepg
	bne loop		; always taken
out:	fatal "out of rune space"
.endproc

;*****************************************************************************
; Allocate program space
; In:	Y - # pages
; Out:	X - page number allocated
; Guarantees safety of reading by block until the next allocation - while it 
; doesn't allocate double-pages, it ensures it could have.
.proc _progalloc
	tya			; page count
	clc			; round up to full blks for check
	adc #1
	lsr
	asl
	sta tmp			; # pages to check for
	lda limitprogpg
	sec
	sbc nextprogpg		; calculate how many remain in this area
	cmp tmp
	bcc out
	ldx nextprogpg		; save page to allocate
	tya			; get back real # pages
	clc
	adc nextprogpg		; bump up the next prog pg
	sta nextprogpg
	rts
out:	fatal "out of rune space"
.endproc

;*****************************************************************************
.proc _progrun
; Run a user-space program. Searches CWD, then "/bin/"
; In:	A/X - filename to run (pascal-style len-prefixed string)
;	zarg - will get passed to program in A/X
; Out:	if found: clc, X=exit code
;	else: sec and X=$FF
	sta fname
	stx fname+1
	lda zarg	; save argument for later
	sta arg
	lda zarg+1
	sta arg+1
	lda #DIRSCAN_BIN ; start with bin, then down to cwd
dir:	sta dirnum
chk:	lda fname
	ldx fname+1
	ldy dirnum
	jsr _dirscan
	sta fndblk	; keep found block # and page ct
	stx fndblk+1
	sty zarg	; page count for load
	bcc found
	lda dirnum
	sec
	sbc #DIRSCAN_BIN-DIRSCAN_CWD
	cmp #DIRSCAN_CWD
	beq dir
	sec		; error
	ldx #$FF
	rts
found:	; allocate
	lda nextprogpg	; save allocation point
	pha
	tya
	pha		; save # pages for later relocator call
	jsr _progalloc	; allocate memory for the program (Y pages)
	; read
	stx pjmp+2	; vector for calling the program later
	txa		; resulting page #
	tay		; to Y for load
	lda fndblk
	ldx fndblk+1
	jsr _readblks	; read in the program
	; relocate
	pla		; get page ct back
	tay
	lda #$10	; programs always org at $1000
	ldx pjmp+2
	jsr reloc	; perform relocation
	; run
	lda arg	; arg saved from earlier
	ldx arg+1
	jsr pjmp	; run the program
	; free
	pla
	sta nextprogpg	; pop the allocation mark (frees prog mem)
	; done (exit code still in X)
	clc
	rts
pjmp:	jmp $1100	 ; self-mod above
; vars
	bit $1111
fname	= *-2

	bit $11
dirnum	= *-1

	bit $1111
fndblk	= *-2

	bit $1111
arg	= *-2
.endproc

;*****************************************************************************
_readblk:
; Read one block
; In:	A/X - block num
;	Y - target page
	pha
	lda #1		; alt entry point to read just one block
	sta zarg
	pla
.proc _readblks
; Read a number of blocks
; In:	A/X - block num
;	Y - target page
;	zarg - number of blocks
; Out:	aborts on failure; no need to check result.
cmd     = $42
unit    = $43
bufptr  = $44
blknum  = $46
	sta ld1+1	; mod code below
	stx ld2+1	; mod code below
	; save contents of $42-47 on stack
	ldx #0
:	lda $42,x
	pha
	inx
	cpx #6
	bne :-
	; set up parameters
	lda #1		; read
	sta cmd
	lda hddunit
	sta unit
	lda #0
	sta bufptr
	sty bufptr+1	; target page still in Y
ld1:	lda #$11	; self-modified above
	sta blknum
ld2:	lda #$22	; self-modified above
	sta blknum+1
lup:	jsr callhdd
	bcc_or_die "hdd read fail"
	inc blknum
	bne :+
	inc blknum+1
:	inc bufptr+1
	inc bufptr+1
	dec zarg	; more blocks?
	bne lup	; read more
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
; In: ;	A/X - block num to read
; Out: none (aborts on fail)
.proc readdirblk
	cmp curdirblk
	bne go
	cpx curdirblk+1
	bne go
	rts
go:	ldy #>dirbuf
	sta curdirblk	; cache for next time
	stx curdirblk+1
	jmp _readblk
.endproc

;*****************************************************************************
; Get first or next entry in a directory
; In:	clc:get first entry
;	    Y - dir to scan:
;		DIRSCAN_ROOT  = 0 = root
;		DIRSCAN_CWD   = 2 = cwd
;		DIRSCAN_RUNES = 4 = runes
;		DIRSCAN_BIN   = 6 = bin
;	sec:get next entry (Y ignored)
; Out:
;	clc on success, A/X - dir entry ptr, Y - name length
;	sec if no more entries
.proc _getdirent
	bcs adv
first:	lda #4
	sta dirent_nblks
	lda rootdirblk+1,y
	tax
	lda rootdirblk,y
rblk:	sta dirent_blknum
	stx dirent_blknum+1
	jsr readdirblk
	lda #2		; skip initial word (next free blk, or parent dir blk)
	ldy dirent_nblks
	cpy #4
	beq :+
	lda #0		; second and subsequent blocks start at offset zero
:	ldx #>dirbuf
ckent:	sta dirent_pscan
	stx dirent_pscan+1
	jsr getlen
	beq nxblk
	rts		; found a valid entry - c already clr, A/X already has ptr
nxblk:	lda dirent_blknum
	ldx dirent_blknum+1
	adc #1		; carry already clear from getlen
	bcc :+
	inx
:	dec dirent_nblks
	bne rblk
	sec		; out of blks
	rts
adv:	jsr getlen
	ldx dirent_pscan+1
	tya
	adc #4		; skip len, blk num, npages (carry already clr from getlen)
	adc dirent_pscan
	bcc ckent
	inx
	bne ckent	; always taken
dirent_pscan = *+1
getlen:	ldy $1111
	clc
	rts
.endproc

;*****************************************************************************
; Scan directory for a file - optional wildcard at end
; In:
; 	A/X - pascal-style (len-prefixed) filename to scan for
;	Y - dir to scan:
;		DIRSCAN_ROOT  = 0 = root
;		DIRSCAN_CWD   = 2 = cwd
;		DIRSCAN_RUNES = 4 = runes
;		DIRSCAN_BIN   = 6 = bin
; Out:
;	clc on success, sec if not found
;	A/X - blk num
;	Y - length in pages
wildscan:
	sec
	bcs *+3		; skip clc below
.proc _dirscan
	clc
fname	= ptmp		; len 2
pscan	= ptmp2		; len 2
wflg	= tmp		; len 1
nmlen	= tmp2		; len 1
	sta fname
	stx fname+1
	lda #0
	ror		; carry -> bit $80; clears carry as well
	sta wflg
nxtent:	jsr getdirent	; carry is clr first time, set subsequent times
	bcc ckent
	rts		; out of entries - error return
ckent:	sta pscan
	stx pscan+1
	sty nmlen	; save length for later
	tya
	tax		; count for non-wild name chk
	ldy #0
	cmp (fname),y
	beq cknam	; if same len, do normal chk
	bcc skip	; if entry name shorter than target name, skip.
	bit wflg	; ent name is longer than target...
	bpl skip	; ...so if no wild allowed, skip this ent
	lda (fname),y	; len of *target* name
	tax		; ...is count for name chk
cknam:	iny
	lda (pscan),y
	cmp (fname),y
	bne skip
	dex
	bne cknam
match:	ldy nmlen	; length of name...
	iny		; 	+1 gets us to blknum
	lda (pscan),y	; blk num lo
	pha
	iny
	lda (pscan),y	; blk num hi
	tax
	iny	
	lda (pscan),y	; length in pages
	tay
	pla		; get blk num lo back
	clc		; signal success
	rts
skip:	sec		; sec = get next entry
	jmp nxtent
.endproc

;*****************************************************************************
.proc _getsetcwd
; clc = get -> A/X; sec = set from A/X
	bcs set
get:	lda cwdblk
	ldx cwdblk+1
	rts
set:	sta cwdblk
	stx cwdblk+1
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
	bmi got
	adc #$28
	dex
	bmi got
	adc #$28
got:	sta txtptre
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
_getxy:
	ldx cursx
	ldy cursy
	rts

;*****************************************************************************
.proc _clreol
; Clear current line from curx to end
; Doesn't modify cursx
	ldy cursx
	lda #$A0
lup:	sta (txtptre),y
	iny
	cpy #40
	bne lup
	rts
.endproc

;*****************************************************************************
.proc _clrscr
; Clear entire screen
; leaves with cursx=0, cursy=0
	jsr zero
loop:	jsr _clreol
	inc cursy
	jsr bascalc
	lda cursy
	cmp #24
	bne loop
zero:	ldx #0
	ldy #0
	jmp _gotoxy
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
	beq scrl
	jsr bascalc
	jmp restregs
	; end of screen - scroll it up
scrl:	ldy #0
	jsr _gotoxy	; x is already zero
sc1:	lda txtptre
	sta st+1	; modifies code below
	lda txtptre+1
	sta st+2
	inc cursy
	jsr bascalc
	ldy #39
cp:	lda (txtptre),y
st:	sta $1111,y	; self-modified above
	dey
	bpl cp
	lda cursy
	cmp #23
	bne sc1
	jsr _clreol
	jmp restregs
.endproc

;*****************************************************************************
.proc _prbyte
; preserves all regs except P
	pha
	pha
	lsr
	lsr
	lsr
	lsr
	jsr prdig
	pla
	and #$F
	jsr prdig
	pla
	rts
prdig:	cmp #$A
	bcs letr
	adc #'0'
	jmp cout
letr:	clc
	adc #'A'-$A
	jmp cout
.endproc

;*****************************************************************************
.proc _rdkey
; In: 	(none)
; Out:	A - the key pressed (in lo-bit ascii)
	jsr inv	; display cursor
:	lda $C000
	bpl :-
	and #$7F
	bit a3flg
	bpl got
	; On Apple ///, convert to lower-case unless shift
	cmp #'A'
	bcc got
	cmp #'Z'+1
	bcs got
	pha
	lda $C008
	lsr
	lsr		; get bit 2 = shift key
	pla
	bcs got	; if shifted, leave char as-is
	clc
	adc #'a'-'A'	; if not shifted, convert to lower-case
got:	bit $C010	; clear keyboard strobe
	pha
	jsr inv	; erase cursor
	pla
	rts
inv:	ldy cursx
	lda (txtptre),y
	eor #$80
	sta (txtptre),y
	rts
.endproc

;*****************************************************************************
.proc reloc
; Relocator
; Input:
;	A=src page
;	X=dst/current page
;	Y=num pages
srcpage = tmp
dstpage = tmp+1
npages = tmp2
pscan = ptmp
	sta srcpage
	stx dstpage
	stx pscan+1
	sty npages
	lda #0
	sta pscan
	tay		; Y is normally zero
inst:	lda (pscan),y	; read next instruction
	beq sbrk	; special case for brk
	tax
	cmp #$D8	; check for CLD which marks upcoming LDA/LDX/LDY of a page #
	beq iscld
notcld:	lda inslen_t,x
	cmp #3
	beq len3
	; len < 3, so carry is now clear
adv:	;clc		; carry is already clear when we arrive here
	adc pscan
	sta pscan
	bcc inst
	inc pscan+1
	lda pscan+1
	sec
	sbc dstpage
	cmp npages
	bcc inst
stop:	rts

iscld:	iny		; got CLD
	lda (pscan),y	; check next byte
	dey
	and #$F0	; is it A0, A2, A9 (LDY, LDX, LDA)?
	cmp #$A0	; roughly is good enough
	bne notcld	; if not, treat as normal 1-byte inst
	; otherwise, treat as 3-byte and check for reloc

len3:	;sec		; fyi we got here via beq, so carry is already set
	ldy #2
	lda (pscan),y	; high byte of operand
	sbc srcpage	; find page offset; carry already set
	bcc skip	; before range? skip
	cmp npages	; after range? skip
	bcs skip
	; carry is now clear
	adc dstpage	; adjust for new location
	sta (pscan),y	; and store it
skip:	lda #3		; back to 3-byte len
	ldy #0		; normal state again
	clc
	bcc adv	; always taken

sbrk:	iny
	lda (pscan),y	; check 1st byte of str
	cmp #$CB
	beq chkz
	cmp #$DB
	bne bbrk	; if not CB or DB, it's a normal brk
chkz:	iny
	lda (pscan),y
	bne chkz	; scan for zero-terminator
	iny		; and one past for next ins
	tya		; now we have the len
	ldy #0
	clc
	bcc adv	; always taken

bbrk:	iny
	lda (pscan),y	; one more byte
	beq stop	; 3 zeros in a row --> stop relocation, data section begun
	ldy #0
	lda #1
	clc
	bcc adv	; otherwise, a real brk (always taken)
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
	beq irq	; for now, do nothing on real IRQ
	tsx
	lda $102,x	; ret addr lo byte
	sec
	sbc #1		; back to 1st byte after brk
	sta ld1+1	; mod self below
	sta ld2+1
	sta ld3+1
	tay		; save for later
	lda $103,x	; ret addr hi byte
	sbc #0
	sta ld1+2	; mod self below
	sta ld2+2
	sta ld3+2
	tax		; save for later
ld1:	lda $1111	; first byte
	cmp #$CB	; invalid 6502 instruc - WAI on 65816
	beq prnt
	cmp #$DB	; invalid 6502 instruc - STP on 65816
	beq ldst
	jmp bkpnt	; BRK+other means actual breakpoint
ldst:	iny		; point to first byte of the str
	bne :+
	inx
:	sty areg	; load str - put its ptr in A/X (loaded on ret)
	stx xreg
	ldx #1
ld2:	lda $1111,x
	beq adv
	inx
	bne ld2		; always taken
prnt:	ldx #1		; X - index in string
	ldy #0		; Y - percent mode (1=on)
	beq ld3		; always taken
scanz:	cpy #0
	bne pct
	cmp #'%'
	bne dopr
	iny		; set percent mode
	bne next	; always taken
dopr:	jsr _cout	; print char
next:	inx
ld3:	lda $1111,x	; find terminator
	bne scanz
adv:	txa
	clc		; no need to add 1, since brk already did it
	tsx
	adc $102,x	; ret adr lo
	sta $102,x
	bcc :+
	inc $103,x	; ret adr hi
:	lda areg
	ldx xreg
	ldy yreg
irq:	rti
pct:	dey		; turn off percent mode
	cmp #'s'
	beq pstr
	cmp #'x'
	bne dopr
phex:	lda #'$'
	jsr cout
	lda xreg
	jsr prbyte
	lda areg
	jsr prbyte
	jmp next
pstr:	lda areg
	sta psl1+1
	sta psl2+1
	sta psl3+1
	lda xreg
	sta psl1+2
	sta psl2+2
	sta psl3+2
	ldy #0
psl1:	lda $1111,y	; self-mod above
	cmp #32
	bcc plen
pzt:	iny
psl2:	lda $1111,y	; self-mod above
	beq psdn
	jsr cout
	jmp pzt
psdn:	jmp next
plen:	pha
pslp:	pla
	beq psdn
	sec
	sbc #1
	pha
	iny
psl3:	lda $1111,y	; self-mod above
	jsr cout
	jmp pslp

; breakpoint (BRK+00) - print location and registers
bkpnt:	jsr _crout	; always start on next new line
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
	jsr preg
	ldx xreg
	lda #'X'
	jsr preg
	ldx yreg
	lda #'Y'
	jsr preg
	tya		; get back p-reg val, saved all the way up there
	tax
	lda #'P'
	jsr preg
	tsx		; happily we've popped everything, so this is the real caller S reg
	lda #'S'
	jsr preg
	jsr _crout
	; jump to platform-specific system monitor for now
	jmp gosysmon

preg:	jsr _cout
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
	jsr _crout	; always start on next fresh line
	print "Fatal error: "
	ldy #0
lup:	lda (ptmp),y
	beq done
	jsr _cout
	iny
	bne lup		; always taken
done:	jsr _crout
	jmp gosysmon
.endproc

;*****************************************************************************
.proc gosysmon
	bit a3flg
	bpl a2
a3:	lda cursy
	sta $5D
	jsr $FBC7	; a3 bascalc
	jmp a3mon
a2:	ldx cursy
	dex
	dex
	stx $25
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

; program allocation global vars
nextprogpg:	.byte 0
limitprogpg:	.byte 0
lastprogpg:	.byte 0

; disk-related vars
hddunit:	.byte 0
curdirblk:	.word 0

; various directories (keep these together in order)
rootdirblk:	.word 1
cwdblk:		.word 1
runesdirblk:	.word 0
bindirblk:	.word 0

; State for getdirent
dirent_blknum:	.word 0
dirent_nblks:	.byte 0

runefn:		.byte 2, "00" ; length + 2 digits

s_runes:	.byte 5, "runes"
s_bin:		.byte 3, "bin"
s_shell:	.byte 5, "shell"

;*****************************************************************************
	.align 32
rune0vecs:	; rune 0 = kernel services
	jmp _resetrunes
	jmp _fatal
	jmp _readblks
	jmp _getdirent
	jmp _dirscan
	jmp _progalloc
	jmp _progrun
	jmp _getsetcwd
	.align 32,$EA	; rune vecs always total 32 bytes
rune1vecs:	; rune 1 = text services
	jmp _clrscr
	jmp _gotoxy
	jmp _cout
	jmp _crout
	jmp _prbyte
	jmp _rdkey
	jmp _getxy
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