; Compact pool of up to 126 variable-sized objects, 1-254 bytes. Each has an
; even-numbered ID from 02..FE. Object data always starts with the length.
;
; Valid ids:   02, 04, 06...
; Invalid ids: 00, 01, 03, 05...

pool_iptr = _pool_zp	; low byte always zero
pool_dptr = _pool_zp+2	; low byte always zero

;*****************************************************************************
; Rune vectors
v_pool_init	= pool_vecs+(0*3)
v_pool_alloc	= pool_vecs+(1*3)
v_pool_free	= pool_vecs+(2*3)
v_pool_setlen	= pool_vecs+(3*3)

;*****************************************************************************
; Initialize a pool. Returns the new pool index page in A.
.macro pool_init
	jsr v_pool_init
.endmacro

;*****************************************************************************
; Set which pool to work on.
.macro pool_select pool
	ld_a pool
	sta pool_iptr+1
.endmacro

;*****************************************************************************
; Allocate an object of length A. Returns obj ID in Y, ptr in AX.
; Aborts if len too large.
.macro pool_alloc len
	ld_a len
	jsr v_pool_alloc
.endmacro

;*****************************************************************************
; Free an object's space for future reuse.
.macro pool_free objnum
	ld_y objnum
	jsr v_pool_free
.endmacro

;*****************************************************************************
; Get a pointer to the data for an obj in current pool -> AX
.macro pool_getptr objnum
	ld_y objnum
	iny
	lda (pool_iptr),y
	tax
	dey
	lda (pool_iptr),y
.endmacro

;*****************************************************************************
; pool_setlen: Set length of obj in cur pool in preparation for overwriting.
;   	** May scramble existing obj data - to preserve, use pool_resize **.
;	Return: AX = new obj ptr
.macro pool_setlen objnum, newlen
	ld_y objnum
	ld_x newlen
	jsr v_pool_setlen
.endmacro

;*****************************************************************************
; pool_resize: Resize an object in the pool, retaining current content 
;              (as much as will fit in the new len)
;	Return: AX = new obj ptr
.macro pool_resize objnum, newlen
	ld_a newlen
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
