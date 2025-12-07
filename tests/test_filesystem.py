#!/usr/bin/env python3
"""Test filesystem navigation commands: cd, pwd, ls."""

import pytest
from pathlib import Path


def test_pwd_at_root(pim65):
    """Test that pwd shows / at boot."""
    result = pim65.run_boot_test(
        command_line="pwd\\nhalt\\n",
        max_instructions=100000,
        timeout=2
    )

    screen = result["screen_output"]
    assert "/" in screen, "pwd should show root directory /"


def test_ls_shows_files(pim65):
    """Test that ls shows files in root directory."""
    result = pim65.run_boot_test(
        command_line="ls\\nhalt\\n",
        max_instructions=100000,
        timeout=2
    )

    screen = result["screen_output"]
    # Should show at least the kernel and runes directory
    assert "runix" in screen or "runes" in screen, \
        "ls should show files in root directory"


def test_cd_to_runes(pim65):
    """Test cd into runes directory."""
    # cd into runes, then pwd to verify
    result = pim65.run_boot_test(
        command_line="cd runes\\npwd\\nhalt\\n",
        max_instructions=100000,
        timeout=2
    )

    screen = result["screen_output"]
    assert "runes" in screen, "pwd should show we're in /runes"


def test_cd_and_ls_runes(pim65):
    """Test cd into runes and list its contents."""
    result = pim65.run_boot_test(
        command_line="cd runes\\nls\\nhalt\\n",
        max_instructions=100000,
        timeout=2
    )

    screen = result["screen_output"]
    # Should show rune files like 00-system
    assert "00" in screen or "rune" in screen.lower(), \
        "ls in /runes should show rune files"


def test_cd_parent_directory(pim65):
    """Test cd .. to go back to parent."""
    result = pim65.run_boot_test(
        command_line="cd runes\\ncd ..\\npwd\\nhalt\\n",
        max_instructions=100000,
        timeout=2
    )

    screen = result["screen_output"]
    # After cd .., pwd should show root again
    # We're looking for just "/" not "/runes"
    lines = screen.split('\n')
    # Find the last pwd output
    assert any('/' in line and 'runes' not in line for line in lines[-5:]), \
        "After cd .., pwd should show root directory"


def test_multiple_commands(pim65):
    """Test a sequence of navigation commands."""
    result = pim65.run_boot_test(
        command_line="pwd\\nls\\ncd runes\\npwd\\nls\\ncd ..\\npwd\\nhalt\\n",
        max_instructions=200000,
        timeout=3
    )

    screen = result["screen_output"]
    # Basic sanity check - should have executed multiple commands
    assert len(screen) > 20, "Should have output from multiple commands"
    assert "/" in screen, "Should show root directory at some point"
