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
    assert re.search(r'T1:.*00.23.01.FF\b', screen)
    assert re.search(r'T1b:.*80.34.12.FF\b', screen)
    assert re.search(r'T2:.*->123\b', screen)
    assert re.search(r'T2b:.*->-123\b', screen)
    assert re.search(r'T3:.*->123\b', screen)
    assert re.search(r'T3b:.*->0\b', screen)
    assert re.search(r'T4:.*->124\b', screen)
    assert re.search(r'T4b:.*->-122\b', screen)
    assert re.search(r'T4c:.*->0\b', screen)
    assert re.search(r'T5:.*->100\b', screen)
    assert re.search(r'T6:.*->100000\b', screen)
    assert re.search(r'T7:.*->122\b', screen)
    assert re.search(r'T8:.*->9999\b', screen)
    assert re.search(r'T9:.*->-1\b', screen)
    assert re.search(r'T10:.*->00\b', screen)
    assert re.search(r'T11:.*->FF\b', screen)
    assert re.search(r'T11b:.*->FF\b', screen)
    assert re.search(r'T12:.*->01\b', screen)
    assert re.search(r'T12b:.*->01\b', screen)
    assert re.search(r'T12c:.*->01\b', screen)

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

    assert re.search(r'T13:.*->579\b', screen)
    assert re.search(r'T14:.*->100002\b', screen)
    assert re.search(r'T15:.*->1000002\b', screen)
    assert re.search(r'T16:.*->10003\b', screen)
    assert re.search(r'T17:.*->100004\b', screen)
    assert re.search(r'T18:.*->333\b', screen)
    assert re.search(r'T19:.*->997\b', screen)
    assert re.search(r'T20:.*->9996\b', screen)
    assert re.search(r'T21:.*->1035\b', screen)
    assert re.search(r'T22:.*->7812\b', screen)
    assert re.search(r'T23:.*->5535\b', screen)
    assert re.search(r'T24:.*->4140\b', screen)
    assert re.search(r'T25:.*->1082088630\b', screen)

