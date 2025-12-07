#!/usr/bin/env python3
"""Boot tests for Runix."""

import pytest


def test_runix_boots(pim65):
    """Test that Runix boots successfully."""
    result = pim65.run_boot_test(max_instructions=100000)

    # We expect it to hit the instruction limit (not an error)
    # because it's waiting for input at the shell prompt
    assert result["returncode"] != 0, "Should hit instruction limit"
    assert "Instruction limit" in result["stderr"], "Should timeout at instruction limit"


def test_welcome_message(pim65):
    """Test that Runix displays the welcome message."""
    result = pim65.run_boot_test(max_instructions=100000)

    screen = result["screen_output"]
    assert "Welcome to Runix" in screen, "Should display welcome message"


def test_shell_prompt(pim65):
    """Test that Runix displays the shell prompt."""
    result = pim65.run_boot_test(max_instructions=100000)

    screen = result["screen_output"]
    assert "#" in screen, "Should display shell prompt (#)"


def test_boot_completes_quickly(pim65):
    """Test that boot completes within reasonable instruction count."""
    # Boot should complete well before 100K instructions
    result = pim65.run_boot_test(max_instructions=100000)

    # If we got screen output, boot succeeded
    screen = result["screen_output"]
    assert len(screen) > 0, "Should produce screen output"
    assert "Welcome to Runix" in screen, "Boot should complete and show welcome"
