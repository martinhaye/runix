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
; 00: Number of pages in the pool
; 01: First data page
; 02: Last-allocated object ID
; 03: Currently-allocating data page
; 04..FF: pointers for objects 04..FE (all even, and objs 0-2 are reserved)
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
	lda #1
	sta (pool_iptr),y	; 00: number of pages
	iny
	inx
	txa
	sta (pool_iptr),y	; 01: first data page
	iny
	lda #$FE		; fake in last allocated obj id
	sta (pool_iptr),y
	iny
	; Clear the remainder of the index page
	lda #0
:	sta (pool_iptr),y
	iny
	bne :-
	; Now init the data page
	stx pool_dptr+1
	; fall through to init_data_page
.endproc

.proc init_data_page
	; Initialize a new data page - assumes pool_dptr is set
	ldy #0
	lda #2
	sta (pool_dptr),y	; 00: offset of next free byte
	iny
	lda #0
	sta (pool_dptr),y	; 01: next data page (0 for last)
	rts
.endproc

;*****************************************************************************
.proc _pool_alloc
	sta pool_objlen		; save object len for later

	; Find an unused id
	ldy #2
	lda (pool_iptr),y	; last obj id
	tay
	clv			; use V to track number of passes
	iny
nxtid:	iny
	bne :+
	bvs idfull		; if second pass, give up
	setv			; prevent infinite rewinds
	ldy #4
:	iny			; check hi-byte for empty
	lda (pool_iptr),y
	bne nxtid
fndid:	dey
	sty pool_objid		; stash the id for now
	tya			; record ID for next alloc scan
	ldy #2
	sta (pool_iptr),y

	; Find space on a data page
	ldy #3
	lda (pool_iptr),y	; index's first data page to start scan
	sta pool_marker		; marker to prevent infinite rewinds
	bne chksp		; always taken
chkpg:	cmp pool_marker
	beq newpg		; we've checked every page - need a new one
chksp:	sta pool_dptr+1
	ldy #0
	lda (pool_dptr),y	; offset of next free byte
	tax			; stash it for possible use
	sec			; 1 extra byte for length prefix
	adc pool_objlen
	bcc room		; if we found space - go use it
	iny			; Y=1 -> offset of next data page
	lda (pool_dptr),y
	bne chkpg
	lda (pool_iptr),y	; loop back to index's first data page
	bne chkpg		; always taken

newpg:	ldy #1
	jsr progalloc		; allocate 1 page for more data
	stx pool_dptr+1
	ldy #0
	lda (pool_iptr),y	; increment count of pages
	clc
	adc #1
	sta (pool_iptr),y
	iny
	; link in at start of page list
	lda (pool_iptr),y	; prev data page
	sta (pool_dptr),y
	txa			; new data page
	sta (pool_iptr),y
	ldx #2			; put the new obj at the start of usable space
	lda pool_objlen
	sec
	adc #2			; calc offset of next usable

	; Record the new object. Note we don't init the data field, only the len.
room:	sta (pool_dptr),y	; advance offset of next free byte
	txa			; back to start of obj
	tay
	lda pool_objlen
	sta (pool_dptr),y	; save len of new obj
	lda pool_dptr+1
	ldy #3
	sta (pool_iptr),y	; record page with known free space, for next time
	ldy pool_objid
	txa			; obj start again
	sta (pool_iptr),y	; record addr lo
	iny
	lda pool_dptr+1
	sta (pool_iptr),y	; record addr hi
	dey			; return obj id in Y
	rts

idfull:	fatal "pool-ids-full"
.endproc

	; variables 
		.byt 0,0,0
pool_objlen:	.byt 0
pool_objid:	.byt 0
pool_marker:	.byt 0