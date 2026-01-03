resetrunes	= kernel_vecs+(0*3)
kfatal		= kernel_vecs+(1*3)
rdblks		= kernel_vecs+(2*3)
getdirent	= kernel_vecs+(3*3)	; clc=first, Y=dir; sec=next; ret: A/X - ent, Y - name len
dirscan		= kernel_vecs+(4*3)	; A/X - name to scan for, Y - dir to scan
  DIRSCAN_ROOT	= 0
  DIRSCAN_CWD	= 2
  DIRSCAN_RUNES	= 4
  DIRSCAN_BIN	= 6
progalloc	= kernel_vecs+(5*3)
progrun		= kernel_vecs+(6*3)
getsetcwd	= kernel_vecs+(7*3)
