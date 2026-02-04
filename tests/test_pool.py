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
    assert "T1: tot=$0006 np=$0001" in screen
