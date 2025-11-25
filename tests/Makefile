# Runix Integration Tests using pim65

PYTHON = python3
# Set PYTHONPATH to include parent directory so pim65 module can be found
export PYTHONPATH := $(shell pwd)/..
PIM65 = $(PYTHON) -m pim65
DISK_IMAGE = ../build/runix.2mg

# Default: run tests
.PHONY: all test clean

all: test

# Generate boot stub if needed
bootstub.bin: mkbootstub.py
	$(PYTHON) mkbootstub.py

# Run the boot test
test: bootstub.bin $(DISK_IMAGE)
	@echo "=== Running boot test ==="
	$(PIM65) boot_test.json --disk $(DISK_IMAGE) --screen -n 100000 -t 2>&1 | tail -50

# Run with more verbose output for debugging
debug: bootstub.bin $(DISK_IMAGE)
	$(PIM65) boot_test.json --disk $(DISK_IMAGE) --screen --brk-abort -n 100000 -t

clean:
	rm -f bootstub.bin
