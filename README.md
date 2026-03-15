# Runix Project - Context

## Project Overview

**Runix** is a bare-metal operating system for the Apple III computer, written entirely in 6502 assembly language. The name "Runix" plays on Unix conventions while introducing the concept of "runes" - dynamically loadable system libraries.

## Key Architecture Concepts

### Runes (Dynamic Libraries)

- Runes are Runix's term for system libraries/modules
- Called via `JSR` to memory-mapped jump vectors at `$C00-$DFF`
- 16 runes total, 32 bytes each (10 API calls per rune)
  - Rune 00: `$C00-$C1F` (system essentials: block I/O, file ops)
  - Rune 01: `$C20-$C3F`
  - Rune 02: `$C40-$C5F`, etc.
- Loaded on-demand when first called (lazy loading)
- Initial vectors point to stub loader that loads the real rune
- Runes use in-place relocation (no fixup tables)
- All code must be disassemble-clean (no inline data buffers)

### Memory Layout

**System Bank:**

- `$0C00-$0DFF`: Jump vector table (32 bytes × 16 runes)
- `$0E00-$1FFF`: Rune space
- `$A000-$BFFF`: Rune space
- `$C000-$CFFF`: hardware I/O and slot ROMs (reserved)
- `$D000-$EFFF`: Rune space
- `$F000+`: ROM (reserved)

**User Banks:**

- Bank 1: Graphics or free for app use
- Bank 2: Application code (loads at `$6000`)
- Bank 3: Shell (loads at `$6000`)

### Filesystem Format

**Custom block-based filesystem (512-byte blocks):**

**Block Layout:**

- Block 0: Boot loader
  - Starts with magic: `01 52 75 6E 69 78` (spells "\1Runix")
  - Disassembles cleanly and executes harmlessly
- Blocks 1-4: Root directory (4 blocks = 2KB, ~100 entries)
- Block 5+: Files and subdirectories

**Directory Structure:**

- Directories are always 4 blocks (2KB)
- First 2 bytes:
  - Root dir: next free block pointer
  - Subdirs: parent directory block number
- Followed by directory entries

**Directory Entry Format (variable length):**

1. 1 byte: name length (0 = end of entries)
2. N bytes: filename in lo-bit ASCII
3. 2 bytes: start block (little-endian)
4. 1 byte: length in pages (256-byte pages), or `$F8` for directory

**Important:** Directory entries may not span block boundaries. If an entry won't fit in the remaining space of a block (or would extend to the very last byte), the rest of the block is filled with zeros and the entry starts on the next block. The last byte of each directory block must always be zero.

**Naming Conventions:**

- Unix-style lowercase filenames
- Runes stored in `/runes/` subdirectory
- Runes named as `XX-description` (e.g., `00-system`, `01-example`)
  - the number is the only significant part to the system when it's matching rune filenames
- First file in root must be `runix` for bootability

### Boot Process

1. Apple III loads block 0 from floppy to `$A000`, jumps to it (external bootloader)
2. Scan slots for mass storage card (highest to lowest)
3. Load block 0 from disk to `$0800`, jump to it
4. Block 0 loader: read root dir (block 1), verify `runix` exists
5. Load kernel blocks to `$0E00`
6. Jump to kernel

### BRK-based String Macros

Instead of using `BRK` for interrupts, Runix uses it for inline strings. The encoding is a 2-byte header (BRK + length byte) then the string bytes.

**print macro** - prints formatted strings:

```asm
lda #1
ldx #2
print "Foo %x"    ; prints "Foo $0201"
; Encoding: 00 86 46 6F 6F 20 25 78
; The 86 above is the length (6) plus the high-bit to say "print" instead of "ldstr"
```

Format codes:

- `%x`: print '$' + A/X in hex (4 digits)
- `%d`: print A/X in decimal
- `%c`: print A as character
- `%s`: print length-prefixed string pointed to by A/X

Only ONE format code is allowed per print

**ldstr macro** - loads string pointer:

```asm
ldstr "Foobar"    ; points A/X to an inline length-prefixed string
; Encoding: 00 06 46 6F 6F 62 61 72
; The 6 above is the string length
```

## Build and Test

### Prerequisites

- cc65 tools: `ca65` and `ld65`
- Python 3
- `pytest` for the integration test suite
- Install Python dependencies with `pip install -r requirements.txt -r tests/requirements.txt`

### Build Outputs

- `make` builds everything into `build/`
- Each assembly source is assembled to `.o`, linked to a raw `.bin`, and also gets a `.lst` listing
- `mkrunix.py` then packs those binaries into `build/runix.2mg`
- The image layout mirrors how Runix is organized at runtime:
  - root contains `runix`
  - subdirectories contain `runes`, `bin` (including `shell`), `demos`, and `rtest`
- `src/runes/base_font.s` is generated from `src/runes/base_font.txt` during the build

### Common Commands

- `make`: build `build/runix.2mg`
- `make test`: build the image, then run the Runix integration tests
- `make -C tests test-verbose`: run tests with uncaptured output
- `make -C tests test-<name>`: run one test file such as `make -C tests test-boot`
- `make deploy`: optionally rsync the image to `diskserver.local` if it is reachable
- `make clean`: remove build artifacts

### Test Infrastructure

- Runix feature tests live in `tests/` and are written with `pytest`
- The test harness boots `build/runix.2mg` inside the in-process `pim65` simulator
- `tests/mkbootstub.py` generates `tests/bootstub.bin`, which the fixtures use to load block 0 and enter Runix the same way every test does
- Most tests drive the shell by injecting command lines, then assert against screen output and simulator stderr
- For lower-level feature work, the usual pattern is:
  1. add a small assembly test program under `src/rtest/`
  2. let `make` include it in the disk image under `/rtest`
  3. add a `tests/test_*.py` case that boots Runix, runs that program from the shell, and checks the output
- If you are changing the simulator itself, its separate tests live in `pim65/tests/`

### Image Builder Notes

`mkrunix.py` creates the `.2mg` image, writes block 0, lays out the root directory and subdirectories, and then copies in the built binaries for `runix`, `runes`, `bin`, `demos`, and `rtest`.

## Assembly Language Notes

### cc65 Toolchain

- `ca65` assembles sources to object files
- `ld65` links them into raw binaries using `runix.cfg`
- `-t none` is used for the 6502 bare-metal target
- The linker config provides the final memory map and vector placement

### 6502 Conventions

- Little-endian architecture
- A/X/Y registers
- Zero page addressing is fast
- Stack at `$0100-$01FF`

## Development Workflow

1. Edit sources in `src/`
2. If the change needs focused runtime coverage, add or update an `src/rtest/*.s` helper and a matching `tests/test_*.py`
3. Run `make test` for the normal loop, or `make -C tests test-<name>` when iterating on one area
4. Use `build/runix.2mg` in your emulator or `make deploy` when you want manual interactive testing
