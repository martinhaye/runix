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
	jmp _pool_qreduce
	jmp _pool_resize
	jmp _pool_total
	.align 32,$EA

;*****************************************************************************
; Pool index page structure:
; 00: First data page
; 80: Highest allocated object ID
; 01-7F: lo byte of pointers for objects 01..7F
; 81-FF: hi byte of pointers for objects 01..7F
;
; Pool data page structure:
; 00: Offset of next free byte
; 01: Next data page (0 for last)
; 02..FF: data in length-prefixed format. Len=01..FE.

;*****************************************************************************
.proc _pool_init
	lda #0
	sta pool_ilptr	; our zp pointers always have fixed low byte
	sta pool_dptr
	sta pool_slowpath
	tay
	lda #$80
	sta pool_ihptr
	ldy #2
	jsr progalloc		; allocate 2 pages - index and first data
	stx pool_ilptr+1
	stx pool_ihptr+1
	; First byte of index page points to first data page
	inx
	txa
	; Clear index page - first byte is the data page, rest are zero
	ldy #0
:	sta (pool_ilptr),y
	lda #0
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
	lda pool_ilptr+1	; return pool index page in A
	rts
.endproc

;*****************************************************************************
.proc _pool_alloc
	sta pool_objlen		; save object len for later

	; Find an unused id
	ldy #0
	lda (pool_ihptr),y	; last allocated obj id
	tay			; ...start scanning from there
	clv			; use V to track number of passes
nxtid:	iny
	bpl :+
	bvs idfull		; if second pass, give up
	set_v			; prevent infinite rewinds
	ldy #1
:	lda (pool_ihptr),y	; check hi byte for empty
	bne nxtid
fndid:	sty pool_objid		; stash the id for now
	tya			; remember ID for next alloc scan
	ldy #0
	sta (pool_ihptr),y

	; Find space on a data page
alt:	; alternate entry point if obj id already known
	ldy #0
	lda (pool_ilptr),y	; index's first data page to start scan
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
	lda (pool_ilptr),y	; prev data page
	sta (pool_dptr),y	; now becomes second data page
	txa			; new data page
	sta (pool_ilptr),y	; becomes first data page
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
	lda pool_dptr+1
	sta (pool_ihptr),y	; record addr hi in index
	txa			; obj start again
	sta (pool_ilptr),y	; record addr lo in index
	ldx pool_dptr+1		; on return: obj id in Y, addr in AX
	rts

idfull:	fatal "pool-ids-full"
.endproc

;*****************************************************************************
.proc _pool_free
	lda (pool_ilptr),y	; data ptr lo
	sta pool_objoff
	lda (pool_ihptr),y	; data ptr hi (data page)
	beq dblfr		; if already freed - error out
	sta pool_dptr+1		; data page
	sta sma+2		; self-mod for move later
	lda #0
	sta (pool_ihptr),y	; zero out the pointer (just hi-byte is sufficient)
	ldy pool_objoff
	lda (pool_dptr),y	; get object's length
	tax			; stash for later use
	sec
	adc pool_objoff		; add object's offset to length, +1 for len byte itself
	ldy #1
	cmp (pool_dptr),y	; check if this is last obj on page
	beq islast
	inx			; calc len+1 - that's the amount that's collapsing
	stx pool_slowpath	; mark that a slow path was taken
	stx pool_objlen		; save len+1 for later use
	stx sma+1		; self-mod for move later
	; adjust index entries for objects following the freed one
	ldy #0
	lda (pool_ihptr),y	; last allocated obj id
	tay
alup:	lda (pool_ihptr),y	; chk object's data page
	cmp pool_dptr+1
	bne anext
	lda (pool_ilptr),y	; object's data offset
	cmp pool_objoff
	bcc anext		; if blk is before freed one, skip it
	sec			; already adjusted for len byte itself
	sbc pool_objlen		; blk is moving
	sta (pool_ilptr),y
anext:	dey			; process all objs
	bne alup		; don't do offset zero (it's not an obj)
	; now compact the data page
	iny			; now Y=1
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
	lda (pool_ihptr),y	; obj dpage
	sta pool_dptr+1
	sta sma+2
	sta smc+2
	lda (pool_ilptr),y	; obj offset in dpg
	tay
	txa			; requested len
	cmp (pool_dptr),y	; vs current len
	beq nochg		; if len not changing, early out
  ; 37 cyc
	; check if obj is already the last on its page (for fast path)
	tya
	sec			; add 1 for len byte itself
	adc (pool_dptr),y	; calculate end of object
