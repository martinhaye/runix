# Runix Build System
# Assembles all modules and builds a .2mg disk image

# Tools
CA65 = ca65
LD65 = ld65
LDCFG = runix.cfg
LDFLAGS = -C $(LDCFG)
CA65FLAGS = -t none -I src/include
PYTHON = python3
MKIMG = ./mkrunix.py
MDNS_CHECK = ./mdns_chk.py
RSYNC = rsync -a --inplace --progress --compress

# Suppress ld65 alignment warnings (expected for raw binary output)
LINK = @$(LD65) $(LDFLAGS) -o $@ $< 2>&1 | grep -v "isn't aligned properly" || true

# Build directory
BUILD = build

# Deployment settings
DISKSERVER = diskserver.local
DEPLOY_TARGET = $(DISKSERVER):/srv/apple2_share/Runix.2mg

# Source files
BOOT_SRC = src/boot/boot.s
KERNEL_SRC = src/kernel/kernel.s
RUNE_SRC = $(wildcard src/runes/*.s)
SHELL_SRC = src/shell/shell.s
BIN_SRC = $(wildcard src/bin/*.s)
DEMO_SRC = $(wildcard src/demos/*.s)
RTEST_SRC = $(wildcard src/rtest/*.s)

# Font generation
FONT_TXT = src/runes/base_font.txt
FONT_ASM = src/runes/base_font.s
FONT_SCRIPT = src/runes/font_to_asm.py

# Binary outputs (final targets)
BOOT_BIN = $(BUILD)/boot.bin
KERNEL_BIN = $(BUILD)/kernel.bin
RUNE_BINS = $(patsubst src/runes/%.s,$(BUILD)/runes/%.bin,$(RUNE_SRC))
SHELL_BIN = $(BUILD)/shell.bin
BIN_BINS = $(patsubst src/bin/%.s,$(BUILD)/bin/%.bin,$(BIN_SRC))
DEMO_BINS = $(patsubst src/demos/%.s,$(BUILD)/demos/%.bin,$(DEMO_SRC))
RTEST_BINS = $(patsubst src/rtest/%.s,$(BUILD)/rtest/%.bin,$(RTEST_SRC))

# Final disk image
IMAGE = $(BUILD)/runix.2mg

.PHONY: all clean dirs deploy test

all: $(IMAGE)

# Create build directories
dirs:
	@mkdir -p $(BUILD)/runes $(BUILD)/bin $(BUILD)/demos $(BUILD)/rtest

# Font generation rule
$(FONT_ASM): $(FONT_TXT) $(FONT_SCRIPT)
	$(PYTHON) $(FONT_SCRIPT)

# Common dependencies
BASE_INC = src/include/base.i

# Assembly rules: .s -> .o
$(BUILD)/boot.o: $(BOOT_SRC) $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/kernel.o: $(KERNEL_SRC) $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/shell.o: $(SHELL_SRC) $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

# Rune 02 depends on generated font
$(BUILD)/runes/02-font.o: src/runes/02-font.s $(FONT_ASM) $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/runes/%.o: src/runes/%.s $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/bin/%.o: src/bin/%.s $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/demos/%.o: src/demos/%.s $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

$(BUILD)/rtest/%.o: src/rtest/%.s $(BASE_INC) | dirs
	$(CA65) $(CA65FLAGS) -o $@ $<

# Linking rule: .o -> .bin (works for all paths)
%.bin: %.o $(LDCFG)
	$(LINK)

# Build the disk image
$(IMAGE): $(BOOT_BIN) $(KERNEL_BIN) $(RUNE_BINS) $(SHELL_BIN) $(BIN_BINS) $(DEMO_BINS) $(RTEST_BINS)
	$(PYTHON) $(MKIMG) $(BUILD) $(IMAGE)

# Deploy to disk server (can be run manually)
deploy: $(IMAGE)
	@if $(PYTHON) $(MDNS_CHECK) $(DISKSERVER) >/dev/null 2>&1; then \
		echo "Deploying to $(DEPLOY_TARGET)..."; \
		$(RSYNC) $(IMAGE) $(DEPLOY_TARGET); \
		echo "Deployed successfully"; \
	else \
		echo "Note: Disk server $(DISKSERVER) not found on network"; \
	fi

# Run tests (requires disk image to be built first)
test: $(IMAGE)
	@$(MAKE) -C tests test

clean:
	rm -rf $(BUILD)

# Help target
help:
	@echo "Runix Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all (default) - Build disk image and auto-deploy if server is available"
	@echo "  test          - Build disk image and run integration tests"
	@echo "  deploy        - Deploy disk image to $(DISKSERVER) (fails if not found)"
	@echo "  clean         - Remove all build artifacts"
	@echo "  help          - Show this help message"
