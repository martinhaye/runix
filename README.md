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

Build, emulate, and test are all driven by Rotoskop via `rotoskop.yaml`.

### Prerequisites

- Rotoskop (`rotoskop` on `PATH`)
- Python 3 (used by `deploy.sh` / `mdns_chk.py` and by `lsrunix.py`)

### Build Outputs

- `rotoskop build` runs the steps in `rotoskop.yaml` and writes everything under `build/`
- Font data is generated from `src/runes/base_font.txt` to `build/generated/base_font.s`
- Sources are assembled to raw binaries (`boot.bin`, `kernel.bin`, `shell.bin`, plus `runes/`, `bin/`, `demos/`, `rtest/`)
- `tests/bootstub.s` is assembled to `build/bootstub.bin` so the emulator can load block 0 the same way every run
- Those binaries are packed into `build/runix.2mg`. The image layout mirrors runtime:
  - root contains `runix` (the kernel)
  - subdirectories contain `runes`, `bin` (including `shell`), `demos`, and `rtest`

### Common Commands

- `rotoskop build`: build `build/runix.2mg`
- `rotoskop test`: rebuild if dirty, then run the integration tests
- `rotoskop test halt testbcd1`: run named cases (stems or globs such as `testbcd*`)
- `rotoskop test -v`: print instruction counts
- `rotoskop run`: boot the image in the emulator (`run:` in `rotoskop.yaml`)
- `rotoskop run --profile halt`: overlay a named profile (keyboard input, instruction cap)
- `./deploy.sh`: rsync the image to `diskserver.local` if that host is reachable
- `rm -rf build`: remove build artifacts
- `python3 lsrunix.py build/runix.2mg`: print the image directory tree

### Test Infrastructure

- Shell-level cases live in `tests/*.test`
- Rune/program cases live as `; @test` comments at the top of `src/rtest/*.s`
- `rotoskop.yaml` `tests.files` lists both globs; each case boots `build/runix.2mg` with `build/bootstub.bin` loaded at `$1000`
- Directives such as `@test keys`, `@test expect`, `@test stop success`, and `@test max_instructions` drive keyboard input and screen assertions
- For lower-level feature work:
  1. add a small assembly program under `src/rtest/` (it is packed into `/rtest` automatically)
  2. put `; @test` directives on that file, or add a `tests/*.test` that runs it from the shell

### Image Builder Notes

The `pack_image` step in `rotoskop.yaml` creates the `.2mg` image, writes block 0, lays out the root directory and subdirectories, and copies in the built binaries for `runix`, `runes`, `bin`, `demos`, and `rtest`.

## Assembly Language Notes

### Rotoskop assembler

- `rotoskop assemble` (and the `assemble:` steps in `rotoskop.yaml`) produce raw 6502 binaries
- Include search paths come from `include_dirs` in `rotoskop.yaml` (`src/include`)
- Use `rotoskop assemble source.s -o out.bin --list out.lst` when you want a listing file

### 6502 Conventions

- Little-endian architecture
- A/X/Y registers
- Zero page addressing is fast
- Stack at `$0100-$01FF`

## Development Workflow

1. Edit sources in `src/`
2. If the change needs focused runtime coverage, add or update an `src/rtest/*.s` helper and `; @test` directives (or a `tests/*.test`)
3. Run `rotoskop test` for the normal loop, or `rotoskop test <name>` when iterating on one area
4. Use `rotoskop run` interactively, or `./deploy.sh` when you want the image on the disk server
