# Runix Integration Tests using pim65

PYTHON = python3
# Set PYTHONPATH to include parent directory so pim65 module can be found
export PYTHONPATH := $(shell pwd)/..
PIM65 = $(PYTHON) -m pim65
DISK_IMAGE = ../build/runix.2mg

# Default: run tests
.PHONY: all test test-boot test-cat clean

all: test

test: test-boot test-cat

# Generate boot stub if needed
bootstub.bin: mkbootstub.py
	$(PYTHON) mkbootstub.py

# Run the boot test
test-boot: bootstub.bin $(DISK_IMAGE)
	@echo "=== Running boot test ==="
	$(PIM65) boot_test.json --disk $(DISK_IMAGE) --screen -n 100000 -t 2>&1 | tail -50

# Run the cat test
test-cat: bootstub.bin $(DISK_IMAGE)
	@echo "=== Running cat test ==="
	@$(PIM65) cat_test.json --disk $(DISK_IMAGE) --screen -n 500000 \
		--keys "cat hello.txt\n" 2>&1 | tee /tmp/cat_test_output.txt | tail -60
	@echo ""
	@echo "=== Verifying cat output ==="
	@if grep -q "Hello from Runix" /tmp/cat_test_output.txt && \
	    grep -q "Testing the cat utility" /tmp/cat_test_output.txt; then \
		echo "✓ Cat test PASSED - found expected output"; \
	else \
		echo "✗ Cat test FAILED - expected output not found"; \
		exit 1; \
	fi

# Run with more verbose output for debugging
debug: bootstub.bin $(DISK_IMAGE)
	$(PIM65) boot_test.json --disk $(DISK_IMAGE) --screen --brk-abort -n 100000 -t

clean:
	rm -f bootstub.bin /tmp/cat_test_output.txt
