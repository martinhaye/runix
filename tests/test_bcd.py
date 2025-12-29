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
    assert "T1: '123' = 123." in screen
    assert "T2: '-123' = -123." in screen
    assert "T3a: '00123' = 123." in screen
    assert "T3b: '0' = 0." in screen
    assert "T4a: inc 123 = 124." in screen
    assert "T4b: inc -123 = -122." in screen
    assert "T4c: inc -1 = 0." in screen
    assert "T5: inc 99 = 100." in screen
    assert "T6: inc 99999 = 100000." in screen
    assert "T7: dec 123 = 122." in screen
    assert "T8: dec 10000 = 9999." in screen
    assert "T9: dec 0 = -1." in screen
    assert "T10: cmp 123 vs 123 = $0000." in screen
    assert "T11a: cmp 122 vs 123 = $FFFF." in screen
    assert "T11b: cmp -12 vs 12 = $FFFF." in screen
    assert "T12a: cmp 123 vs 122 = $0001." in screen
    assert "T12b: cmp 12 vs -12 = $0001." in screen
    assert "T12c: cmp -12 vs -13 = $0001." in screen

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

    assert "T13: 123 + 456 = 579." in screen
    assert "T14: 99999 + 3 = 100002." in screen
    assert "T15: 999999 + 3 = 1000002." in screen
    assert "T16: 4 + 9999 = 10003." in screen
    assert "T17: 5 + 99999 = 100004." in screen
    assert "T18: -5 + -3 = -8." in screen
    assert "T19a: 5 + -3 = 2." in screen
    assert "T19b: 5 + -8 = -3." in screen
    assert "T20a: -5 + 2 = -3." in screen
    assert "T20b: -5 + 8 = 3." in screen
    assert "T21: 456 - 123 = 333." in screen
    assert "T22: 1000 - 3 = 997." in screen
    assert "T23: 10000 - 4 = 9996." in screen
    assert "T24a: -5 - -3 = -2." in screen
    assert "T24b: -5 - -8 = 3." in screen
    assert "T25a: -5 - 3 = -8" in screen
    assert "T25b: 5 - -8 = 13." in screen
    assert "T26: 123 * 45 = 5535." in screen
    assert "T27: 12 * 345 = 4140." in screen
    assert "T28: 12345 * 87654 = 1082088630." in screen
    assert "T29a: -2 * 3 = -6." in screen
    assert "T29b: -2 * -3 = 6." in screen

