"""Configuration file parser for pim65 simulator."""

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass
class BinaryConfig:
    """Configuration for a binary file to load."""
    file: str
    load_addr: int


@dataclass
class SimulatorConfig:
    """Complete simulator configuration."""
    binaries: list[BinaryConfig]
    start_addr: int

    @classmethod
    def from_file(cls, config_path: str | Path) -> "SimulatorConfig":
        """Load configuration from a JSON file."""
        config_path = Path(config_path)

        with open(config_path, "r") as f:
            data = json.load(f)

        binaries = []
        for b in data.get("binaries", []):
            file_path = b["file"]
            # Resolve relative paths from config file location
            if not Path(file_path).is_absolute():
                file_path = str(config_path.parent / file_path)

            load_addr = cls._parse_addr(b["load_addr"])
            binaries.append(BinaryConfig(file=file_path, load_addr=load_addr))

        start_addr = cls._parse_addr(data["start_addr"])

        return cls(binaries=binaries, start_addr=start_addr)

    @staticmethod
    def _parse_addr(value: str | int) -> int:
        """Parse an address from string (hex) or int."""
        if isinstance(value, int):
            return value
        if isinstance(value, str):
            value = value.strip()
            if value.startswith("0x") or value.startswith("0X"):
                return int(value, 16)
            if value.startswith("$"):
                return int(value[1:], 16)
            return int(value)
        raise ValueError(f"Invalid address: {value}")
