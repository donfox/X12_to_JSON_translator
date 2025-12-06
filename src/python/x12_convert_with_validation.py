#!/usr/bin/env python3
"""
X12 837P Converter with Validation
Validates X12 file before conversion to prevent processing malformed data
"""

import sys
import subprocess
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    # Get the directory where this script is located
    script_dir = Path(__file__).parent

    # Step 1: Validate the file
    print(f"Step 1: Validating {input_file}...")
    validator_path = script_dir / "x12_validator.py"

    result = subprocess.run(
        ["python3", str(validator_path), input_file],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print("\n" + "=" * 80)
        print("VALIDATION FAILED - File contains errors")
        print("=" * 80)
        print("\nThe X12 file has validation errors and should not be converted.")
        print("Please fix the errors before conversion.\n")
        print("Validation output:")
        print(result.stdout)
        sys.exit(1)

    print("✓ Validation passed\n")

    # Step 2: Convert the file
    print(f"Step 2: Converting {input_file} to JSON...")
    converter_path = script_dir / "X12_837p_to_json_semantic.py"

    converter_args = ["python3", str(converter_path), input_file]
    if output_file:
        converter_args.append(output_file)

    result = subprocess.run(converter_args)
    sys.exit(result.returncode)


def print_usage():
    print("""
X12 837P Converter with Validation

This script validates the X12 file before conversion to ensure data quality.

Usage: python3 x12_convert_with_validation.py <input_file.x12> [output_file.json]

Examples:
  python3 x12_convert_with_validation.py sample_837p_claim.x12
  python3 x12_convert_with_validation.py sample_837p_claim.x12 output.json

The script will:
1. Validate the X12 file for errors
2. Only convert if validation passes
3. Prevent processing of malformed data

To skip validation (not recommended):
  python3 X12_837p_to_json_semantic.py <input_file.x12> [output_file.json]
    """)


if __name__ == "__main__":
    main()
