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

Nobody seems to have a really good use for `BRK` xx. Even I struggle to find a good use for it given the overhead of intercepting and parsing. So, let's use it for strings!

Encoding:
- `00 C1 C2 C3 00` - Print a 3-char string "ABC" (hi-bit ascii, zero-terminated)
- `00 03 C1 C2 C3` - Push pointer to pascal-style length prefixed string "ABC" (up to 127 chars)

When printed (first form), the string can contain a single printf-style code from this list:
- `%x` to print '$' and A/X in hex
- `%d` to print A/X in decimal
- `%c` to print A as a char
- `%s` to print string pointed to by A/X
   - Pascal-style length-prefixed if first byte < $80
   - Zero-terminted if first byte >= $80

## Filesystem

Let's keep it super simple.
- Block 0 starts with magic:
   `B1 D2 F5 EE E9 F8`   - which spells "1Runix" and also disassembles cleanly and executes harmlessly
- Block $0000 continues with the loader
- Block $0001 holds the root directory's first block
- Blocks $0002-$FFFF hold data files (and additional dir blocks as needed)
- First directory block:
  - 2-byte first free block #
  - then regular directory blk below
- Directory block format:
  - 2-byte number of next dir block (zero for none)
  - followed by the entries themselves
- Directory entry format:
  - 1-byte name length (0 if no more in this block)
        - future idea: hi-bit set if subdirectory
  - file name in hi-bit ascii
  - 2-byte start block
  - 1-byte count of blocks

Algorithm for allocating a new file:
1. Read root dir block, grab the free block number, bump it, write back
2. Iterate to find last dir block
3. Check for space in the dir block. If none, allocate a new dir block (going back to the root to inc free blk num)
4. Add the entry and write the dir block

Naming conventions
* Runes are named e.g. "Rune01-description" where 01 is the rune number in hex
* Rune 01 stubs are at $C10; Rune 02 stubs at $C20, etc.
* "Rune00-system" is the system init. The boot loader looks for this and runs it.

Future
- subdirectories might be useful, but would have to track CWD
