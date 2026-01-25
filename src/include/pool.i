; Compactable pool of up to 126 variable-sized objects, 1-254 bytes. Each has an
; even-numbered ID from 04..FE. Object data always starts with the size.
;
; Objects 00 and 02 are reserved (01, 03, and all other odd-numbered IDs: invalid).

pool_iptr = _pool_zp	; low byte always zero
pool_dptr = _pool_zp+2	; low byte always zero

;*****************************************************************************
; Initialize a pool, returning the new pool page in A
.macro pool_init
	jsr v_pool_init
.endmacro

;*****************************************************************************
; Set which pool to work on. A=index page
.macro pool_select pool, size
	lda pool
	sta pool_iptr+1
.endmacro

;*****************************************************************************
; Allocate an object of size A. Returns obj ID in Y.
; Aborts if size too large.
.macro pool_alloc size
	lda size
	jsr v_pool_alloc
.endmacro

;*****************************************************************************
; Free an object's space for possible future reuse.
.macro pool_free objnum
	lda objnum
	jsr v_pool_free
.endmacro

;*****************************************************************************
; Get a pointer to the data for an obj -> AX
.macro pool_getptr objnum
	ldy objnum
	iny
	lda (pool_iptr),y
	tax
	dey
	lda (pool_iptr),y
.endmacro

;*****************************************************************************
; pool_resize: Resize an object in the pool
.macro pool_resize objnum, newsize
	ldy objnum
	lda newsize
	jsr v_pool_resize
.endmacro

;*****************************************************************************
; Calculate how much space is used, and the total number of pages in the pool
; Out: AX - sum of object lengths
;      Y - total number of allocated pages
.macro pool_total
	jsr v_pool_total
.endmacro

;*****************************************************************************
; Consolidate space used by current objects, consolidating unused space in the
; pool and releasing any no-longer-needed pool pages. 
;
; During the consolidation process, the callback is periodically called; if it
; sets C=1, the consolidation is safely tied off and can be restarted later.
.macro pool_collect callback
	ldax callback
	jsr v_pool_collect
.endmacro
