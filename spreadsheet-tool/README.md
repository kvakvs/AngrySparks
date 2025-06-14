# World of Warcraft Raid Assignment Tool

A Python CLI tool that reads Google Sheets containing World of Warcraft raid assignments and generates formatted text files for easy distribution to guild members.

## Features

- Read assignments from publicly accessible Google Sheets
- Support for multiple Classic WoW raids: MC, BWL, AQ40, and Naxx
- Configurable via TOML files
- Generate formatted text files for easy copy/paste into Discord or other platforms
- Command-line interface for easy automation and weekly usage

## Installation

### Prerequisites

- Python 3.11 or higher
- Internet connection to access Google Sheets

### Setup

1. Clone or download this repository
2. Install dependencies:
   ```powershell
   pip install -r requirements.txt
   ```

## Configuration

1. Copy the example configuration file:
   ```powershell
   Copy-Item config.toml.example config.toml
   ```

2. Edit `config.toml` with your specific values:
   - `spreadsheet_url`: URL to your Google Sheets document (must be publicly accessible)
   - `raid_name`: One of `MC`, `BWL`, `AQ40`, or `Naxx`
   - `page_name`: Name of the specific sheet/tab in your spreadsheet

### Google Sheets Setup

1. Create a Google Sheets document with your raid assignments
2. Make sure the document is publicly accessible (anyone with the link can view)
3. Structure your data with appropriate columns (exact structure depends on your needs)
4. Copy the sharing URL to your configuration file

## Usage

### Basic Usage

Generate assignments using a configuration file:

```powershell
python main.py config.toml
```

### Advanced Usage

Specify a custom output file:

```powershell
python main.py --output "weekly_mc_assignments.txt" config.toml
```

Enable verbose output for debugging:

```powershell
python main.py --verbose config.toml
```

### Command Line Options

- `config_file`: Path to TOML configuration file (required)
- `--output`, `-o`: Custom output file path (optional)
- `--verbose`, `-v`: Enable verbose output (optional)

## Example Workflow

1. Update your Google Sheets with this week's assignments
2. Run the tool: `python main.py config.toml`
3. Copy the generated text file contents to Discord/forums
4. Distribute to guild members

## Supported Raids

- **MC**: Molten Core
- **BWL**: Blackwing Lair
- **AQ40**: Ahn'Qiraj 40
- **Naxx**: Naxxramas

## Output Format

The tool generates a text file with formatted assignments that includes:
- Raid name header
- Processed assignment data from your spreadsheet
- Clean formatting suitable for Discord/forum posting

## Troubleshooting

### Common Issues

1. **"Configuration file not found"**
   - Make sure you've created `config.toml` from the example file

2. **"Failed to fetch spreadsheet data"**
   - Verify your Google Sheets URL is correct
   - Ensure the spreadsheet is publicly accessible
   - Check your internet connection

3. **"Unsupported raid name"**
   - Make sure `raid_name` in your config is one of: MC, BWL, AQ40, Naxx

### Google Sheets Access

The spreadsheet must be publicly accessible. To set this up:

1. Open your Google Sheets document
2. Click "Share" in the top right
3. Change access to "Anyone with the link can view"
4. Copy the sharing link to your configuration file

## Development

### Running Tests

```powershell
pytest
```

### Code Formatting

```powershell
black main.py
```

### Type Checking

```powershell
mypy main.py
```

## License

This tool is provided as-is for guild use. Modify as needed for your specific requirements.

## Contributing

Feel free to submit issues or pull requests to improve the tool for the Classic WoW community.