#!/usr/bin/env python3
"""pytest configuration and shared fixtures for Runix tests."""

import pytest
import subprocess
import json
import os
from pathlib import Path

# Test directory setup
TEST_DIR = Path(__file__).parent
REPO_ROOT = TEST_DIR.parent
BUILD_DIR = REPO_ROOT / "build"
DISK_IMAGE = BUILD_DIR / "runix.2mg"


@pytest.fixture(scope="session")
def disk_image():
    """Ensure disk image is built before tests run."""
    if not DISK_IMAGE.exists():
        pytest.fail(f"Disk image not found: {DISK_IMAGE}. Run 'make' first.")
    return str(DISK_IMAGE)


@pytest.fixture(scope="session")
def bootstub():
    """Ensure bootstub.bin is built."""
    bootstub_path = TEST_DIR / "bootstub.bin"
    if not bootstub_path.exists():
        # Build it
        subprocess.run(
            ["python3", "mkbootstub.py"],
            cwd=TEST_DIR,
            check=True
        )
    return str(bootstub_path)


class Pim65Runner:
    """Helper class to run pim65 tests."""

    def __init__(self, disk_image, bootstub):
        self.disk_image = disk_image
        self.bootstub = bootstub
        self.test_dir = TEST_DIR

    def run_boot_test(self, command_line=None, max_instructions=100000, timeout=2):
        """
        Run a boot test using the bootstub.

        Args:
            command_line: Optional command line to inject at shell prompt
            max_instructions: Max instructions to execute
            timeout: Timeout in seconds

        Returns:
            dict with keys: returncode, stdout, stderr, screen_output
        """
        # Create a temporary test config
        test_config = {
            "binaries": [{"file": "bootstub.bin", "load_addr": "0x1000"}],
            "start_addr": "0x1000"
        }

        config_path = self.test_dir / "temp_test.json"
        with open(config_path, "w") as f:
            json.dump(test_config, f)

        try:
            cmd = [
                "python3", "-m", "pim65",
                str(config_path),
                "--disk", self.disk_image,
                "--screen",
                "-n", str(max_instructions),
                "-t"
            ]

            # Add command line input if provided
            if command_line is not None:
                cmd.extend(["--keys", command_line])

            result = subprocess.run(
                cmd,
                cwd=self.test_dir,
                capture_output=True,
                text=True,
                timeout=timeout,
                env={**os.environ, "PYTHONPATH": str(REPO_ROOT)}
            )

            # Parse screen output from stderr
            screen_lines = []
            in_screen = False
            for line in result.stderr.split('\n'):
                if line.strip() == "Screen:":
                    in_screen = True
                    continue
                if in_screen:
                    screen_lines.append(line)

            return {
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "screen_output": '\n'.join(screen_lines).strip()
            }
        finally:
            # Clean up temp config
            if config_path.exists():
                config_path.unlink()

    def run_custom_test(self, binary_path, load_addr="0x2000",
                       start_addr=None, max_instructions=100000, timeout=2):
        """
        Run a custom test binary.

        Args:
            binary_path: Path to the test binary
            load_addr: Memory address to load binary (default 0x2000)
            start_addr: Starting PC (default same as load_addr)
            max_instructions: Max instructions to execute
            timeout: Timeout in seconds

        Returns:
            dict with keys: returncode, stdout, stderr, screen_output
        """
        if start_addr is None:
            start_addr = load_addr

        test_config = {
            "binaries": [{"file": str(binary_path), "load_addr": load_addr}],
            "start_addr": start_addr
        }

        config_path = self.test_dir / "temp_test.json"
        with open(config_path, "w") as f:
            json.dump(test_config, f)

        try:
            result = subprocess.run(
                [
                    "python3", "-m", "pim65",
                    str(config_path),
                    "--disk", self.disk_image,
                    "--screen",
                    "-n", str(max_instructions),
                    "-t"
                ],
                cwd=self.test_dir,
                capture_output=True,
                text=True,
                timeout=timeout,
                env={**os.environ, "PYTHONPATH": str(REPO_ROOT)}
            )

            # Parse screen output from stderr
            screen_lines = []
            in_screen = False
            for line in result.stderr.split('\n'):
                if line.strip() == "Screen:":
                    in_screen = True
                    continue
                if in_screen:
                    screen_lines.append(line)

            return {
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "screen_output": '\n'.join(screen_lines).strip()
            }
        finally:
            # Clean up temp config
            if config_path.exists():
                config_path.unlink()


@pytest.fixture
def pim65(disk_image, bootstub):
    """Provide a Pim65Runner instance for tests."""
    return Pim65Runner(disk_image, bootstub)
