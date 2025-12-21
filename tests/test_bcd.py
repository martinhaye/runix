#!/usr/bin/env python3
"""BCD (Binary Coded Decimal) rune tests for Runix."""

import pytest
from pathlib import Path
import re

def test_bcd(pim65):
    """Test the bcd rune."""
    result = pim65.run_boot_test(
        command_line="cd rtest\\npwd\\ntestbcd\\nhalt\\n",
        max_instructions=100000,
        timeout=2
    )

    # Debug output - show all results on failure
    print("\n=== TEST RESULTS ===")
    print(f"Return code: {result['returncode']}")
    print(f"\n=== STDOUT ===\n{result['stdout']}")
    print(f"\n=== FULL STDERR ===")
    print(result['stderr'])
    print(f"\n=== SCREEN OUTPUT ===\n{result['screen_output']}")
    print("=== END TEST RESULTS ===\n")

    screen = result["screen_output"]
    assert re.search(r'Test 1:.*23.01.FF\b', screen)
    assert re.search(r'Test 2:.*-> 123\b', screen)
    assert re.search(r'Test 3:.*-> 123\b', screen)
    assert re.search(r'Test 4:.*-> 124\b', screen)
    assert re.search(r'Test 5:.*-> 100\b', screen)
    assert re.search(r'Test 6:.*-> 100000\b', screen)

