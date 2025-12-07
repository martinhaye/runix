# Runix Integration Tests using pytest + pim65

# Use venv if available, otherwise fall back to system python
VENV_PYTHON = ../venv/bin/python3
PYTHON = $(shell [ -x $(VENV_PYTHON) ] && echo $(VENV_PYTHON) || echo python3)
PYTEST = $(PYTHON) -m pytest
# Set PYTHONPATH to include parent directory so pim65 module can be found
export PYTHONPATH := $(shell pwd)/..
DISK_IMAGE = ../build/runix.2mg

# Default: run tests
.PHONY: all test test-verbose clean

all: test

# Generate boot stub if needed
bootstub.bin: mkbootstub.py
	$(PYTHON) mkbootstub.py

# Run all tests with pytest
test: bootstub.bin $(DISK_IMAGE)
	@echo "=== Running Runix tests with pytest ==="
	$(PYTEST) -v

# Run tests with verbose output and don't capture stdout/stderr
test-verbose: bootstub.bin $(DISK_IMAGE)
	@echo "=== Running Runix tests (verbose) ==="
	$(PYTEST) -vv -s

# Run specific test file (use test-<name> to run test_<name>.py)
test-%: bootstub.bin $(DISK_IMAGE)
	$(PYTEST) -v test_$*.py

clean:
	rm -f bootstub.bin temp_test.json
	rm -rf __pycache__ .pytest_cache
