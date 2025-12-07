#!/usr/bin/env python3
"""Test the halt command."""

import pytest
from pathlib import Path


def test_halt_from_shell(pim65):
    """Test that running 'halt' from the shell exits cleanly via $FFF9."""
    # Boot Runix and inject "halt\n" at the shell prompt (\n = CR in pim65)
    result = pim65.run_boot_test(
        command_line="halt\\n",
        max_instructions=100000,
        timeout=2
    )

    # Should NOT hit instruction limit since halt exits at $FFF9
    assert "Instruction limit" not in result["stderr"], \
        "halt command should exit cleanly without reaching instruction limit"

    # Should exit with code 0 (clean exit)
    assert result["returncode"] == 0, "Should exit cleanly (returncode 0)"
