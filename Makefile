# Runix Build System
# Assembles all modules and builds a .2mg disk image

# Tools
CA65 = ca65
LD65 = ld65
LDCFG = runix.cfg
LDFLAGS = -C $(LDCFG)
CA65FLAGS = -t none
PYTHON = python3
MKIMG = ./mkrunix.py

# Suppress ld65 alignment warnings (expected for raw binary output)
LINK = @$(LD65) $(LDFLAGS) -o $@ $< 2>&1 | grep -v "isn't aligned properly" || true

# Build directory
BUILD = build

# Source files
BOOT_SRC = src/boot/boot.s
KERNEL_SRC = src/kernel/kernel.s
RUNE_SRC = $(wildcard src/runes/*.s)
SHELL_SRC = src/shell/shell.s
BIN_SRC = $(wildcard src/bin/*.s)
DEMO_SRC = $(wildcard src/demos/*.s)

# Binary outputs (final targets)
BOOT_BIN = $(BUILD)/boot.bin
KERNEL_BIN = $(BUILD)/kernel.bin
RUNE_BINS = $(patsubst src/runes/%.s,$(BUILD)/runes/%.bin,$(RUNE_SRC))
SHELL_BIN = $(BUILD)/shell.bin
BIN_BINS = $(patsubst src/bin/%.s,$(BUILD)/bin/%.bin,$(BIN_SRC))
DEMO_BINS = $(patsubst src/demos/%.s,$(BUILD)/demos/%.bin,$(DEMO_SRC))

# Final disk image
IMAGE = $(BUILD)/runix.2mg

.PHONY: all clean dirs

all: $(IMAGE)

# Create build directories
dirs:
	@mkdir -p $(BUILD)/runes $(BUILD)/bin $(BUILD)/demos

# Assembly rules: .s -> .o
$(BUILD)/boot.o: $(BOOT_SRC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/kernel.o: $(KERNEL_SRC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/shell.o: $(SHELL_SRC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/runes/%.o: src/runes/%.s | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/bin/%.o: src/bin/%.s | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/demos/%.o: src/demos/%.s | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

# Linking rule: .o -> .bin (works for all paths)
%.bin: %.o $(LDCFG)
	$(LINK)

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
