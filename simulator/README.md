# Runix 6502 Simulator Setup - Summary

## What Was Accomplished

Successfully set up a complete 6502 simulator environment for automated testing of Runix code without requiring a full Apple III emulator.

### 1. cc65 Submodule Setup
- Added cc65 as a git submodule in `simulator/cc65`
- Forked cc65 to https://github.com/martinhaye/cc65_runixmod
- Applied 3 custom commits with Runix-specific modifications
- `.gitmodules` now points to the fork

### 2. sim65 Enhancements

**Multi-segment Binary Support (Version 3 Format)**
- Extended sim65 to load code at multiple memory addresses
- Allows placing ROM routines at specific addresses ($C200, $F800, etc.)
- Format: header specifies segment count, then for each segment: address + length + data
- Backward compatible with version 2 single-segment format
- Location: `simulator/cc65/src/sim65/main.c`

**ProDOS Block Device Support**
- Added `-d <file>` / `--disk <file>` option to load .2mg disk images
- Virtual ROM at $C200-$C2FF with ProDOS signatures:
  - $C201 = $20 (ID byte 1)
  - $C203 = $00 (ID byte 2)
  - $C205 = $03 (ID byte 3)
  - $C2FF = $0A (entry point offset, points to $C20A)
- Device number: $20
- Location: `simulator/cc65/src/sim65/main.c` and `6502.c`

**Block I/O Handler**
- Hooks PC=$C20A to intercept block I/O calls
- Reads ProDOS parameters from $42-$47:
  - $42: command (1=read, 2=write)
  - $43: unit number (ignored)
  - $44-$45: buffer address (little-endian)
  - $46-$47: block number (little-endian)
- Uses file-based I/O (fseek/fread/fwrite) for performance
- Supports read and write of 512-byte blocks
- Crashes on errors (as requested)
- Location: `HandleBlockIO()` in `simulator/cc65/src/sim65/main.c`

### 3. Test Utilities Created

**Multi-segment test program**
- `simulator/build-multiseg.py` - Builds version 3 format binaries
- `simulator/test-multi.s` - Assembly source for multi-segment test
- `simulator/rom-c200.s` - ROM routine at $C200
- `simulator/rom-f800.s` - ROM routine at $F800

**Disk I/O test utilities**
- `simulator/create-test-disk.py` - Generates .2mg test images with known patterns
- `simulator/test-disk-io.py` - Builds test programs for block I/O verification
- `simulator/test.s` - Simple test program (version 2 format)

### 4. Build System
- Modified cc65 builds with `make -C simulator/cc65/src sim65`
- Compiled binary at `simulator/cc65/bin/sim65`
- `.gitignore` updated to exclude build artifacts (*.bin, *.o, *.2mg)

## How to Use

### Running a test program:
```bash
cd simulator
./cc65/bin/sim65 --trace --verbose test.bin
```

### Running with disk image:
```bash
./cc65/bin/sim65 -vv -d test-disk.2mg test-disk-io.bin
```

### Building multi-segment binaries:
```bash
python3 build-multiseg.py  # Creates test-multi.bin with 3 segments
```

### Creating test disk images:
```bash
python3 create-test-disk.py  # Creates test-disk.2mg (280 blocks)
```

## Architecture Details

### Version 3 Binary Format
```
Bytes 0-4:   "sim65" signature
Byte 5:      Version (3)
Byte 6:      CPU type (0=6502, 1=65C02, 2=6502X)
Byte 7:      Stack pointer page
Bytes 8-9:   Reset address (little-endian)
Bytes 10-11: Segment count (little-endian)

For each segment:
  Bytes 0-1: Load address (little-endian)
  Bytes 2-3: Length (little-endian)
  Bytes 4+:  Data
```

### .2mg Disk Format
```
Bytes 0-3:   "2IMG" signature
Bytes 4-63:  Header metadata
Bytes 64+:   ProDOS-ordered disk blocks (512 bytes each)
```

### ProDOS Block Parameters (Zero Page $42-$47)
```
$42:      Command (0=status, 1=read, 2=write)
$43:      Unit number
$44-$45:  Buffer address (little-endian)
$46-$47:  Block number (little-endian)
```

## Important Files

### Modified cc65 Files
- `simulator/cc65/src/sim65/main.c` - Core modifications
- `simulator/cc65/src/sim65/main.h` - New header for HandleBlockIO()
- `simulator/cc65/src/sim65/6502.c` - Added PC hook

### Test Utilities (Keep these)
- `simulator/build-multiseg.py`
- `simulator/create-test-disk.py`
- `simulator/test-disk-io.py`
- `simulator/test.s`
- `simulator/test-multi.s`
- `simulator/rom-c200.s`
- `simulator/rom-f800.s`
- `simulator/test.cfg`
- `simulator/raw.cfg`

### Documentation
- `CLAUDE.md` - Project overview (already existed)
- `IDEAS.md` - Design notes (already existed)

## Next Steps for Future Claude

### Immediate Tasks
1. **Test with actual Runix disk images**
   - Once `make` in the root directory works, test with `build/runix.2mg`
   - Verify boot sector loads correctly
   - Test kernel block loading

2. **Implement Runix-specific test programs**
   - Write 6502 assembly to test rune loading
   - Test filesystem operations (directory scanning, file loading)
   - Test block I/O from Runix code

3. **Add more ROM simulation if needed**
   - $F800 ROM routines (if Runix needs them)
   - Other peripheral simulation as required

### Future Enhancements
1. **Automated test suite**
   - Python harness to run multiple test programs
   - Compare expected vs actual memory contents
   - Parse sim65 trace output for verification

2. **Enhanced debugging**
   - Breakpoint support at specific addresses
   - Memory dump utilities
   - Trace filtering by address range

3. **Performance optimization**
   - Block caching if needed
   - Batch I/O operations

4. **Additional .2mg features**
   - Support for write-protected images
   - Multiple disk support (if needed)
   - DOS 3.3 order support (if needed)

### Known Limitations
- Only supports ProDOS-ordered .2mg images
- No status or format commands implemented (just read/write)
- Single disk image only
- No error codes returned (crashes on errors as requested)
- Unit number is ignored (always uses same disk)

### Testing Strategy
1. Start with simple programs that read/write single blocks
2. Progress to directory scanning
3. Test file loading across multiple blocks
4. Test edge cases (boundary blocks, invalid block numbers)
5. Eventually test full Runix boot sequence

### Git State
- Branch: `claude/setup-6502-simulator-01Dx26uABfShdzcDTE1HgbTh`
- Submodule points to: https://github.com/martinhaye/cc65_runixmod.git
- All changes committed and pushed
- Patches have been applied to the fork

## Questions for Next Session
- Does Runix need specific initialization at $F800 or other ROM addresses?
- What's the expected boot process? (block 0 → kernel → runes?)
- Should we implement additional paravirtualization features?
- Do we need to simulate any Apple III-specific hardware beyond block I/O?

## Build Verification
To verify the simulator is working correctly:
```bash
cd simulator
python3 create-test-disk.py
python3 test-disk-io.py
./cc65/bin/sim65 -vv -d test-disk.2mg test-disk-io.bin 2>&1 | grep "Block I/O"
```

Should see: `Block I/O: READ block 0 to $0300`

---
Created: 2025-11-19
Last updated: 2025-11-19
