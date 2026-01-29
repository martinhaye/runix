; Rune 5 - Pool (Garbage-collected pool of variable-sized objects)
; Jump vectors at $CA0-$CBF

        .org $2000

.include "base.i"
.include "kernel.i"
.include "pool.i"

	; API jump vectors
	jmp _pool_init
	jmp _pool_alloc
	jmp _pool_free
	jmp _pool_setsize
	;jmp _pool_resize
	;jmp _pool_total
	;jmp _pool_collect
	.align 32,$EA

;*****************************************************************************
; Pool index page structure:
; 00: First data page
; 01: Highest allocated object ID
; 02..FF: pointers for objects 02..FE (all even, objs 0,1,3,5... are invalid)
;
; Pool data page structure:
; 00: Offset of next free byte
; 01: Next data page (0 for last)
; 02..FF: data in length-prefixed format. Len=01..FE.

;*****************************************************************************
.proc _pool_init
	lda #0
	sta pool_iptr+1		; our zp pointers are always page pointers
	sta pool_dptr+1
	ldy #2
	jsr progalloc		; allocate 2 pages - index and first data
	stx pool_iptr+1
	; Initialize index page
	ldy #0
	inx
	txa
	sta (pool_iptr),y	; 00: first data page
	iny
	lda #0			; last allocated obj id
	sta (pool_iptr),y
	iny
	; Clear the remainder of the index page
	lda #0
:	sta (pool_iptr),y
	iny
	bne :-
	; Now init the data page
	; fall through to init_data_page
.endproc

.proc init_data_page
	; Initialize a new data page - page in X
	stx pool_dptr+1
	ldy #0
	tya
	sta (pool_dptr),y	; 00: next data page (0 for last)
	iny
	lda #2
	sta (pool_dptr),y	; 00: offset of next free byte
	lda pool_iptr+1		; return pool index page in A
	rts
.endproc

;*****************************************************************************
.proc _pool_alloc
	sta pool_objlen		; save object len for later

	; Find an unused id
	ldy #1
	lda (pool_iptr),y	; last obj id
	tay
	clv			; use V to track number of passes
	iny
nxtid:	iny
	bne :+
	bvs idfull		; if second pass, give up
	set_v			; prevent infinite rewinds
	ldy #2
:	iny			; check hi-byte for empty
	lda (pool_iptr),y
	bne nxtid
fndid:	dey
	sty pool_objid		; stash the id for now
	tya			; remember ID for next alloc scan
	ldy #1
	sta (pool_iptr),y

	; Find space on a data page
alt1:	; alternate entry point if obj id already known
	ldy #0
	lda (pool_iptr),y	; index's first data page to start scan
chkpg:	sta pool_dptr+1
alt2:	; alternate entry point if obj id and target page already known
	ldy #1
	lda (pool_dptr),y	; offset of next free byte
	tax			; stash it for possible use
	sec			; 1 extra byte for length prefix
	adc pool_objlen
	bcc room		; if we found space - go use it
	dey			; Y=0 -> offset of next data page
	lda (pool_dptr),y
	bne chkpg

	; no room on existing pages - need a new one
newpg:	pagealloc		; allocate a new data page
	stx pool_dptr+1
	; link in at start of page list
	ldy #0
	lda (pool_iptr),y	; prev data page
	sta (pool_dptr),y
	txa			; new data page
	sta (pool_iptr),y
	ldx #2			; put the new obj at the start of usable space
	lda pool_objlen
	sec
	adc #2			; add header size to obj len to calc next usable
	iny			; need Y=1 for recording new free offset

	; Record the new object. Note we don't init the data field, only the len.
room:	sta (pool_dptr),y	; advance offset of next free byte
	txa			; back to start of obj
	tay
	lda pool_objlen
	sta (pool_dptr),y	; save len of new obj
	ldy pool_objid
	txa			; obj start again
	sta (pool_iptr),y	; record addr lo in index
	iny
	lda pool_dptr+1
	sta (pool_iptr),y	; record addr hi in index
	dey			; return obj id in Y
	rts

idfull:	fatal "pool-ids-full"
.endproc

