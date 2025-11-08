; Runix shell
; Loads somewhere $2000-$AFFF; always org at $1000 so relocator knows what to do

        .org $1000

:	inc $7F0
	jmp :-
