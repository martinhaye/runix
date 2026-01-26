; Rune 5 - Pool (Garbage-collected pool of variable-sized objects)
; Jump vectors at $CA0-$CBF

        .org $2000

.include "base.i"
.include "kernel.i"
.include "pool.i"

	; API jump vectors
	jmp _pool_init
	jmp _pool_alloc
	;jmp _pool_free
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
	ldy #0
	lda (pool_iptr),y	; index's first data page to start scan
chkpg:	sta pool_dptr+1
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
.proc pool_free
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
.proc pool_setsize
	sty pool_objnum
	iny
	lda (pool_iptr),y
	sta pool_dptr+1
	dey
	lda (pool_iptr),y
	tay
	txa
	cmp (pool_dptr),y	; get current len
	beq nochg
	; TODO: handle change of size cases: 
	;   (1) end of pg and fits; 
	;   (2) same pg and fits; 
	;   (3) diff pg needed
nochg:	iny
	sta (pool_dptr),y	; scramble contents per contract even if no move
	rts
.endproc

;*****************************************************************************
; variables 
		.byt 0,0,0
pool_objlen:	.byt 0
pool_objid:	.byt 0
pool_objoff:	.byt 0
pool_marker:	.byt 0