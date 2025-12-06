# X12 837P EDI Validator

## Overview

This Python script provides comprehensive validation for X12 837P (Professional Claims) EDI files. It checks for structural integrity, syntactical correctness, and business rule compliance to help distinguish valid healthcare data from defective or malformed submissions.

## Features

### Validation Layers

1. **Structural Validation**
   - Segment format and identifiers
   - Delimiter usage (segment terminator, element separator, sub-element separator)
   - Minimum element requirements
   - Valid segment types for 837P transactions

2. **Envelope Validation**
   - ISA/IEA (Interchange) envelope matching
   - GS/GE (Functional Group) envelope matching
   - ST/SE (Transaction Set) envelope matching
   - Control number verification
   - Segment count validation

3. **Syntactical Validation**
   - Data type checking (numeric, alphanumeric)
   - Length constraints
   - Code set validation (entity types, relationship codes, etc.)
   - Date format validation (CCYYMMDD)
   - Cardinality requirements

4. **Business Rule Validation**
   - Required segment presence (Billing Provider, Subscriber, Claim)
   - Financial totals (claim amount vs. service line totals)
   - Entity relationships
   - Date logic (valid date ranges)

## Usage

### Command Line

```bash
python x12_validator.py <path_to_x12_file>
```

### Example

```bash
# Validate a valid claim file
python x12_validator.py sample_837p_claim.x12

# Validate a malformed file
python x12_validator.py malformed_837p.x12
```

## Output

The validator provides a detailed report including:

- **Overall Status**: Valid or Invalid
- **Issue Summary**: Count of Errors, Warnings, and Info messages
- **Detailed Issues**: Organized by severity level with:
  - Segment ID and number
  - Element position (if applicable)
  - Clear error message
  - Contextual information

### Severity Levels

- **ERROR**: Fatal issues that prevent processing or will cause payer rejection
- **WARNING**: Issues that may cause rejection or processing problems
- **INFO**: Informational notices about the data

## Exit Codes

- `0`: File is valid (may have warnings or info messages)
- `1`: File is invalid (has one or more errors)

## Sample Files Included

### sample_837p_claim.x12
A valid 837P claim demonstrating proper structure with:
- Complete envelope structure (ISA/GS/ST)
- Billing provider information
- Subscriber/patient data
- Claim details with two service lines
- Proper control numbers and segment counts

### malformed_837p.x12
An intentionally malformed file demonstrating various errors:
- Mismatched control numbers
- Invalid entity type qualifier
- Non-numeric claim amount
- Invalid date (month 13, day 32)
- Empty diagnosis code
- Negative service line charge
- Zero service units
- Missing required subscriber segment

## Integration with Your System

This validator can be integrated into your healthcare data processing pipeline in several ways:

1. **Pre-processing Validation**: Run before conversion to JSON
2. **Quality Control**: Batch validation of incoming files
3. **Error Reporting**: Generate detailed reports for data quality teams
4. **Automated Workflows**: Use exit codes to route valid/invalid files

### Integration Example (Python)

```python
from x12_validator import X12Validator

validator = X12Validator()
result = validator.validate_file("incoming_claim.x12")

if result.is_valid:
    # Proceed with conversion to JSON
    convert_to_json(file_path)
else:
    # Log errors and reject file
    for issue in result.issues:
        if issue.level == ValidationLevel.ERROR:
            log_error(issue)
```

### Integration with Elixir

You can call the Python validator from Elixir using ports or System.cmd:

```elixir
defmodule X12.Validator do
  def validate_file(file_path) do
    case System.cmd("python3", ["x12_validator.py", file_path]) do
      {_output, 0} -> {:ok, "File is valid"}
      {output, 1} -> {:error, "Validation failed: #{output}"}
    end
  end
end
```

## Extending the Validator

The validator is designed to be extensible:

### Adding New Segment Validations

Add a new method in the `X12Validator` class:

```python
def _validate_custom_segment(self, segment: List[str], idx: int):
    """Validate CUSTOM segment"""
    # Your validation logic here
    pass
```

Then call it from `_validate_segments()`:

```python
elif segment_id == 'CUSTOM':
    self._validate_custom_segment(segment, idx)
```

### Adding Code Sets

Update the class-level dictionaries:

```python
NEW_CODE_SET = {
    'A': 'Description A',
    'B': 'Description B',
}
```

### Custom Business Rules

Add logic to `_validate_business_rules()` method for complex multi-segment validations.

## Technical Details

### Delimiter Parsing

The validator automatically detects delimiters from the ISA segment:
- Element separator: Position 3 (typically `*`)
- Sub-element separator: Position 104 (typically `:`)
- Segment terminator: End of ISA segment (typically `~`)

### Performance

- Fast parsing using string splitting
- Single-pass validation for most checks
- Minimal memory footprint
- Suitable for batch processing

### Dependencies

None! This is a standalone Python script with no external dependencies, using only Python standard library modules.

## Requirements

- Python 3.6 or higher
- No external packages required

## Validation Coverage

### Currently Validated Segments

- ISA, IEA (Interchange envelopes)
- GS, GE (Functional group envelopes)
- ST, SE (Transaction set envelopes)
- BHT (Beginning of Hierarchical Transaction)
- NM1 (Entity Name)
- CLM (Claim Information)
- DTP (Date or Time Period)
- HI (Health Care Diagnosis Code)
- SV1 (Professional Service)
- REF (Reference Information)
- HL (Hierarchical Level)

### Business Rules Validated

- Required entity presence (Billing Provider, Subscriber)
- Claim financial totals vs. service line totals
- Control number matching across envelopes
- Segment count accuracy
- Date validity and logic
- Code set compliance

## Known Limitations

1. The validator focuses on 837P (Professional Claims). Other transaction types (837I for Institutional, 835 for Remittance Advice) would require separate validation rules.

2. Code set validation is based on common values but is not exhaustive. Full HIPAA compliance would require complete code set validation against official implementation guides.

3. The validator does not check payer-specific requirements, which may vary by insurance company.

4. Advanced situational requirements (some elements required only in specific contexts) are partially implemented.

## Future Enhancements

Potential additions for production use:

- [ ] Configurable validation rules via JSON/YAML
- [ ] Support for 837I (Institutional) and 835 (Remittance) transactions
- [ ] Payer-specific validation profiles
- [ ] JSON output format for machine parsing
- [ ] Performance metrics (validation time, file size)
- [ ] Batch processing mode
- [ ] Integration with clearinghouse validation services
- [ ] Detailed HIPAA compliance checking

## License

This validator is part of the Healthcare Data Processing System project.

## Support

For issues or questions about integrating this validator into your workflow, please refer to the main project documentation.

---

**Generated**: 2025-11-27  
**Version**: 1.0  
**Python Version**: 3.6+
