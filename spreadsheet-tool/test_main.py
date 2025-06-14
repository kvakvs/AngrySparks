#!/usr/bin/env python3
"""
Basic tests for the WoW Raid Assignment Tool
"""

import pytest
import tempfile
import os
from pathlib import Path
from unittest.mock import patch, MagicMock

from main import RaidAssignmentGenerator


class TestRaidAssignmentGenerator:
    """Test cases for RaidAssignmentGenerator class."""

    def test_supported_raids(self):
        """Test that supported raids are correctly defined."""
        expected_raids = ["MC", "BWL", "AQ40", "Naxx"]
        assert RaidAssignmentGenerator.SUPPORTED_RAIDS == expected_raids

    def test_init(self):
        """Test initialization of RaidAssignmentGenerator."""
        config_path = "test_config.toml"
        generator = RaidAssignmentGenerator(config_path)

        assert generator.config_path == Path(config_path)
        assert generator.config == {}
        assert generator.sheet_data is None

    def test_validate_config_missing_keys(self):
        """Test config validation with missing required keys."""
        generator = RaidAssignmentGenerator("test.toml")
        generator.config = {"raid_name": "MC"}  # Missing required keys

        with pytest.raises(ValueError, match="Missing required configuration key"):
            generator._validate_config()

    def test_validate_config_invalid_raid(self):
        """Test config validation with invalid raid name."""
        generator = RaidAssignmentGenerator("test.toml")
        generator.config = {
            "spreadsheet_url": "https://docs.google.com/spreadsheets/d/test/edit",
            "raid_name": "INVALID_RAID",
            "page_name": "Test Page"
        }

        with pytest.raises(ValueError, match="Unsupported raid name"):
            generator._validate_config()

    def test_validate_config_invalid_url(self):
        """Test config validation with invalid URL."""
        generator = RaidAssignmentGenerator("test.toml")
        generator.config = {
            "spreadsheet_url": "invalid_url",
            "raid_name": "MC",
            "page_name": "Test Page"
        }

        with pytest.raises(ValueError, match="Invalid spreadsheet URL format"):
            generator._validate_config()

    def test_validate_config_valid(self):
        """Test config validation with valid configuration."""
        generator = RaidAssignmentGenerator("test.toml")
        generator.config = {
            "spreadsheet_url": "https://docs.google.com/spreadsheets/d/test123/edit",
            "raid_name": "MC",
            "page_name": "MC Assignments"
        }

        # Should not raise any exception
        generator._validate_config()

    def test_convert_to_csv_url(self):
        """Test conversion of Google Sheets URL to CSV export URL."""
        generator = RaidAssignmentGenerator("test.toml")
        generator.config = {"page_name": "Test Page"}

        sheets_url = "https://docs.google.com/spreadsheets/d/1234567890abcdef/edit#gid=0"
        csv_url = generator._convert_to_csv_url(sheets_url)

        expected_url = "https://docs.google.com/spreadsheets/d/1234567890abcdef/export?format=csv&gid=0"
        assert csv_url == expected_url

    def test_convert_to_csv_url_invalid(self):
        """Test conversion with invalid URL."""
        generator = RaidAssignmentGenerator("test.toml")

        with pytest.raises(ValueError, match="URL must be a Google Sheets URL"):
            generator._convert_to_csv_url("https://example.com/invalid")

    def test_generate_assignments_no_data(self):
        """Test assignment generation without loaded data."""
        generator = RaidAssignmentGenerator("test.toml")
        generator.config = {"raid_name": "MC"}

        with pytest.raises(RuntimeError, match="Sheet data not loaded"):
            generator.generate_assignments()

    def test_save_to_file(self):
        """Test saving assignments to file."""
        generator = RaidAssignmentGenerator("test.toml")
        generator.config = {"raid_name": "MC"}

        test_assignments = "=== MC RAID ASSIGNMENTS ===\nTest assignment content"

        with tempfile.TemporaryDirectory() as temp_dir:
            output_path = os.path.join(temp_dir, "test_assignments.txt")
            result_path = generator.save_to_file(test_assignments, output_path)

            # Check file was created
            assert os.path.exists(output_path)
            assert result_path == str(Path(output_path).absolute())

            # Check file content
            with open(output_path, 'r', encoding='utf-8') as f:
                content = f.read()
            assert content == test_assignments


class TestConfigFileLoading:
    """Test cases for TOML configuration file loading."""

    def test_load_config_file_not_found(self):
        """Test loading non-existent config file."""
        generator = RaidAssignmentGenerator("nonexistent.toml")

        with pytest.raises(FileNotFoundError):
            generator.load_config()

    def test_load_config_valid_toml(self):
        """Test loading valid TOML configuration."""
        valid_config = """
        spreadsheet_url = "https://docs.google.com/spreadsheets/d/test123/edit"
        raid_name = "MC"
        page_name = "MC Assignments"
        """

        with tempfile.NamedTemporaryFile(mode='w', suffix='.toml', delete=False) as f:
            f.write(valid_config)
            f.flush()

            try:
                generator = RaidAssignmentGenerator(f.name)
                generator.load_config()

                assert generator.config["spreadsheet_url"] == "https://docs.google.com/spreadsheets/d/test123/edit"
                assert generator.config["raid_name"] == "MC"
                assert generator.config["page_name"] == "MC Assignments"

            finally:
                os.unlink(f.name)


def test_main_function_structure():
    """Test that main function exists and has expected structure."""
    from main import main

    # Function should exist and be callable
    assert callable(main)


if __name__ == "__main__":
    pytest.main([__file__])