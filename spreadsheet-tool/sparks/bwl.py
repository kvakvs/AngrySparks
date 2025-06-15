from typing import List
import pandas as pd

def process_bwl_assignments(sheet_data: pd.DataFrame) -> List[str]:
    assignments = []

    def get_cell_value(sheet_data: pd.DataFrame, col_letter: str, row_num: int) -> str:
        """Convert Excel-style cell reference to DataFrame index and get value."""
        # Convert column letter to index (A=0, B=1, ..., Z=25)
        col_idx = ord(col_letter.upper()) - ord('A')
        row_idx = row_num - 1  # Convert to 0-based indexing

        try:
            if row_idx < len(sheet_data) and col_idx < len(sheet_data.columns):
                value = sheet_data.iloc[row_idx, col_idx]
                return str(value).strip() if pd.notna(value) else ""
            return ""
        except (IndexError, KeyError):
            return ""

    def get_cell_range(sheet_data: pd.DataFrame, col_letter: str, start_row: int, end_row: int) -> List[str]:
        """Get values from a range of cells in the same column."""
        values = []
        for row in range(start_row, end_row + 1):
            value = get_cell_value(sheet_data, col_letter, row)
            if value:  # Only add non-empty values
                values.append(value)
        return values

    # Group 1 - General assignments for trash
    # Cells E6-E10 contain list of tanks, cells N6-N10 contain list of healers for those tanks
    # Cell G13 contains name of puller hunter
    # Cells E17-E19 contain healers-resurrectors for trash
    # Cells N13-N15 contain healers for melee, cells N16-N18 contain healers for ranged, N19 contains flex
    assignments.append("# BWL") # Header level 1 will create a category in AngrySparks
    assignments.append("## Trash")

    # Extract tanks from E6-E10
    tanks = get_cell_range(sheet_data, 'E', 6, 10)
    # Extract healers for tanks from N6-N10
    tank_healers = get_cell_range(sheet_data, 'N', 6, 10)

    if tanks:
        assignments.append("TANK ASSIGNMENTS:")
        for i, tank in enumerate(tanks):
            healer = tank_healers[i] if i < len(tank_healers) else "No healer assigned"
            assignments.append(f"  Tank {i+1}: {tank} -> Healer: {healer}")
        assignments.append("")

    # Extract puller hunter from G13
    puller = get_cell_value(sheet_data, 'G', 13)
    if puller:
        assignments.append(f"PULLER: {puller}")
        assignments.append("")

    # Extract healers-resurrectors for trash from E17-E19
    trash_healers = get_cell_range(sheet_data, 'E', 17, 19)
    if trash_healers:
        assignments.append("TRASH HEALERS/RESURRECTORS:")
        for i, healer in enumerate(trash_healers):
            assignments.append(f"  {i+1}. {healer}")
        assignments.append("")

    # Extract melee healers from N13-N15
    melee_healers = get_cell_range(sheet_data, 'N', 13, 15)
    if melee_healers:
        assignments.append("MELEE HEALERS:")
        for i, healer in enumerate(melee_healers):
            assignments.append(f"  {i+1}. {healer}")
        assignments.append("")

    # Extract ranged healers from N16-N18
    ranged_healers = get_cell_range(sheet_data, 'N', 16, 18)
    if ranged_healers:
        assignments.append("RANGED HEALERS:")
        for i, healer in enumerate(ranged_healers):
            assignments.append(f"  {i+1}. {healer}")
        assignments.append("")

    # Extract flex healer from N19
    flex_healer = get_cell_value(sheet_data, 'N', 19)
    if flex_healer:
        assignments.append(f"FLEX HEALER: {flex_healer}")
        assignments.append("")

    return assignments