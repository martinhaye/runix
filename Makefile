# Runix Build System
# Assembles all modules and builds a .2mg disk image

# Tools
CA65 = ca65
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

# Assemble boot block (at $0800)
$(BOOT_BIN): $(BOOT_SRC) | dirs
	$(CA65) -t none -o $@ $<

# Assemble kernel (at $0E00)
$(KERNEL_BIN): $(KERNEL_SRC) | dirs
	$(CA65) -t none -o $@ $<

# Assemble runes (relocatable, origin $2000)
$(BUILD)/runes/%.bin: src/runes/%.s | dirs
	$(CA65) -t none -o $@ $<

# Assemble shell (relocatable, origin $2000)
$(SHELL_BIN): $(SHELL_SRC) | dirs
	$(CA65) -t none -o $@ $<

# Assemble bin utilities (relocatable, origin $2000)
$(BUILD)/bin/%.bin: src/bin/%.s | dirs
	$(CA65) -t none -o $@ $<

# Assemble demos (relocatable, origin $2000)
$(BUILD)/demos/%.bin: src/demos/%.s | dirs
	$(CA65) -t none -o $@ $<

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
