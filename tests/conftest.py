#!/usr/bin/env python3
"""pytest configuration and shared fixtures for Runix tests."""

import pytest
import subprocess
import sys
import os
from pathlib import Path
from io import StringIO

# Test directory setup
TEST_DIR = Path(__file__).parent
REPO_ROOT = TEST_DIR.parent
BUILD_DIR = REPO_ROOT / "build"
DISK_IMAGE = BUILD_DIR / "runix.2mg"

# Add pim65 to path for direct import
sys.path.insert(0, str(REPO_ROOT))

from pim65.config import SimulatorConfig, BinaryConfig
from pim65.simulator import Simulator
from pim65.cpu import BrkAbortError, InvalidOpcodeError


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
    """Helper class to run pim65 tests directly (no subprocess)."""

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
            timeout: Timeout in seconds (ignored in direct mode)

        Returns:
            dict with keys: returncode, stdout, stderr, screen_output
        """
        # Create config directly
        config = SimulatorConfig(
            binaries=[BinaryConfig(file=str(self.test_dir / "bootstub.bin"), load_addr=0x1000)],
            start_addr=0x1000
        )

        # Create simulator
        sim = Simulator(config)

        # Set up hardware
        if command_line:
            sim.setup_keyboard([command_line])
        sim.setup_hard_drive(self.disk_image)

        # Load binaries
        try:
            sim.load()
        except FileNotFoundError as e:
            return {
                "returncode": 1,
                "stdout": "",
                "stderr": f"Error: Binary file not found: {e}",
                "screen_output": f"Error: Binary file not found: {e}"
            }

        # Capture stderr for trace output
        old_stderr = sys.stderr
        stderr_capture = StringIO()
        sys.stderr = stderr_capture

        # Run simulation
        returncode = 0
        try:
            success = sim.run(
                max_instructions=max_instructions,
                trace=False,  # Don't trace by default to speed up tests
                brk_abort=False
            )
            if not success:
                returncode = 1
        except (BrkAbortError, InvalidOpcodeError, RuntimeError) as e:
            returncode = 1
            stderr_capture.write(f"Error: {e}\n")
        finally:
            # Restore stderr
            sys.stderr = old_stderr

        # Get screen output
        screen_output = sim.dump_screen() or ""

        # Cleanup
        sim.cleanup()

        stderr_text = stderr_capture.getvalue()

        return {
            "returncode": returncode,
            "stdout": "",
            "stderr": stderr_text,
            "screen_output": screen_output
        }

    def run_custom_test(self, binary_path, load_addr="0x2000",
                       start_addr=None, max_instructions=100000, timeout=2):
        """
        Run a custom test binary.

        Args:
            binary_path: Path to the test binary
            load_addr: Memory address to load binary (default 0x2000)
            start_addr: Starting PC (default same as load_addr)
            max_instructions: Max instructions to execute
            timeout: Timeout in seconds (ignored in direct mode)

        Returns:
            dict with keys: returncode, stdout, stderr, screen_output
        """
        if start_addr is None:
            start_addr = load_addr

        # Create config directly
        if isinstance(load_addr, str):
            load_addr = int(load_addr, 16) if load_addr.startswith("0x") else int(load_addr)
        if isinstance(start_addr, str):
            start_addr = int(start_addr, 16) if start_addr.startswith("0x") else int(start_addr)

        config = SimulatorConfig(
            binaries=[BinaryConfig(file=str(binary_path), load_addr=load_addr)],
            start_addr=start_addr
        )

        # Create simulator
        sim = Simulator(config)
        sim.setup_hard_drive(self.disk_image)

        # Load binaries
        try:
            sim.load()
        except FileNotFoundError as e:
            return {
                "returncode": 1,
                "stdout": "",
                "stderr": f"Error: Binary file not found: {e}",
                "screen_output": f"Error: Binary file not found: {e}"
            }

        # Capture stderr
        old_stderr = sys.stderr
        stderr_capture = StringIO()
        sys.stderr = stderr_capture

        # Run simulation
        returncode = 0
        try:
            success = sim.run(
                max_instructions=max_instructions,
                trace=False,
                brk_abort=False
            )
            if not success:
                returncode = 1
        except (BrkAbortError, InvalidOpcodeError, RuntimeError) as e:
            returncode = 1
            stderr_capture.write(f"Error: {e}\n")
        finally:
            sys.stderr = old_stderr

        # Get screen output
        screen_output = sim.dump_screen() or ""

        # Cleanup
        sim.cleanup()

        stderr_text = stderr_capture.getvalue()

        return {
            "returncode": returncode,
            "stdout": "",
            "stderr": stderr_text,
            "screen_output": screen_output
        }


@pytest.fixture
def pim65(disk_image, bootstub):
    """Provide a Pim65Runner instance for tests."""
    return Pim65Runner(disk_image, bootstub)
