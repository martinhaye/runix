# Runix Project - Claude Context

## Project Overview

**Runix** is a bare-metal operating system for the Apple III computer, written entirely in 6502 assembly language. The name "Runix" plays on Unix conventions while introducing the concept of "runes" - dynamically loadable system libraries.

## Development Environment Setup

### Quick Start (Ubuntu/Debian Linux)

To set up your development environment:

```bash
# Install cc65 toolchain (ca65 assembler and ld65 linker)
apt-get install -y cc65

# Verify installation
ca65 --version
ld65 --version

# Build and test
make test
```

### What You Get

After running `make test`, you should see:
- All source files assembled successfully
- Disk image created at `build/runix.2mg`
- Boot test running in pim65 simulator
- Console output showing "Welcome to Runix 0.1" with prompt

The instruction limit message at the end is expected - it's just preventing infinite loops during testing.

### Prerequisites

- **cc65 package** (version 2.18+): Provides ca65 assembler and ld65 linker
- **Python 3**: Already included in most Linux distributions
- **pim65 simulator**: Included in this repository as a submodule

### Common Issues

- If `apt-get update` fails with repository errors, you can skip the update and install cc65 directly with `apt-get install -y cc65`
- The build creates a `build/` directory automatically - no need to create it manually

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

Instead of using `BRK` for interrupts, Runix uses it for inline strings:

**PRINT macro** - prints formatted strings:

```asm
lda #1
ldx #2
PRINT "Foo %x"    ; prints "Foo $201"
; Encoding: 00 46 6F 6F 20 25 78 00
```

Format codes:

- `%x`: print '$' + A/X in hex
- `%d`: print A/X in decimal
- `%c`: print A as character
- `%s`: print string at A/X (length-prefixed if <$80, zero-terminated if ≥$80)

**LDSTR macro** - loads string pointer:

```asm
LDSTR "Foobar"    ; points A/X to length-prefixed string
; Encoding: 00 06 46 6F 6F 62 61 72
```

## Build System

### Tools

- **ca65**: Assembler from cc65 suite
- **Python 3**: For building disk images
- Target: 6502 CPU

### Directory Structure

```
/workspace/
├── src/
│   ├── boot/         # Bootloader (block 0, loads at $0800)
│   ├── kernel/       # Kernel (loads at $0E00)
│   ├── runes/        # System runes (relocatable, origin $2000)
│   ├── shell/        # Shell (relocatable, origin $2000)
│   ├── bin/          # Utility programs (relocatable, origin $2000)
│   └── demos/        # Demo programs (relocatable, origin $2000)
├── build/            # Build output directory
│   ├── *.bin         # Assembled binaries
│   └── runix.2mg     # Final disk image
├── Makefile          # Top-level build system
├── mkrunix.py        # Python script to create .2mg filesystem image
└── IDEAS.md          # Design documentation
```

### Makefile Targets

- `make` or `make all`: Build everything and create disk image
- `make clean`: Remove all build artifacts
- `make help`: Show help

### Build Process

1. **Assemble modules**: Each `.s` file assembled to `.bin` with ca65
   - Boot: assembles at `$0800`
   - Kernel: assembles at `$0E00`
   - Everything else: assembles at `$2000` (will be relocated at runtime)
2. **Create filesystem**: `mkrunix.py` builds proper Runix filesystem
3. **Generate .2mg**: Creates 32MB ProDOS-ordered disk image with 2mg header

### mkrunix.py Details

Creates a 32MB (65536 blocks) disk image with:

- Proper 2mg header (creator code: `RNIX`)
- Block 0: Boot block with Runix magic bytes
- Blocks 1-4: Root directory with all files cataloged
- Automatic subdirectory creation (e.g., `/runes/`)
- Proper directory entry formatting (ASCII names)
- File layout: kernel → runes dir → runes → shell → bins → demos

## Current State

### Implemented

- Complete build system (Makefile + mkrunix.py)
- Source directory structure
- Stub assembly files for all modules (just `rts` for now)
- Proper .2mg disk image generation with Runix filesystem
- Root directory and runes subdirectory structure

### To Do

- Implement bootloader (block 0 loader)
- Implement kernel initialization
- Implement rune loader and relocation
- Implement system runes (Rune 00: block I/O, file ops)
- Implement shell
- Implement string macros (PRINT, LDSTR)
- Implement utilities (pwd, ls, etc.)

## Assembly Language Notes

### ca65 Assembler

- Part of cc65 suite
- Use `-t none` for raw binary output (no linking)
- `.org` directive sets origin address
- No linker needed - each binary is independent

### 6502 Conventions

- Little-endian architecture
- A/X/Y registers
- Zero page addressing is fast
- Stack at `$0100-$01FF`

## Related Files

- [IDEAS.md](IDEAS.md) - Detailed design notes and decisions
- [Makefile](Makefile) - Build system
- [mkrunix.py](mkrunix.py) - Disk image builder
- [experiments.s](experiments.s) - Performance experiments (BRK overhead, etc.)
- [dirscan.s](dirscan.s) - Directory scanning code (work in progress)

## Development Workflow

1. Edit source files in `src/*/`
2. Run `make` to build
3. Test resulting `build/runix.2mg` in Apple III emulator
4. Iterate

## Apple III Hardware Notes

- 6502A CPU @ 2 MHz
- Bank-switched memory (4 banks of 64KB)
- Built-in disk controller
- ProDOS-based disk format (which we're replacing with Runix filesystem)