sma:	cmp $1001		; self-mod above - check byte 1 of dpage
	bne moveit
	; already at end of page - is there enough space for the new size?
	sty smb+1
	txa			; requested len
	;sec			; C already set (because cmp was eq above)
smb:	adc #modn		; add obj offset to calc new end of pg
	bcs moveit		; if it would overflow page, move the obj
	; new size fits - adj len and page end
smc:	sta $1001		; store new end of pg
	txa
	sta (pool_dptr),y	; store new len
  ; 73  cyc
nochg:	ldx pool_dptr+1		; exit with ptr in AX
	tya
	rts

moveit:	clc			; modified by _pool_resize to be sec
	stx pool_newlen
	stx pool_slowpath	; mark that a slow path was taken
	bcs save		; normal case, we don't save the data
move2:	ldy pool_objid
	jsr _pool_free		; collapse current space used by obj
	lda pool_newlen
	sta pool_objlen		; restore requested len
	jmp _pool_alloc::alt	; finish by re-allocating - alt entry because we know id

	; in resize mode: save original contents to a temp page
save:	txa			; new len comes in X
	cmp (pool_dptr),y	; check against old len
	bcc :+
	lda (pool_dptr),y	; clamp to min (newlen, oldlen)
:	cmp #0			; A is now minlen - is it zero?
	beq move2		; if min len is zero, no copying needed
	sta _o2+1		; self-modify loop bounds
	sta _i2+1
	pagealloc		; get a temporary data page
	stx _o1+2		; self-modify out-copy loop
	stx _i1+2		; self-modify in-copy loop
	ldy pool_objid
	lda (pool_ilptr),y	; obj offset again
	tay
	ldx #0
outlup:	iny			; no need to copy len byte
	lda (pool_dptr),y
_o1:	sta modaddr,x
	inx
_o2:	cpx #11			; self-modified above - len to copy
	bne outlup
	; now we're ready to do the free and reallocate
	jsr move2
	; restore original contents (up to new len)
	tay			; obj offset from alloc was in AX, get offset into Y
	pha			; save offset for returning later
	ldx #0
	; note - len already set by pool_alloc above, so we only need to copy data bytes
inlup:	iny
_i1:	lda modaddr,x
	sta (pool_dptr),y
	inx
_i2:	cpx #11			; self-modified above - len to copy
	bne inlup
inrt:	pagefree _i1+2		; free the temporary copy page
	pla			; return new offset...
	ldx pool_dptr+1		; ...and page
	rts

.endproc

;*****************************************************************************
.proc _pool_qreduce
; reduce size of last allocated blk to X bytes
; Only safe if no other pool operations have been performed since last alloc
	ldy pool_objid
	lda (pool_ilptr),y	; object's data offset
	tay
	sta sma+1		; self-modify for add later
	txa			; requested new len
	sta (pool_dptr),y	; store new len
	clc
sma:	adc #modn		; calculate new end of page (self-modified above)
	ldy #1
	sta (pool_dptr),y	; store new end of page
	rts
.endproc

;*****************************************************************************
.proc _pool_resize
	; modify _pool_setlen so it will save and restore contents
	lda #$38	; sec
	sta _pool_setlen::moveit
	; now run it
	jsr _pool_setlen
	; and put it back to normal
	ldy #$18	; clc
	sty _pool_setlen::moveit
	rts
.endproc

;*****************************************************************************
.proc _pool_total
	lda #0
	sta pool_nbytes
	sta pool_nbytes+1
	sta pool_npages
pglup:	ldy #0
	lda (pool_ilptr),y	; link to data page
	beq fin			; if no data pages, we're done
nxtpg:	sta pool_dptr+1
	inc pool_npages		; count this page
	iny
	lda (pool_dptr),y
	sta pool_objoff		; save offset of last obj on page
	iny
	tya
objlup:	cpy pool_objoff
	beq pgend		; if at end of page, move to next
	sec			; again adding 1 for the length byte itself
	adc (pool_dptr),y
	tay
	bcc objlup
corr:	fatal "pool-pg-corrupt"
pgend:	lda pool_objoff		; end of page
	sec
	sbc #2			; minus 2 byte header = total data bytes
	clc
	adc pool_nbytes
	sta pool_nbytes
	bcc :+
	inc pool_nbytes+1
:	ldy #0
	lda (pool_dptr),y	; next data page
	bne nxtpg
	; out: AX = total space used in pool, Y = total number of allocated pages
fin:	clc
	lda pool_slowpath
	beq :+
	sec			; set carry if any slow path was taken since last total
:	lda #0
	sta pool_slowpath
	ldax pool_nbytes
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
pool_newlen:	.byt 0
pool_slowpath:	.byt 0