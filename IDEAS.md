# Runix ideas

## Inter-library calls

Decisions:
- Libraries will be called "runes" because it's not boring
- We won't use `BRK` xx for inter-library calls, because the overhead is like 50 cycles (see experiments.s)
- Library calls will be simple `JSR` to $Cxx space. Rune00 is $C00-C0F (5 jmp vectors); Rune01 is $C10-$C1F, etc.
- Runes will be loaded on demand when their vector is first used (system initializes all vectors to a stub loader)
- Rune00 vectors are obviously for system essentials - read/write block, read file, etc.
- Relocator won't use a fixup table, but will iterate the code and fix in place.
    - therefore, all code needs to be disassemble-clean (no invalid ops, inline buffers, etc.)

## In-line strings

Nobody seems to have a really good use for `BRK` xx. Even I struggle to find a good use for it given the overhead of intercepting and parsing. So, let's use it for strings! They're not generally used in fast operations anyhow.

Print
```
  lda #1
  ldx #2
  PRINT "Foo %x"   ; prints "Foo $201"
  ; encoding: `00 C6 EF EF A0 A5 F8 00`
```

The string is allowed to contain a single printf-style code from this list:
- `%x` to print '$' and A/X in hex
- `%d` to print A/X in decimal
- `%c` to print A as a char
- `%s` to print string pointed to by A/X
   - Pascal-style length-prefixed if first byte < $80
   - Zero-terminted if first byte >= $80

Load
```
  LDSTR "Foobar"  ; points A/X to 6-byte len prefixed string "Foobar"
  ; encoding: `00 06 C6 EF EF E2 E1 F2`
```

## Filesystem

### Format

Let's keep it super simple.
- Block 0 starts with magic:
   `B1 D2 F5 EE E9 F8`   - which spells "1Runix" and also disassembles cleanly and executes harmlessly
- Block  $0000 continues with the loader
- Blocks $0001.0004 hold the root dir, about 100 entries if 20 bytes each
- Blocks $0005.FFFF hold data files and subdirs
- Directories are always 4 blks ($800) long, about 100 entries
- Directory block format:
  - root dir is blk 1, so that's how you can tell if you're at the root
  - starts with 2-byte next-free-blk (if root), or parent dir blk (if not root)
  - followed by the entries themselves
- Directory entry format:
  - 1-byte name length (0 if no more in this block)
  - file name in hi-bit ascii
  - 2-byte start block of file
  - 2-byte length of file - special $F800 if directory

### Algorithm for allocating a new file
1. Read root dir block, grab the free block number, bump it, write back
2. Iterate to find last block in cur dir with any entries
3. If entry would fit there, add it, write, done
4. Advance to next blk. If we would exceed 4 blks, abort.

### FS naming conventions
* In general we'll use unix-style lowercase filenames
* Runes are stored in a subdirectory off root called "runes"
* Runes are named e.g. "01-description" where 01 is the rune number in hex
* Rune 01 stubs are at $C10; Rune 02 stubs at $C20, etc.
* "00-system" is the system/startup rune. The boot loader looks for this and runs it.

### Implementing `pwd`
* Track the block num of the current subdir
* `pwd` will be an executable in bin/. It can use parent dir traversal and matching up the block numbers to figure out the path.

## Memory management

* We'll allocate on a byte granularity (not page)
* No freeing of individual memory blocks - must reset everything and reload (but could have limited support for using things that are already in the right place)
* Runes will load starting at $D00 and build upward.
    * This means rune 00 - the kernel - will always be at $D00.
* Apps and their buffers will start at $BFFF and build downward.
    * Later I might figure out how to start at $FFC0 and build downward, but mon support would have to be copied or bank-switched.