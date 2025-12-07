#!/usr/bin/env python3
"""Command-line interface for pim65 6502 simulator."""

import argparse
import sys
from pathlib import Path

from .config import SimulatorConfig
from .cpu import BrkAbortError, InvalidOpcodeError
from .simulator import Simulator


def main(argv: list[str] | None = None) -> int:
    """Main entry point for the simulator CLI."""
    parser = argparse.ArgumentParser(
        prog="pim65",
        description="A results-accurate 6502 simulator with Apple II support"
    )
    parser.add_argument(
        "config",
        help="Path to JSON configuration file"
    )
    parser.add_argument(
        "-t", "--trace",
        action="store_true",
        help="Print instruction trace"
    )
    parser.add_argument(
        "-n", "--max-instructions",
        type=int,
        default=1000,
        metavar="N",
        help="Maximum instructions to execute (default: 1000)"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "--brk-abort",
        action="store_true",
        help="Abort with register dump on BRK 00"
    )
    parser.add_argument(
        "--screen",
        action="store_true",
        help="Dump 40-column text screen on exit"
    )
    parser.add_argument(
        "--keys",
        action="append",
        metavar="STRING",
        help="Keyboard input string (C-style escapes, \\n=CR). Can specify multiple."
    )
    parser.add_argument(
        "--disk",
        metavar="IMAGE",
        help="Path to .2mg disk image for hard drive emulation (slot 2)"
    )

    args = parser.parse_args(argv)

    # Load configuration
    try:
        config = SimulatorConfig.from_file(args.config)
    except FileNotFoundError:
        print(f"Error: Config file not found: {args.config}", file=sys.stderr)
        return 1
    except (KeyError, ValueError) as e:
        print(f"Error: Invalid config file: {e}", file=sys.stderr)
        return 1

    # Create simulator
    sim = Simulator(config)

    # Set up Apple II hardware
    if args.keys:
        sim.setup_keyboard(args.keys)

    if args.disk:
        try:
            sim.setup_hard_drive(args.disk)
        except FileNotFoundError:
            print(f"Error: Disk image not found: {args.disk}", file=sys.stderr)
            return 1
        except IOError as e:
            print(f"Error: Cannot open disk image: {e}", file=sys.stderr)
            return 1

    # Load binaries
    try:
        sim.load()
    except FileNotFoundError as e:
        print(f"Error: Binary file not found: {e}", file=sys.stderr)
        sim.cleanup()
        return 1

    # Run simulation
    try:
        success = sim.run(
            max_instructions=args.max_instructions,
            trace=args.trace,
            brk_abort=args.brk_abort
        )
    except BrkAbortError as e:
        print(f"BRK abort: {e}", file=sys.stderr)
        if args.trace:
            print("\nTrace (last 20 instructions):", file=sys.stderr)
            for line in sim.get_trace()[-20:]:
                print(f"  {line}", file=sys.stderr)
        if args.screen:
            screen = sim.dump_screen()
            if screen:
                print("\nScreen:", file=sys.stderr)
                print(screen, file=sys.stderr)
        sim.cleanup()
        return 1
    except InvalidOpcodeError as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.trace:
            print("\nTrace (last 20 instructions):", file=sys.stderr)
            for line in sim.get_trace()[-20:]:
                print(f"  {line}", file=sys.stderr)
        sim.cleanup()
        return 1
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.trace:
            print("\nTrace (last 20 instructions):", file=sys.stderr)
            for line in sim.get_trace()[-20:]:
                print(f"  {line}", file=sys.stderr)
        if args.screen:
            screen = sim.dump_screen()
            if screen:
                print("\nScreen:", file=sys.stderr)
                print(screen, file=sys.stderr)
        sim.cleanup()
        return 1

    # Print trace if requested
    if args.trace:
        print("Trace:")
        for line in sim.get_trace():
            print(f"  {line}")
        print()

    if args.verbose or args.trace:
        print(f"Instructions executed: {sim.instruction_count}")

    # Dump screen if requested - always to stderr for consistency
    if args.screen:
        screen = sim.dump_screen()
        if screen:
            print("\nScreen:", file=sys.stderr)
            print(screen, file=sys.stderr)

    sim.cleanup()

    if success:
        if args.verbose:
            print("Simulation completed successfully")
        return 0
    else:
        print("Simulation halted without reaching success address", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
