#!/usr/bin/env python3
"""Pool tests for Runix."""

import pytest
from pathlib import Path
import re

def test_pool(pim65):
    """Test the pool rune."""
    result = pim65.run_boot_test(
        command_line="cd rtest\\npwd\\ntestpool\\nhalt\\n",
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
    assert "T1: id=$0002 tot=$0006 np=$0001" in screen
    assert "T2: HELLO" in screen


def test_pool_free_characterization(pim65):
    """Characterize the current pool free path."""
    result = pim65.run_boot_test(
        command_line="cd rtest\\ntestpoolfree\\n",
        max_instructions=100000,
        timeout=2
    )

    screen = result["screen_output"]
    assert "Testing pool free:" in screen
    assert "T1: HELLO" in screen
    assert "T2: free" in screen
    assert "Fatal error: pool-pg-corrupt" in screen


def test_pool_resize_characterization(pim65):
    """Characterize the current pool resize path."""
    result = pim65.run_boot_test(
        command_line="cd rtest\\ntestpoolrz\\n",
        max_instructions=100000,
        timeout=2
    )

    screen = result["screen_output"]
    assert "Testing pool resize:" in screen
    assert "T1: HELLO" in screen
    assert "T2: resize" in screen
    assert "Fatal error: pool-pg-corrupt" in screen
