; Compact pool of up to 127 variable-sized objects, 1-254 bytes. Each has an
; ID from 01..7F. Object data always starts with the length.
;
; Valid ids:   01, 02, 03, ... 7F
; Invalid ids: 00, 80, 81, ... FF

pool_ilptr	= _pool_zp	; low byte always zero
pool_ihptr	= _pool_zp+2	; low byte always $80
pool_dptr	= _pool_zp+4	; low byte always zero

;*****************************************************************************
; Rune vectors
v_pool_init	= pool_vecs+(0*3)
v_pool_alloc	= pool_vecs+(1*3)
v_pool_free	= pool_vecs+(2*3)
v_pool_setlen	= pool_vecs+(3*3)
v_pool_qreduce	= pool_vecs+(4*3)
v_pool_resize	= pool_vecs+(5*3)
v_pool_total	= pool_vecs+(6*3)

;*****************************************************************************
; Initialize a pool. Returns the new pool index page in A.
.macro pool_init
	jsr v_pool_init
.endmacro

;*****************************************************************************
; Set which pool to work on.
.macro pool_select pool
	ld_a pool
	sta pool_ilptr+1
	sta pool_ihptr+1
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
	lda (pool_ihptr),y
	tax
	lda (pool_ilptr),y
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
	ld_y objnum
	ld_x newlen
	jsr v_pool_resize
.endmacro

;*****************************************************************************
; pool_qreduce: Reduce the size of the last allocated object (only safe if
;		no other pool operations have been performed since last alloc)
.macro pool_qreduce newlen
	ld_x newlen
	jsr v_pool_qreduce
.endmacro

;*****************************************************************************
; pool_total: Add up how much space is used, and the total number of data pages
;             and whether any slow path was taken since last total
;      AX - sum of object data sizes (including their length bytes)
;      Y - total number of allocated pages
;      C - set if any slow path was taken since last total
.macro pool_total
	jsr v_pool_total
.endmacro
