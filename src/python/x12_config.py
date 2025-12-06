#!/usr/bin/env python3
"""
X12 Project Configuration

Central configuration for all X12 processing tools.
Manages paths for data, output, and source directories.

Project Structure:
    X12_to_JSON_translator/
    ├── data/              # Input X12 files
    ├── output/            # Processed results
    │   ├── json/          # Converted JSON files
    │   ├── reports/       # Validation reports
    │   └── logs/          # Processing logs
    ├── src/               # Source code
    │   ├── python/        # Python tools
    │   └── elixir_project/ # Elixir processors
    └── docs/              # Documentation

Author: Healthcare Data Processing System
Version: 2.0
"""

import os
from pathlib import Path
from typing import Optional


class X12Config:
    """Configuration manager for X12 processing system"""
    
    def __init__(self):
        # Determine project root (2 levels up from this file in src/python/)
        self._script_dir = Path(__file__).resolve().parent
        self._project_root = self._script_dir.parent.parent
        
        # Directory paths
        self._data_dir = self._project_root / "data"
        self._output_dir = self._project_root / "output"
        self._src_dir = self._project_root / "src"
        self._docs_dir = self._project_root / "docs"
        
        # Sub-directories
        self._output_json_dir = self._output_dir / "json"
        self._output_reports_dir = self._output_dir / "reports"
        self._output_logs_dir = self._output_dir / "logs"
        
        self._src_python_dir = self._src_dir / "python"
        self._src_elixir_dir = self._src_dir / "elixir"
        
        # Tool paths
        self._validator_path = self._src_python_dir / "x12_validator.py"
        self._detector_path = self._src_python_dir / "x12_transaction_detector.py"
        self._converter_path = self._src_python_dir / "X12_837p_to_json_semantic.py"
        
    @property
    def project_root(self) -> Path:
        """Project root directory"""
        return self._project_root
    
    @property
    def data_dir(self) -> Path:
        """Input data directory"""
        return self._data_dir
    
    @property
    def output_dir(self) -> Path:
        """Output directory (base)"""
        return self._output_dir
    
    @property
    def output_json_dir(self) -> Path:
        """JSON output directory"""
        return self._output_json_dir
    
    @property
    def output_reports_dir(self) -> Path:
        """Validation reports directory"""
        return self._output_reports_dir
    
    @property
    def output_logs_dir(self) -> Path:
        """Processing logs directory"""
        return self._output_logs_dir
    
    @property
    def src_dir(self) -> Path:
        """Source code directory"""
        return self._src_dir
    
    @property
    def src_python_dir(self) -> Path:
        """Python source directory"""
        return self._src_python_dir
    
    @property
    def src_elixir_dir(self) -> Path:
        """Elixir source directory"""
        return self._src_elixir_dir
    
    @property
    def docs_dir(self) -> Path:
        """Documentation directory"""
        return self._docs_dir
    
    @property
    def validator_path(self) -> Path:
        """Path to x12_validator.py"""
        return self._validator_path
    
    @property
    def detector_path(self) -> Path:
        """Path to x12_transaction_detector.py"""
        return self._detector_path
    
    @property
    def converter_path(self) -> Path:
        """Path to X12_837p_to_json_semantic.py"""
        return self._converter_path
    
    def get_data_file(self, filename: str) -> Path:
        """Get full path to a data file"""
        return self._data_dir / filename
    
    def get_output_json_file(self, filename: str) -> Path:
        """Get full path to a JSON output file"""
        return self._output_json_dir / filename
    
    def get_output_report_file(self, filename: str) -> Path:
        """Get full path to a report file"""
        return self._output_reports_dir / filename
    
    def get_output_log_file(self, filename: str) -> Path:
        """Get full path to a log file"""
        return self._output_logs_dir / filename
    
    def ensure_directories(self):
        """Create all necessary directories if they don't exist"""
        dirs = [
            self._data_dir,
            self._output_dir,
            self._output_json_dir,
            self._output_reports_dir,
            self._output_logs_dir,
        ]
        for directory in dirs:
            directory.mkdir(parents=True, exist_ok=True)
    
    def validate_setup(self) -> tuple[bool, list[str]]:
        """
        Validate that project structure is correct
        
        Returns:
            (is_valid, list_of_issues)
        """
        issues = []
        
        # Check directories exist
        if not self._project_root.exists():
            issues.append(f"Project root not found: {self._project_root}")
        if not self._data_dir.exists():
            issues.append(f"Data directory not found: {self._data_dir}")
        if not self._src_python_dir.exists():
            issues.append(f"Python source directory not found: {self._src_python_dir}")
        
        # Check tool files exist
        if not self._validator_path.exists():
            issues.append(f"Validator not found: {self._validator_path}")
        if not self._detector_path.exists():
            issues.append(f"Detector not found: {self._detector_path}")
        if not self._converter_path.exists():
            issues.append(f"Converter not found: {self._converter_path}")
        
        return (len(issues) == 0, issues)
    
    def print_config(self):
        """Print current configuration"""
        print("=" * 70)
        print("X12 Project Configuration")
        print("=" * 70)
        print(f"Project Root:     {self._project_root}")
        print(f"Data Directory:   {self._data_dir}")
        print(f"Output Directory: {self._output_dir}")
        print(f"  - JSON:         {self._output_json_dir}")
        print(f"  - Reports:      {self._output_reports_dir}")
        print(f"  - Logs:         {self._output_logs_dir}")
        print(f"Source Directory: {self._src_dir}")
        print(f"  - Python:       {self._src_python_dir}")
        print(f"  - Elixir:       {self._src_elixir_dir}")
        print(f"Docs Directory:   {self._docs_dir}")
        print()
        print("Tools:")
        print(f"  - Validator:    {self._validator_path}")
        print(f"  - Detector:     {self._detector_path}")
        print(f"  - Converter:    {self._converter_path}")
        print("=" * 70)


# Singleton instance
_config = None

def get_config() -> X12Config:
    """Get the global configuration instance"""
    global _config
    if _config is None:
        _config = X12Config()
    return _config


def main():
    """Command-line interface for config management"""
    import sys
    
    config = get_config()
    
    if len(sys.argv) > 1:
        command = sys.argv[1]
        
        if command == "validate":
            is_valid, issues = config.validate_setup()
            if is_valid:
                print("✓ Project structure is valid")
                config.print_config()
                sys.exit(0)
            else:
                print("✗ Project structure validation failed:")
                for issue in issues:
                    print(f"  - {issue}")
                sys.exit(1)
        
        elif command == "setup":
            print("Creating necessary directories...")
            config.ensure_directories()
            print("✓ Directories created")
            config.print_config()
            sys.exit(0)
        
        elif command == "show":
            config.print_config()
            sys.exit(0)
        
        else:
            print(f"Unknown command: {command}")
            print("Available commands: validate, setup, show")
            sys.exit(1)
    else:
        config.print_config()


if __name__ == "__main__":
    main()
