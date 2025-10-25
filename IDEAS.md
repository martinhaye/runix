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
- Going to store strings and chars in lo-bit ASCII for easier generation from modern tools (e.g. ca65)

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
  `01 52 75 6E 69 78` - which spells "\1Runix" and also disassembles cleanly,
  executes harmlessly, and is even Apple II compatible.
- Block $0000 continues with the loader
- Blocks $0001.0004 hold the root dir, about 100 entries if 20 bytes each. First file
  must be "runix" for it to be bootable/usable.
- Blocks $0005.FFFF hold data files and subdirs. First subdir is usually "runes".
- Directories are always 4 blks ($800) long, about 100 entries
- Directory block format:
  - root dir is blk 1, so that's how you can tell if you're at the root
  - starts with 2-byte next-free-blk (if root), or parent dir blk (if not root)
  - followed by the entries themselves
- Directory entry format:
  - 1-byte name length (0 if no more in this block)
  - file name in lo-bit ascii
  - 2-byte start block of file
  - 1-byte length of file in pages - special $F8 if directory

### Boot process

1. Floppy booted by Apple /// - loads first blk to $A000 and jumps to it
2. Scan slots for mass storage card, highest slot to lowest. Record slot found.
3. Load block 0 at $800 and jump to it.
4. Blk 0 code: load block 1, and verify first file is "runix"
5. Read kernel blocks starting at $E00
6. Jump to kernel

### Algorithm for allocating a new file

1. Read root dir block, grab the free block number, bump it, write back
2. Iterate to find last block in cur dir with any entries
3. If entry would fit there, add it, write, done
4. Advance to next blk. If we would exceed 4 blks, abort.

### FS naming conventions

- In general we'll use unix-style lowercase filenames
- Runes are stored in a subdirectory off root called "runes"
- Runes are named e.g. "01-description" where 01 is the rune number in hex
- Rune 01 stubs are at $C10; Rune 02 stubs at $C20, etc.
- "00-system" is the system/startup rune. The boot loader looks for this and runs it.

### Implementing `pwd`

- Track the block num of the current subdir
- `pwd` will be an executable in bin/. It can use parent dir traversal and matching up the block numbers to figure out the path.

## Memory management

- Rune jumps are at $C00.DFF, 32 bytes per rune x 16 runes
  - This allows up to 10 APIs per rune
  - e.g. Rune00 - $C00, Rune01 - $C20, Rune02 - $C40, etc.
- Runes will be allocated in the system bank in the following areas:
  - 0E00.1FFF
  - A000.BFFF
  - D000.EFFF
    (saving Cxxx and Fxxx for I/O and ROM)
- We'll allocate memory on a page granularity (not block, not byte)
  - but be sure the next page is free if reading an odd # of pages
- No freeing of individual memory allocations - must reset everything and reload
  - (but maybe in future support reusing things that are already in the right place)
- Might as well put Rune 00 at $E00; no compelling advantage elsewhere.
- Runes (except 00) load at variable address, so will be subject to initial relocation
- Regular binaries will load at $6000, no relocation needed
  - bank 1 - (graphics, or free for app use)
  - bank 2 - app
  - bank 3 - shell
