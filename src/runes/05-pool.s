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
	jmp _pool_setlen
	jmp _pool_resize
	jmp _pool_total
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
alt:	; alternate entry point if obj id already known
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
	iny
	lda pool_dptr+1
	sta (pool_iptr),y	; record addr hi in index
	dey
	txa			; obj start again
	sta (pool_iptr),y	; record addr lo in index
	ldx pool_dptr+1		; on return: obj id in Y, addr in AX
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
	sta (pool_dptr),y	; simply adjust the next-allocation offset
	rts

dblfr:	fatal "pool-dbl-free"
.endproc

;*****************************************************************************
.proc _pool_setlen
; on entry, Y=objnum, X=requested len
	sty pool_objid		; save obj id for later use if moving
	iny
	lda (pool_iptr),y
	sta pool_dptr+1
	sta sma+2
	sta smc+2
	dey
	lda (pool_iptr),y
	tay
	txa			; requested len
	cmp (pool_dptr),y	; vs current len
	beq nochg		; if len not changing, early out
  ; 40 cyc
	; check if obj already at the end of its page (optimal)
sma:	cpy $1001		; self-mod above - check byte 1 of dpage
	bne moveit
	; already at end of page - is there enough space for the new size?
	sty smb+1
	;txa			; requested len already in A
	;sec			; C already set (because cpy was eq above)
smb:	adc #11			; add obj offset to calc new end of pg
	bcs moveit
	; new size fits - adj len and page end
smc:	sta $1001		; store new end of pg
	txa
	sta (pool_dptr),y	; store new len
  ; 65 cyc
nochg:	ldx pool_dptr+1		; exit with ptr in AX
	tya
	rts

moveit:	txa
	pha			; save requested len on stack
	ldy pool_objid
	jsr _pool_free		; collapse current space used by obj
	pla
	sta pool_objlen		; restore requested len
	jmp _pool_alloc::alt	; re-allocate - alt entry because we know id
.endproc

;*****************************************************************************
.proc _pool_resize
	sty pool_objid
	sta pool_objlen
	pagealloc		; temporary data page to save obj contents
	stx _sm1+2
	stx _sm2+2
	ldy pool_objid
	iny
	lda (pool_iptr),y	; obj current data page
	sta pool_dptr+1
	dey
	lda (pool_iptr),y	; obj offset
	tay
	lda (pool_dptr),y	; get object's current length
	beq cpdone		; if zero-len, no copying needed
	sta _sb1+1		; loop bound for copy
	ldx #0
cpout:	iny
	lda (pool_dptr),y
_sm1:	sta modaddr,x
	inx
_sb1:	cpx #11			; self-modified above - current obj len
	bne cpout
cpdone:	; now set the new length
	ldy pool_objid
	ldx pool_objlen
	jsr _pool_setlen
	lda pool_objlen
	beq fin
	sta _sb2+1		; loop bound for copy
	ldx #0
	; note - len already set by setlen, so we only need to copy data bytes
cpin:	iny
_sm2:	lda modaddr,x
	sta (pool_dptr),y
	inx
_sb2:	cpx #11			; self-modified above - new obj len
	bne cpin
fin:	pagefree _sm1+2		; free the temporary copy page
	rts
.endproc

;*****************************************************************************
.proc _pool_total
	lda #0
	sta pool_nbytes
	sta pool_nbytes+1
	sta pool_npages
pglup:	ldy #0
	lda (pool_iptr),y	; link to data page
	beq fin			; if no data pages, we're done
nxtpg:	sta pool_dptr+1
	inc pool_npages		; count this page
	iny
	lda (pool_dptr),y
	sta pool_objoff		; save offset of last obj on page
	iny
objlup:	cpy pool_objoff
	beq pgend		; if at end of page, move to next
	lda (pool_dptr),y	; get length of obj
	sta pool_objlen		; save for later
	sec			; add 1 to account for length byte itself
	adc pool_nbytes
	sta pool_nbytes
	bcc :+
	inc pool_nbytes+1
:	tya
	sec			; again adding 1 for the length byte itself
	adc pool_objlen
	tay
	bcc objlup
corr:	fatal "pool-pg-corrupt"
pgend:	ldy #0
	lda (pool_dptr),y	; next data page
	bne nxtpg
	; out: AX = total space used in pool, Y = total number of allocated pages
fin:	ldax pool_nbytes
	ldy pool_npages
	rts
.endproc

;*****************************************************************************
; variables 
		.byt 0,0,0
pool_objlen:	.byt 0
pool_objid:	.byt 0
pool_objoff:	.byt 0
pool_npages:	.byt 0
pool_nbytes:	.word 0