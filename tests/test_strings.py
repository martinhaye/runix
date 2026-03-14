#!/usr/bin/env python3
"""String-path characterization tests for Runix."""


def test_string_formatting_rtest(pim65):
    """Characterize current %s and ldstr behavior."""
    result = pim65.run_boot_test(
        command_line="cd rtest\\nteststrfmt\\nhalt\\n",
        max_instructions=100000,
        timeout=2,
    )

    screen = result["screen_output"]
    assert "Testing strings:" in screen
    # Current ldstr + %s path skips the first byte of zero-terminated inline strings.
    assert "T1: inline literal" in screen
    assert "T2: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" in screen
    # Make sure the byte after isn't printed
    assert "T3: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB" in screen


def test_fatal_path_rtest(pim65):
    """Characterize the fatal error path."""
    result = pim65.run_boot_test(
        command_line="cd rtest\\ntestfatal\\n",
        max_instructions=100000,
        timeout=2,
    )

    screen = result["screen_output"]
    assert "Before fatal." in screen
    assert "Fatal error: fatal-path-ok" in screen
