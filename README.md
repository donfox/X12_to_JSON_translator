# X12 to JSON Translator

Healthcare EDI X12 837P (Professional Claims) to JSON converter with comprehensive validation, implemented in both Python and Elixir.

## Overview

This project provides tools to:
1. **Validate** X12 837P EDI files for structural, syntactical, and business rule compliance
2. **Convert** valid X12 files to semantic JSON format
3. **Distinguish** between valid healthcare data and malformed submissions

## Quick Start

### Recommended Workflow

**Always validate before converting** to ensure data quality:

#### Python
```bash
# Validate and convert in one step (recommended)
python3 python/x12_convert_with_validation.py data/sample_837p_claim.x12 output.json

# Or validate separately
python3 python/x12_validator.py data/sample_837p_claim.x12
python3 python/X12_837p_to_json_semantic.py data/sample_837p_claim.x12 output.json
```

#### Elixir
```bash
cd elixir_project

# Validate and convert in one step (recommended)
elixir x12_convert_with_validation.exs ../data/sample_837p_claim.x12 output.json

# Or validate separately
elixir x12_validator.exs ../data/sample_837p_claim.x12
elixir X12_837p_to_json_semantic.exs ../data/sample_837p_claim.x12 output.json
```

## Why Validation Matters

The **converter is lenient by design** - it will process malformed data and use safe defaults (e.g., converting invalid numbers to 0.0). This can lead to:

- ❌ Silent data corruption
- ❌ Invalid claims being submitted
- ❌ Payer rejections
- ❌ Lost revenue

The **validator catches these issues before conversion**:

```bash
$ python3 python/x12_convert_with_validation.py data/malformed_837p.x12

Step 1: Validating data/malformed_837p.x12...

VALIDATION FAILED - File contains errors
The X12 file has validation errors and should not be converted.

ERRORS (9):
  - Control number mismatches
  - Invalid entity type qualifier
  - Non-numeric claim amount
  - Invalid dates
  - Empty diagnosis codes
  - Missing required segments
```

## Project Structure

```
.
├── python/
│   ├── X12_837p_to_json_semantic.py    # Converter (lenient)
│   ├── x12_validator.py                # Validator (strict)
│   └── x12_convert_with_validation.py  # Wrapper (recommended)
│
├── elixir_project/
│   ├── lib/x12_to_json/               # Library modules
│   │   ├── parser.ex
│   │   ├── transformer.ex
│   │   ├── converter.ex
│   │   └── helpers.ex
│   ├── X12_837p_to_json_semantic.exs  # Converter script
│   ├── x12_validator.exs              # Validator script
│   └── x12_convert_with_validation.exs # Wrapper (recommended)
│
├── data/
│   ├── sample_837p_claim.x12          # Valid test file
│   ├── malformed_837p.x12             # Invalid test file
│   └── output/                        # Generated JSON files
│
└── documents/
    ├── README.md                       # Validator documentation
    └── x12_to_json_conversion_spec.md # Conversion specification
```

## Features

### Validation (Strict)

The validators perform comprehensive checks:

- **Structural Validation**
  - Segment format and identifiers
  - Delimiter usage
  - Minimum element requirements
  - Valid segment types for 837P

- **Envelope Validation**
  - ISA/IEA, GS/GE, ST/SE matching
  - Control number verification
  - Segment count validation

- **Syntactical Validation**
  - Data type checking
  - Length constraints
  - Code set validation
  - Date format validation

- **Business Rule Validation**
  - Required segment presence
  - Financial totals verification
  - Entity relationships
  - Date logic

### Conversion (Lenient)

The converters extract data into semantic JSON:

- Hierarchical structure (Interchange → Group → Transaction)
- Provider and subscriber information
- Claim and service line details
- Diagnosis codes
- Financial information

**⚠️ Warning**: Converters use safe defaults for invalid data. Always validate first!

## Requirements

### Python
- Python 3.6+
- No external dependencies (uses standard library only)

### Elixir
- Elixir 1.14+
- Jason library (for JSON encoding)

