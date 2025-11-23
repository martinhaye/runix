#!/usr/bin/env python3
"""Command-line interface for pim65 6502 simulator."""

import argparse
import sys
from pathlib import Path

from .config import SimulatorConfig
from .cpu import InvalidOpcodeError
from .simulator import Simulator


def main(argv: list[str] | None = None) -> int:
    """Main entry point for the simulator CLI."""
    parser = argparse.ArgumentParser(
        prog="pim65",
        description="A results-accurate 6502 simulator"
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

    # Create and run simulator
    sim = Simulator(config)

    try:
        sim.load()
    except FileNotFoundError as e:
        print(f"Error: Binary file not found: {e}", file=sys.stderr)
        return 1

    try:
        success = sim.run(
            max_instructions=args.max_instructions,
            trace=args.trace
        )
    except InvalidOpcodeError as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.trace:
            print("\nTrace:", file=sys.stderr)
            for line in sim.get_trace()[-20:]:  # Last 20 instructions
                print(f"  {line}", file=sys.stderr)
        return 1
    except RuntimeError as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.trace:
            print("\nTrace (last 20 instructions):", file=sys.stderr)
            for line in sim.get_trace()[-20:]:
                print(f"  {line}", file=sys.stderr)
        return 1

    # Print trace if requested
    if args.trace:
        print("Trace:")
        for line in sim.get_trace():
            print(f"  {line}")
        print()

    if args.verbose or args.trace:
        print(f"Instructions executed: {sim.instruction_count}")

    if success:
        if args.verbose:
            print("Simulation completed successfully")
        return 0
    else:
        print("Simulation halted without reaching success address", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
