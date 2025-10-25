# Runix Build System
# Assembles all modules and builds a .2mg disk image

# Tools
CA65 = ca65
LD65 = ld65
LDCFG = runix.cfg
PYTHON = python3
MKIMG = ./mkrunix.py

# Build directory
BUILD = build

# Source files
BOOT_SRC = src/boot/boot.s
KERNEL_SRC = src/kernel/kernel.s
RUNE_SRC = $(wildcard src/runes/*.s)
SHELL_SRC = src/shell/shell.s
BIN_SRC = $(wildcard src/bin/*.s)
DEMO_SRC = $(wildcard src/demos/*.s)

# Object file outputs
BOOT_OBJ = $(BUILD)/boot.o
KERNEL_OBJ = $(BUILD)/kernel.o
RUNE_OBJS = $(patsubst src/runes/%.s,$(BUILD)/runes/%.o,$(RUNE_SRC))
SHELL_OBJ = $(BUILD)/shell.o
BIN_OBJS = $(patsubst src/bin/%.s,$(BUILD)/bin/%.o,$(BIN_SRC))
DEMO_OBJS = $(patsubst src/demos/%.s,$(BUILD)/demos/%.o,$(DEMO_SRC))

# Binary outputs
BOOT_BIN = $(BUILD)/boot.bin
KERNEL_BIN = $(BUILD)/kernel.bin
RUNE_BINS = $(patsubst src/runes/%.s,$(BUILD)/runes/%.bin,$(RUNE_SRC))
SHELL_BIN = $(BUILD)/shell.bin
BIN_BINS = $(patsubst src/bin/%.s,$(BUILD)/bin/%.bin,$(BIN_SRC))
DEMO_BINS = $(patsubst src/demos/%.s,$(BUILD)/demos/%.bin,$(DEMO_SRC))

# Final disk image
IMAGE = $(BUILD)/runix.2mg

# Target CPU
CPU = 6502

.PHONY: all clean dirs

all: $(IMAGE)

# Create build directories
dirs:
	@mkdir -p $(BUILD)/runes $(BUILD)/bin $(BUILD)/demos

# Assemble boot block to object file
$(BOOT_OBJ): $(BOOT_SRC) | dirs
	$(CA65) -t none -o $@ $<

# Link boot block to binary
$(BOOT_BIN): $(BOOT_OBJ) $(LDCFG)
	@$(LD65) -C $(LDCFG) -o $@ $(BOOT_OBJ) 2>&1 || true

# Assemble kernel to object file
$(KERNEL_OBJ): $(KERNEL_SRC) | dirs
	$(CA65) -t none -o $@ $<

# Link kernel to binary
$(KERNEL_BIN): $(KERNEL_OBJ) $(LDCFG)
	@$(LD65) -C $(LDCFG) -o $@ $(KERNEL_OBJ) 2>&1 || true

# Assemble runes to object files
$(BUILD)/runes/%.o: src/runes/%.s | dirs
	$(CA65) -t none -o $@ $<

# Link runes to binaries
$(BUILD)/runes/%.bin: $(BUILD)/runes/%.o $(LDCFG)
	@$(LD65) -C $(LDCFG) -o $@ $< 2>&1 || true

# Assemble shell to object file
$(SHELL_OBJ): $(SHELL_SRC) | dirs
	$(CA65) -t none -o $@ $<

# Link shell to binary
$(SHELL_BIN): $(SHELL_OBJ) $(LDCFG)
	@$(LD65) -C $(LDCFG) -o $@ $(SHELL_OBJ) 2>&1 || true

# Assemble bin utilities to object files
$(BUILD)/bin/%.o: src/bin/%.s | dirs
	$(CA65) -t none -o $@ $<

# Link bin utilities to binaries
$(BUILD)/bin/%.bin: $(BUILD)/bin/%.o $(LDCFG)
	@$(LD65) -C $(LDCFG) -o $@ $< 2>&1 || true

# Assemble demos to object files
$(BUILD)/demos/%.o: src/demos/%.s | dirs
	$(CA65) -t none -o $@ $<

# Link demos to binaries
$(BUILD)/demos/%.bin: $(BUILD)/demos/%.o $(LDCFG)
	@$(LD65) -C $(LDCFG) -o $@ $< 2>&1 || true

# Build the disk image
$(IMAGE): $(BOOT_BIN) $(KERNEL_BIN) $(RUNE_BINS) $(SHELL_BIN) $(BIN_BINS) $(DEMO_BINS)
	$(PYTHON) $(MKIMG) $(BUILD) $(IMAGE)

clean:
	rm -rf $(BUILD)

# Help target
help:
	@echo "Runix Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all (default) - Build all modules and create disk image"
	@echo "  clean         - Remove all build artifacts"
	@echo "  help          - Show this help message"
