#!/usr/bin/env python3
"""
World of Warcraft Raid Assignment Tool

This script reads Google Sheets containing raid assignments and generates
text files with formatted assignments for World of Warcraft raids.
"""

import argparse
import sys
import tomllib
from pathlib import Path
from typing import Dict, Any, Optional
from urllib.parse import urlparse

import pandas as pd

from sparks.bwl import process_bwl_assignments
from sparks.google_web_client import GoogleWebClient
# from sparks.mc import process_mc_assignments


class RaidAssignmentGenerator:
    """Generates raid assignments from Google Sheets data."""

    SUPPORTED_RAIDS = ["MC", "BWL", "AQ40", "Naxx"]

    def __init__(self, config_path: str) -> None:
        """Initialize with configuration file path."""
        self.config_path = Path(config_path)
        self.config: Dict[str, Any] = {}
        self.sheet_data: Optional[pd.DataFrame] = None
        self.web_client = GoogleWebClient()

    def load_config(self) -> None:
        """Load configuration from TOML file."""
        try:
            with open(self.config_path, 'rb') as f:
                self.config = tomllib.load(f)

            self._validate_config()
            self.web_client.set_config(self.config)
        except FileNotFoundError:
            raise FileNotFoundError(f"Configuration file not found: {self.config_path}")
        except tomllib.TOMLDecodeError as e:
            raise ValueError(f"Invalid TOML configuration: {e}")

    def _validate_config(self) -> None:
        """Validate the loaded configuration."""
        required_keys = ["spreadsheet_url", "raid_name", "sheet"]

        for key in required_keys:
            if key not in self.config:
                raise ValueError(f"Missing required configuration key: {key}")

        if self.config["raid_name"] not in self.SUPPORTED_RAIDS:
            raise ValueError(
                f"Unsupported raid name: {self.config['raid_name']}. "
                f"Supported raids: {', '.join(self.SUPPORTED_RAIDS)}"
            )

        # Validate URL format
        try:
            parsed_url = urlparse(self.config["spreadsheet_url"])
            if not all([parsed_url.scheme, parsed_url.netloc]):
                raise ValueError("Invalid spreadsheet URL format")
        except Exception:
            raise ValueError("Invalid spreadsheet URL format")

    def generate_assignments(self) -> str:
        """Generate formatted raid assignments text."""
        if self.sheet_data is None:
            raise RuntimeError("Sheet data not loaded. Call fetch_sheet_data() first.")

        raid_name = self.config["raid_name"]
        assignments = []

        assignments.append(f"=== {raid_name} RAID ASSIGNMENTS ===\n")

        # Process the data based on raid type
        # This is a placeholder - actual implementation would depend on spreadsheet structure
        assignments.extend(self._process_raid_data(raid_name))

        return "\n".join(assignments)

    def _process_raid_data(self, raid_name: str) -> list[str]:
        """Process raid-specific data from the spreadsheet."""
        assignments = []

        # Placeholder implementation - would need to be customized based on
        # the actual structure of your Google Sheets
        assignments.append(f"Processing {raid_name} assignments...")
        assignments.append(f"Found {len(self.sheet_data)} entries in spreadsheet")

        # if raid_name == "MC":
        #     assignments.extend(process_mc_assignments(self.sheet_data))
        if raid_name == "BWL":
            assignments.extend(process_bwl_assignments(self.sheet_data))
        # elif raid_name == "AQ40":
        #     assignments.extend(process_aq40_assignments(self.sheet_data))
        # elif raid_name == "Naxx":

        # Example processing (would need real implementation):
        # for index, row in self.sheet_data.iterrows():
        #     player_name = row.get('Player', 'Unknown')
        #     assignment = row.get('Assignment', 'No assignment')
        #     assignments.append(f"{player_name}: {assignment}")

        return assignments

    def save_to_file(self, assignments: str, output_path: Optional[str] = None) -> str:
        """Save assignments to a text file."""
        if output_path is None:
            raid_name = self.config["raid_name"]
            output_path = f"{raid_name}_assignments.txt"

        output_file = Path(output_path)

        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(assignments)

            print(f"Assignments saved to: {output_file.absolute()}")
            return str(output_file.absolute())

        except IOError as e:
            raise RuntimeError(f"Failed to save assignments to file: {e}")

    def fetch_sheet_data(self) -> None:
        self.sheet_data = self.web_client.fetch_sheet_data()


def main() -> int:
    """Main entry point for the CLI application."""
    parser = argparse.ArgumentParser(
        description="Generate World of Warcraft raid assignments from Google Sheets",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py config.toml
  python main.py --output custom_assignments.txt config.toml
        """
    )

    parser.add_argument(
        "config_file",
        help="Path to TOML configuration file"
    )

    parser.add_argument(
        "--output", "-o",
        help="Output file path (default: <RAID_NAME>_assignments.txt)"
    )

    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )

    args = parser.parse_args()

    try:
        # Initialize generator
        app = RaidAssignmentGenerator(args.config_file)

        if args.verbose:
            print(f"Loading configuration from: {args.config_file}")

        # Load configuration
        app.load_config()

        if args.verbose:
            print(f"Raid: {app.config['raid_name']}")
            print(f"Spreadsheet: {app.config['spreadsheet_url']}")
            print(f"Page: {app.config['sheet']}")

        # Fetch data from Google Sheets
        print("Fetching data from Google Sheets...")
        app.fetch_sheet_data()

        # Generate assignments
        print("Generating raid assignments...")
        assignments = app.generate_assignments()

        # Save to file
        output_file = app.save_to_file(assignments, args.output)

        print(f"✓ Raid assignments generated successfully!")
        return 0

    except KeyboardInterrupt:
        print("\nOperation cancelled by user.")
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
