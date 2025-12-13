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

    screen = result["screen_output"]
    assert re.search(r'Test 1:.*23.01.FF', screen)
    assert re.search(r'Test 2:.*-> 123', screen)
    assert re.search(r'Test 3:.*-> 123', screen)

