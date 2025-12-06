#!/usr/bin/env python3
"""
X12 Master Processor

Unified processing script that:
1. Detects transaction type
2. Routes to appropriate validator
3. Converts to JSON
4. Saves to correct output location

Usage:
    python3 x12_process.py <input_file> [options]

Options:
    --skip-validation    Skip validation step (not recommended)
    --output-dir DIR     Override output directory
    --report             Generate detailed validation report

Author: Healthcare Data Processing System
Version: 2.0
"""

import sys
import argparse
import subprocess
from pathlib import Path
from datetime import datetime
from x12_config import get_config
from x12_transaction_detector import X12TransactionDetector, TransactionType


class X12Processor:
    """Unified X12 file processor"""
    
    def __init__(self):
        self.config = get_config()
        self.detector = X12TransactionDetector()
    
    def process_file(
        self, 
        input_file: str, 
        skip_validation: bool = False,
        output_dir: str = None,
        generate_report: bool = False
    ) -> bool:
        """
        Process an X12 file through detection, validation, and conversion
        
        Args:
            input_file: Path to input X12 file
            skip_validation: Skip validation step
            output_dir: Override default output directory
            generate_report: Generate detailed validation report
        
        Returns:
            True if processing succeeded, False otherwise
        """
        input_path = Path(input_file)
        
        if not input_path.exists():
            print(f"✗ Error: File not found: {input_file}")
            return False
        
        print("=" * 70)
        print(f"X12 FILE PROCESSOR")
        print("=" * 70)
        print(f"Input File: {input_path.name}")
        print(f"File Size:  {input_path.stat().st_size} bytes")
        print()
        
        # Step 1: Detect transaction type
        print("STEP 1: Transaction Type Detection")
        print("-" * 70)
        
        detection_result = self.detector.detect_file(str(input_path))
        
        print(f"Type:        {detection_result.transaction_type.value}")
        print(f"Description: {detection_result.description}")
        print(f"Confidence:  {detection_result.confidence}")
        print(f"Valid:       {'✓' if detection_result.is_valid else '✗'}")
        print()
        
        if not detection_result.is_valid:
            print("✗ Transaction detection failed - file may be malformed")
            return False
        
        # Step 2: Validate (if not skipped)
        if not skip_validation:
            print("STEP 2: Validation")
            print("-" * 70)
            
            validation_passed = self._validate_transaction(
                input_path, 
                detection_result.transaction_type,
                generate_report
            )
            
            if not validation_passed:
                print("✗ Validation failed - file contains errors")
                print("\nProcessing aborted. Fix errors before conversion.")
                return False
            
            print("✓ Validation passed")
            print()
        else:
            print("STEP 2: Validation (SKIPPED)")
            print("-" * 70)
            print("⚠ Warning: Validation skipped - processing unvalidated data")
            print()
        
        # Step 3: Convert to JSON
        print("STEP 3: JSON Conversion")
        print("-" * 70)
        
        output_file = self._get_output_path(input_path, output_dir)
        
        conversion_success = self._convert_to_json(
            input_path,
            output_file,
            detection_result.transaction_type
        )
        
        if not conversion_success:
            print("✗ Conversion failed")
            return False
        
        print(f"✓ Conversion complete")
        print(f"Output: {output_file}")
        print()
        
        # Summary
        print("=" * 70)
        print("PROCESSING COMPLETE")
        print("=" * 70)
        print(f"Input:  {input_path}")
        print(f"Output: {output_file}")
        print(f"Type:   {detection_result.transaction_type.value}")
        print("=" * 70)
        
        return True
    
    def _validate_transaction(
        self, 
        input_path: Path, 
        transaction_type: TransactionType,
        generate_report: bool
    ) -> bool:
        """Validate transaction based on type"""
        
        # Currently only 837P has full validation
        if transaction_type == TransactionType.T837P:
            validator_path = self.config.validator_path
            
            result = subprocess.run(
                ["python3", str(validator_path), str(input_path)],
                capture_output=True,
                text=True
            )
            
            if generate_report:
                self._save_validation_report(input_path, result.stdout)
            
            # Show validation summary
            if result.returncode == 0:
                print("  Status: VALID")
                # Extract summary from output
                if "Issue Summary" in result.stdout:
                    for line in result.stdout.split("\n"):
                        if "Errors:" in line or "Warnings:" in line:
                            print(f"  {line.strip()}")
            else:
                print("  Status: INVALID")
                # Show error summary
                lines = result.stdout.split("\n")
                for i, line in enumerate(lines):
                    if "Issue Summary" in line:
                        # Print next few lines
                        for j in range(i+1, min(i+5, len(lines))):
                            if lines[j].strip():
                                print(f"  {lines[j]}")
            
            return result.returncode == 0
        
        else:
            # Other transaction types don't have validators yet
            print(f"  No validator available for {transaction_type.value}")
            print("  Skipping validation (proceeding with detection only)")
            return True
    
    def _convert_to_json(
        self, 
        input_path: Path, 
        output_path: Path,
        transaction_type: TransactionType
    ) -> bool:
        """Convert X12 to JSON based on transaction type"""
        
        # Currently only 837P has conversion
        if transaction_type == TransactionType.T837P:
            converter_path = self.config.converter_path
            
            result = subprocess.run(
                ["python3", str(converter_path), str(input_path), str(output_path)],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                print(f"  Converted: {output_path.name}")
                return True
            else:
                print(f"  Error: {result.stderr}")
                return False
        
        else:
            print(f"  No converter available for {transaction_type.value}")
            print(f"  Converter needed: Coming in future release")
            return False
    
    def _get_output_path(self, input_path: Path, output_dir: str = None) -> Path:
        """Determine output file path"""
        
        if output_dir:
            output_directory = Path(output_dir)
        else:
            output_directory = self.config.output_json_dir
        
        # Ensure directory exists
        output_directory.mkdir(parents=True, exist_ok=True)
        
        # Create output filename
        output_filename = input_path.stem + ".json"
        return output_directory / output_filename
    
    def _save_validation_report(self, input_path: Path, report_content: str):
        """Save validation report to file"""
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        report_filename = f"{input_path.stem}_validation_{timestamp}.txt"
        report_path = self.config.get_output_report_file(report_filename)
        
        # Ensure directory exists
        report_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(report_path, 'w') as f:
            f.write(report_content)
        
        print(f"  Report saved: {report_path}")


def main():
    """Command-line interface"""
    
    parser = argparse.ArgumentParser(
        description='X12 Master Processor - Detect, Validate, and Convert X12 files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Process with validation
  python3 x12_process.py sample_837p_claim.x12
  
  # Process and generate validation report
  python3 x12_process.py sample_837p_claim.x12 --report
  
  # Process without validation (not recommended)
  python3 x12_process.py sample_837p_claim.x12 --skip-validation
  
  # Process with custom output directory
  python3 x12_process.py sample_837p_claim.x12 --output-dir /custom/path
  
  # Process file from data directory
  python3 x12_process.py ../../data/sample_837p_claim.x12
        """
    )
    
    parser.add_argument(
        'input_file',
        help='Path to X12 input file'
    )
    
    parser.add_argument(
        '--skip-validation',
        action='store_true',
        help='Skip validation step (not recommended)'
    )
    
    parser.add_argument(
        '--output-dir',
        help='Override default output directory'
    )
    
    parser.add_argument(
        '--report',
        action='store_true',
        help='Generate detailed validation report file'
    )
    
    args = parser.parse_args()
    
    # Process the file
    processor = X12Processor()
    success = processor.process_file(
        args.input_file,
        skip_validation=args.skip_validation,
        output_dir=args.output_dir,
        generate_report=args.report
    )
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