## Installation

### Python
```bash
# No installation needed - scripts are standalone
python3 python/x12_validator.py --help
```

### Elixir
```bash
cd elixir_project
mix deps.get
mix compile
```

## Usage Examples

### Validate a File

**Python:**
```bash
python3 python/x12_validator.py data/sample_837p_claim.x12
# Exit code 0 = valid, 1 = invalid
```

**Elixir:**
```bash
elixir elixir_project/x12_validator.exs data/sample_837p_claim.x12
# Exit code 0 = valid, 1 = invalid
```

### Convert to JSON (After Validation)

**Python:**
```bash
# Print to stdout
python3 python/X12_837p_to_json_semantic.py data/sample_837p_claim.x12

# Save to file
python3 python/X12_837p_to_json_semantic.py data/sample_837p_claim.x12 output.json
```

**Elixir:**
```bash
cd elixir_project

# Print to stdout
elixir X12_837p_to_json_semantic.exs ../data/sample_837p_claim.x12

# Save to file
elixir X12_837p_to_json_semantic.exs ../data/sample_837p_claim.x12 output.json
```

### Recommended: Validate + Convert

**Python:**
```bash
python3 python/x12_convert_with_validation.py data/sample_837p_claim.x12 output.json
```

**Elixir:**
```bash
cd elixir_project
elixir x12_convert_with_validation.exs ../data/sample_837p_claim.x12 output.json
```

## Testing

Sample test files are provided:

```bash
# Test with valid file
python3 python/x12_validator.py data/sample_837p_claim.x12
# Should show: Overall Status: ✓ VALID

# Test with malformed file
python3 python/x12_validator.py data/malformed_837p.x12
# Should show: Overall Status: ✗ INVALID with 9 errors
```

## Integration

### As a Pre-processing Step

```python
# Python
from x12_validator import X12Validator

validator = X12Validator()
result = validator.validate_file("incoming_claim.x12")

if result.is_valid:
    convert_to_json(file_path)
else:
    log_errors_and_reject(result.issues)
```

### In a Pipeline

```bash
#!/bin/bash
# Process all X12 files in a directory

for file in inbox/*.x12; do
    if python3 python/x12_validator.py "$file" > /dev/null 2>&1; then
        python3 python/X12_837p_to_json_semantic.py "$file" "processed/$(basename "$file" .x12).json"
        mv "$file" "processed/"
    else
        mv "$file" "errors/"
    fi
done
```

## Code Quality Improvements

Recent improvements include:

- ✅ Eliminated bare exception handlers
- ✅ Added comprehensive type hints (Python)
- ✅ Replaced magic numbers with named constants
- ✅ Better guard clauses for edge cases (Elixir)
- ✅ Refactored complex methods
- ✅ Added validation wrapper scripts
- ✅ Improved error handling and logging

## Performance

- **Python**: Fast, single-pass validation
- **Elixir**: Functional, immutable approach
- Both suitable for batch processing
- Consider streaming for very large files (>100MB)

## Limitations

1. Focuses on 837P (Professional Claims) only
2. Code sets are common values, not exhaustive
3. Does not check payer-specific requirements
4. No support for 837I (Institutional) or 835 (Remittance)

## Future Enhancements

- [ ] Configuration file for validation rules
- [ ] Support for 837I and 835 transactions
- [ ] Payer-specific validation profiles
- [ ] JSON output for validation results
- [ ] Performance benchmarks
- [ ] Batch processing mode
- [ ] Test suite

## Documentation

- [Validator Documentation](documents/README.md) - Detailed validator features
- [Conversion Specification](documents/x12_to_json_conversion_spec.md) - JSON schema
- [Elixir Validator](documents/ELIXIR_VALIDATOR_README.md) - Elixir-specific docs

## License

Healthcare Data Processing System project.

## Support

For issues or questions, please refer to the project documentation.

---

**Last Updated**: 2025-11-28
**Version**: 1.1
**Python Version**: 3.6+
**Elixir Version**: 1.14+