;*****************************************************************************
.proc _pool_free
	lda (pool_iptr),y	; data ptr lo
	sta pool_objoff
	iny
	lda (pool_iptr),y	; data page
	beq dblfr		; if already freed - error out
	sta pool_dptr+1
	sta sma+2		; self-mod for move later
	lda #0
	sta (pool_iptr),y	; zero out the pointer (just hi-byte is sufficient)
	ldy pool_objoff
	lda (pool_dptr),y	; get object's length
	clc
	adc #1			; add 1 for len byte itself
	ldy #1
	cmp (pool_dptr),y	; check if this is last obj on page
	beq islast
	sta pool_objlen		; save len+1 for later use
	sta sma+1		; self-mod for move later
	; adjust index entries for objects following the freed one
	lda (pool_iptr),y	; last allocated obj id (Y=1 already)
	tay
alup:	dey
	lda (pool_iptr),y	; chk data page
	dey
	cmp pool_dptr+1
	bne anext
	lda (pool_iptr),y	; data offset
	cmp pool_objoff
	bcc anext		; if blk is before freed one, skip it
	sec			; already adjusted for len byte itself
	sbc pool_objlen		; blk is moving
	sta (pool_iptr),y
anext:	cpy #2			; stop before we reach the header
	bne alup
	; now compact the data page
	dey			; now Y=1
	lda (pool_dptr),y	; next byte that would be allocated
	sec
	sbc pool_objlen		; adjust offset
	sta (pool_dptr),y
	sta smb+1		; save limit for copy
	ldy pool_objoff
move:
sma:	lda modaddr,y		; self-modified earlier - including lo=objlen+1
	sta (pool_dptr),y
	iny
smb:	cpy #modn		; self-modified earlier
	bne move
	rts

	; obj is last on page - our work is easy
islast:	lda pool_objoff
	sta (pool_dptr),y	; next offset to allocate
	rts

dblfr:	fatal "pool-dbl-free"
.endproc

;*****************************************************************************
.proc _pool_setsize
; on entry, Y=objnum, X=requested len
	sty pool_objid		; save obj id for later use if moving
	iny
	lda (pool_iptr),y
	sta pool_dptr+1
	dey
	lda (pool_iptr),y
	sta pool_objoff		; for later use
	tay
	lda (pool_dptr),y	; get current len
	sta pool_objlen		; for later use
	txa			; get requested len
	sec
	sbc pool_objlen		; calc how much len is changing
	beq nochg		; if same len, just scramble and exit
; 46/47 cyc to here ^^^
	ldy #1
	bcc canfit		; if len decreasing, it'll fit on cur pg
	; A=positive change in len
	clc
	adc (pool_dptr),y	; now A=page size after change
	bcs diffpg		; if past end of pg, have to move to diff pg
; 59/60 cyc to here ^^^
canfit:	; we've determined the new obj size will fit on its current page
	; check if obj is already at the end of its page
	lda pool_objoff		; add cur offset...
	sec			; ...to objlen +1
	adc pool_objlen		; ...equals current end of obj	
	cmp (pool_dptr),y	; ...vs current end of page
	bne swap		; if not at end of page, have to swap it up
; 77/78 cyc to here ^^^
inplc:	; determined we can resize the obj right where it is
	txa			; new len...
	sec			; ...+1
	adc pool_objoff		; ...plus offset
	sta (pool_dptr),y	; ...is new end of pg
	ldy pool_objoff
	txa
	sta (pool_dptr),y	; store new len
; 103 cyc to here ^^^
nochg:	iny
	sta (pool_dptr),y	; scramble contents per contract even if no move
	rts
swap:	; obj will fit on pg but isn't last - free and swap
	jsr freeit
	jmp _pool_alloc::alt2	; re-allocate on same page
diffpg:	; obj has to go on a diff pg - free and totally reallocate
	jsr freeit
	jmp _pool_alloc::alt1	; re-allocate on diff page
freeit:	; subroutine
	txa
	pha			; save requested len on stack
	ldy pool_objid
	jsr _pool_free		; collapse current space used by obj
	pla
	sta pool_objlen		; restore requested len
	rts
.endproc

;*****************************************************************************
; variables 
		.byt 0,0,0
pool_objlen:	.byt 0
pool_objid:	.byt 0
pool_objoff:	.byt 0
pool_marker:	.byt 0