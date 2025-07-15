import requests
import pandas as pd
import hashlib
import time
import json
from pathlib import Path
from typing import Optional


class GoogleWebClient:
    CACHE_DIR = Path(".cache")
    CACHE_LIFETIME = 3600  # 1 hour in seconds

    def __init__(self):
        self.config = {}
        self._ensure_cache_dir()

    def set_config(self, config: dict) -> None:
        self.config = config

    def _ensure_cache_dir(self) -> None:
        """Ensure cache directory exists."""
        self.CACHE_DIR.mkdir(exist_ok=True)

    def _get_cache_key(self, url: str) -> str:
        """Generate a cache key for the given URL."""
        return hashlib.md5(url.encode()).hexdigest()

    def _get_cache_path(self, cache_key: str) -> Path:
        """Get the cache file path for the given cache key."""
        return self.CACHE_DIR / f"{cache_key}.json"

    def _is_cache_valid(self, cache_path: Path) -> bool:
        """Check if cache file exists and is within the cache lifetime."""
        if not cache_path.exists():
            return False

        file_age = time.time() - cache_path.stat().st_mtime
        return file_age < self.CACHE_LIFETIME

    def _load_from_cache(self, cache_path: Path) -> Optional[str]:
        """Load cached data from file."""
        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                cache_data = json.load(f)
                return cache_data.get('content')
        except (FileNotFoundError, json.JSONDecodeError):
            return None

    def _save_to_cache(self, cache_path: Path, content: str) -> None:
        """Save data to cache file."""
        try:
            cache_data = {
                'content': content,
                'timestamp': time.time(),
                'url': getattr(self, '_current_url', 'unknown')
            }
            with open(cache_path, 'w', encoding='utf-8') as f:
                json.dump(cache_data, f)
        except IOError as e:
            print(f"Warning: Failed to save to cache: {e}")

    def fetch_sheet_data(self) -> pd.DataFrame:
        """Fetch data from Google Sheets with caching."""
        try:
            # Convert Google Sheets URL to CSV export format
            sheet_url = self._convert_to_csv_url(url=self.config["spreadsheet_url"],
                                                 sheet=self.config["sheet"])
            print("Requesting sheet data from: ", sheet_url)

            # Store current URL for cache metadata
            self._current_url = sheet_url

            # Check cache first
            cache_key = self._get_cache_key(sheet_url)
            cache_path = self._get_cache_path(cache_key)

            if self._is_cache_valid(cache_path):
                print("Loading data from cache...")
                cached_content = self._load_from_cache(cache_path)
                if cached_content:
                    from io import StringIO
                    sheet_data = pd.read_csv(StringIO(cached_content))
                    print(f"Successfully loaded {len(sheet_data)} rows from cache")
                    return sheet_data

            # Fetch fresh data if cache miss or invalid
            print("Fetching fresh data from Google Sheets...")
            response = requests.get(sheet_url, timeout=30)
            response.raise_for_status()

            # Save to cache
            self._save_to_cache(cache_path, response.text)

            # Parse as CSV
            from io import StringIO
            sheet_data = pd.read_csv(StringIO(response.text))

            print(f"Successfully loaded {len(sheet_data)} rows from spreadsheet")
            return sheet_data

        except requests.RequestException as e:
            raise RuntimeError(f"Failed to fetch spreadsheet data: {e}")
        except pd.errors.EmptyDataError:
            raise RuntimeError("Spreadsheet appears to be empty")
        except Exception as e:
            raise RuntimeError(f"Error processing spreadsheet data: {e}")

    def _convert_to_csv_url(self, url: str, sheet: str) -> str:
        """Convert Google Sheets URL to CSV export URL."""
        # Extract sheet ID from the URL
        # Example: https://docs.google.com/spreadsheets/d/SHEET_ID/edit#gid=0
        if "docs.google.com/spreadsheets" not in url:
            raise ValueError("URL must be a Google Sheets URL")

        try:
            # Extract sheet ID
            parts = url.split("/")
            sheet_id = parts[parts.index("d") + 1]

            # Construct CSV export URL
            csv_url = f"https://docs.google.com/spreadsheets/d/{sheet_id}/export?format=csv"

            # Add specific sheet/page if needed
            if sheet:
                csv_url += f"&gid={sheet}"  # This would need proper GID handling

            return csv_url

        except (ValueError, IndexError):
            raise ValueError("Could not extract sheet ID from URL")
