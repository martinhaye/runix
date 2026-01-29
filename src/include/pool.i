; Compactable pool of up to 126 variable-sized objects, 1-254 bytes. Each has an
; even-numbered ID from 04..FE. Object data always starts with the size.
;
; Objects 00 and 02 are reserved (01, 03, and all other odd-numbered IDs: invalid).

pool_iptr = _pool_zp	; low byte always zero
pool_dptr = _pool_zp+2	; low byte always zero

;*****************************************************************************
; Rune vectors
v_pool_init	= pool_vecs+(0*3)
v_pool_alloc	= pool_vecs+(1*3)
v_pool_free	= pool_vecs+(2*3)
v_pool_setsize	= pool_vecs+(3*3)

;*****************************************************************************
; Initialize a pool. Returns the new pool index page in A.
.macro pool_init
	jsr v_pool_init
.endmacro

;*****************************************************************************
; Set which pool to work on.
.macro pool_select pool, size
	ld_a pool
	sta pool_iptr+1
.endmacro

;*****************************************************************************
; Allocate an object of size A. Returns obj ID in Y.
; Aborts if size too large.
.macro pool_alloc size
	ld_a size
	jsr v_pool_alloc
.endmacro

;*****************************************************************************
; Free an object's space for possible future reuse.
.macro pool_free objnum
	ld_y objnum
	jsr v_pool_free
.endmacro

;*****************************************************************************
; Get a pointer to the data for an obj -> AX
.macro pool_getptr objnum
	ld_y objnum
	iny
	lda (pool_iptr),y
	tax
	dey
	lda (pool_iptr),y
.endmacro

;*****************************************************************************
; pool_setsize: Set size of obj in pool in preparation for writing it.
;               Always scrambles existing obj contents.
;		No return value.
.macro pool_setsize objnum, newsize
	ld_y objnum
	ld_x newsize
	jsr v_pool_setsize
.endmacro

;*****************************************************************************
; pool_resize: Resize an object in the pool, retaining current content 
;              (as much as will fit in the new size)
.macro pool_resize objnum, newsize
	ld_a newsize
	ld_y objnum
	jsr v_pool_resize
.endmacro

;*****************************************************************************
; Add up how much space is used, and the total number of data pages
; Out: AX - sum of object lengths
;      Y - total number of allocated pages
.macro pool_total
	jsr v_pool_total
.endmacro
