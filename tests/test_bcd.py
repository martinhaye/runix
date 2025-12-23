#!/usr/bin/env python3
"""BCD (Binary Coded Decimal) rune tests for Runix."""

import pytest
from pathlib import Path
import re

def test_bcd(pim65):
    """Test the bcd rune."""
    result = pim65.run_boot_test(
        command_line="cd rtest\\npwd\\ntestbcd1\\nhalt\\n",
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
    assert re.search(r'Test 1:.*00.23.01.FF\b', screen)
    assert re.search(r'Test 1b:.*80.34.12.FF\b', screen)
    assert re.search(r'Test 2:.*-> 123\b', screen)
    assert re.search(r'Test 2b:.*-> -123\b', screen)
    assert re.search(r'Test 3:.*-> 123\b', screen)
    assert re.search(r'Test 3b:.*-> 0\b', screen)
    assert re.search(r'Test 4:.*-> 124\b', screen)
    assert re.search(r'Test 4b:.*-> -122\b', screen)
    assert re.search(r'Test 4c:.*-> 0\b', screen)
    assert re.search(r'Test 5:.*-> 100\b', screen)
    assert re.search(r'Test 6:.*-> 100000\b', screen)
    assert re.search(r'Test 7:.*-> 122\b', screen)
    assert re.search(r'Test 8:.*-> 9999\b', screen)
    assert re.search(r'Test 9:.*-> -1\b', screen)
    assert re.search(r'Test 10:.*-> 00\b', screen)
    assert re.search(r'Test 11:.*-> FF\b', screen)
    assert re.search(r'Test 12:.*-> 01\b', screen)

    result = pim65.run_boot_test(
        command_line="cd rtest\\npwd\\ntestbcd2\\nhalt\\n",
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

    assert re.search(r'Test 13:.*-> 579\b', screen)
    assert re.search(r'Test 14:.*-> 100002\b', screen)
    assert re.search(r'Test 15:.*-> 1000002\b', screen)
    assert re.search(r'Test 16:.*-> 10003\b', screen)
    assert re.search(r'Test 17:.*-> 100004\b', screen)
    assert re.search(r'Test 18:.*-> 333\b', screen)
    assert re.search(r'Test 19:.*-> 997\b', screen)
    assert re.search(r'Test 20:.*-> 9996\b', screen)
    assert re.search(r'Test 21:.*-> 1035\b', screen)
    assert re.search(r'Test 22:.*-> 7812\b', screen)
    assert re.search(r'Test 23:.*-> 5535\b', screen)
    assert re.search(r'Test 24:.*-> 4140\b', screen)
    assert re.search(r'Test 25:.*-> 1082088630\b', screen)

