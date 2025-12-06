# X12 Healthcare Transaction Processing System
## Updated with Centralized Configuration

## 📁 Project Structure

```
X12_to_JSON_translator/
├── data/                          # Input X12 files
│   ├── sample_837p_claim.x12      # Professional claim samples
│   ├── sample_837i_claim.x12      # Institutional claim
│   ├── sample_835_payment.x12     # Payment/remittance
│   ├── sample_270_eligibility.x12 # Eligibility inquiry
│   ├── sample_271_eligibility_response.x12
│   ├── sample_276_claim_status.x12
│   ├── sample_277_claim_status_response.x12
│   ├── sample_278_auth_request.x12
│   ├── sample_999_acknowledgment.x12
│   └── malformed_837p_claim.x12   # Test file with errors
│
├── output/                        # Processed results
│   ├── json/                      # Converted JSON files
│   ├── reports/                   # Validation reports
│   └── logs/                      # Processing logs
│
├── src/                           # Source code
│   ├── python/                    # Python tools
│   │   ├── x12_config.py          # ⭐ Central configuration
│   │   ├── x12_process.py         # ⭐ Master processor
│   │   ├── x12_transaction_detector.py  # Type detection
│   │   ├── x12_validator.py       # 837P validation
│   │   ├── X12_837p_to_json_semantic.py # JSON conversion
│   │   ├── test_suite.sh          # ⭐ Test suite
│   │   └── batch_process.sh       # ⭐ Batch processor
│   │
│   └── elixir/            # Elixir processors
│       ├── lib/                   # Elixir modules
│       ├── mix.exs                # Mix configuration
│       └── x12_validator.exs      # Elixir validator
│
└── docs/                          # Documentation
    ├── INDEX.md                   # Package overview
    ├── README_MULTI_TRANSACTION.md  # Complete guide
    ├── QUICK_REFERENCE.md         # Cheat sheet
    ├── VISUAL_OVERVIEW.md         # Architecture diagrams
    └── PROJECT_SUMMARY.md         # Summary
```

## 🚀 Quick Start

### 1. Verify Setup

```bash
cd src/python
python3 x12_config.py validate
```

Expected output:
```
✓ Project structure is valid
```

### 2. Run Test Suite

```bash
cd src/python
./test_suite.sh
```

Expected result: **All 15 tests passing**

### 3. Process a Single File

```bash
cd src/python

# Basic processing (with validation)
python3 x12_process.py ../../data/sample_837p_claim.x12

# With detailed validation report
python3 x12_process.py ../../data/sample_837p_claim.x12 --report

# Skip validation (not recommended)
python3 x12_process.py ../../data/sample_837p_claim.x12 --skip-validation
```

### 4. Batch Process All Files

```bash
cd src/python

# Process all files in data/ directory
./batch_process.sh

# With validation reports
./batch_process.sh --report
```

## 🔧 New Features in This Version

### 1. Centralized Configuration (`x12_config.py`)

All path management in one place. Tools automatically find files in correct locations.

```python
from x12_config import get_config

config = get_config()

# Get paths
input_file = config.get_data_file("sample.x12")
output_file = config.get_output_json_file("sample.json")
report_file = config.get_output_report_file("report.txt")

# Validate structure
is_valid, issues = config.validate_setup()
```

**Command-line usage:**
```bash
python3 x12_config.py validate  # Check structure
python3 x12_config.py setup     # Create directories
python3 x12_config.py show      # Display paths
```

### 2. Master Processor (`x12_process.py`)

Unified workflow: detect → validate → convert

```bash
# Full processing with validation
python3 x12_process.py <input_file>

# Options
--skip-validation    # Skip validation (not recommended)
--output-dir DIR     # Custom output directory
--report             # Generate detailed validation report
```

**Processing steps:**
1. **Detection**: Identifies transaction type (837P, 835, 270, etc.)
2. **Validation**: Validates structure and business rules
3. **Conversion**: Converts to JSON (837P only currently)
4. **Output**: Saves to `output/json/` directory

### 3. Test Suite (`test_suite.sh`)

Comprehensive testing of all components:
- ✅ Configuration validation
- ✅ Directory structure
- ✅ Transaction type detection (9 types)
- ✅ 837P validation
- ✅ Master processor workflow
- ✅ JSON output creation

### 4. Batch Processing (`batch_process.sh`)

Process multiple files at once:
```bash
./batch_process.sh              # Process all files
./batch_process.sh --report     # With validation reports
```

## 📝 Usage Examples

### Example 1: Single File Processing

```bash
cd src/python

# Process with validation
python3 x12_process.py ../../data/sample_837p_claim.x12
```

Output:
```
======================================================================
X12 FILE PROCESSOR
======================================================================
Input File: sample_837p_claim.x12
File Size:  874 bytes

STEP 1: Transaction Type Detection
----------------------------------------------------------------------
Type:        837P
Description: 837P - Professional Health Care Claim
Confidence:  HIGH
Valid:       ✓

STEP 2: Validation
----------------------------------------------------------------------
✓ Validation passed

STEP 3: JSON Conversion
----------------------------------------------------------------------
✓ Conversion complete
Output: /path/to/output/json/sample_837p_claim.json

======================================================================
PROCESSING COMPLETE
======================================================================
```

### Example 2: Detect Transaction Type Only

```bash
cd src/python
python3 x12_transaction_detector.py ../../data/sample_835_payment.x12
```

### Example 3: Validate Only (No Conversion)

```bash
cd src/python
python3 x12_validator.py ../../data/sample_837p_claim.x12
```

### Example 4: Custom Output Location

```bash
cd src/python
python3 x12_process.py ../../data/sample_837p_claim.x12 \
    --output-dir /custom/output/path
```

### Example 5: Python API Usage

```python
#!/usr/bin/env python3
from pathlib import Path
from x12_config import get_config
from x12_transaction_detector import X12TransactionDetector, TransactionType

# Get configuration
config = get_config()

# Detect transaction type
detector = X12TransactionDetector()
input_file = config.get_data_file("sample_837p_claim.x12")
result = detector.detect_file(str(input_file))

print(f"Type: {result.transaction_type.value}")
print(f"Valid: {result.is_valid}")

# Route based on type
if result.transaction_type == TransactionType.T837P:
    # Process professional claim
    pass
elif result.transaction_type == TransactionType.T835:
    # Process payment
    pass
```

## 🔍 Path Management

All tools use centralized configuration for paths:

### From Python Tools

```python
from x12_config import get_config

config = get_config()

# Input
input_file = config.get_data_file("file.x12")

# Output
json_file = config.get_output_json_file("file.json")
report_file = config.get_output_report_file("report.txt")
log_file = config.get_output_log_file("process.log")

# Directories
data_dir = config.data_dir
output_dir = config.output_dir
```

### From Elixir (via System.cmd)

```elixir
defmodule X12.Processor do
  def process(filename) do
    # Tools will find files automatically
    {output, 0} = System.cmd("python3", [
      "src/python/x12_process.py",
      Path.join("data", filename)
    ])
    
    # Output in output/json/
    json_path = Path.join(["output", "json", "#{filename}.json"])
    File.read!(json_path)
  end
end
```

## 🧪 Testing & Validation

### Run All Tests

```bash
cd src/python
./test_suite.sh
```

### Individual Component Tests

```bash
# Test configuration
python3 x12_config.py validate

# Test detection on all samples
for f in ../../data/sample_*.x12; do
    python3 x12_transaction_detector.py "$f" | grep "Type:"
done

# Test validation
python3 x12_validator.py ../../data/sample_837p_claim.x12
```

## 📊 Supported Transaction Types

| Type | Description | Detection | Validation | Conversion |
|------|-------------|-----------|------------|------------|
| 837P | Professional Claims | ✅ | ✅ | ✅ |
| 837I | Institutional Claims | ✅ | 🔄 | 🔄 |
| 835 | Payment/Remittance | ✅ | 🔄 | 🔄 |
| 270 | Eligibility Inquiry | ✅ | 🔄 | 🔄 |
| 271 | Eligibility Response | ✅ | 🔄 | 🔄 |
| 276 | Claim Status Inquiry | ✅ | 🔄 | 🔄 |
| 277 | Claim Status Response | ✅ | 🔄 | 🔄 |
| 278 | Authorization | ✅ | 🔄 | 🔄 |
| 999 | Acknowledgment | ✅ | 🔄 | 🔄 |

Legend:
- ✅ Complete and tested
- 🔄 Framework ready, implementation needed

## 🔐 HIPAA Compliance

When processing files containing PHI:

1. **Encryption**: Files in `data/` and `output/` should be encrypted at rest
2. **Access Control**: Restrict directory permissions
3. **Audit Logging**: Enable logging to `output/logs/`
4. **Secure Disposal**: Use secure deletion for processed files
5. **Network Security**: Encrypt transfers if moving files

## 📈 Performance

- **Transaction Detection**: ~10ms per file
- **837P Validation**: ~50ms per file
- **JSON Conversion**: ~100ms per file
- **Memory**: <10MB per process

## 🛠️ Troubleshooting

### "Project structure invalid"

```bash
# Create missing directories
cd src/python
python3 x12_config.py setup
```

### "Module not found"

```bash
# Make sure you're in src/python when running scripts
cd src/python
python3 x12_process.py ../../data/sample.x12
```

### "Permission denied"

```bash
# Make scripts executable
chmod +x test_suite.sh batch_process.sh
```

### "File not found"

```bash
# Check file location
ls -la ../../data/
# Files should be in data/ directory at project root
```

## 🚧 Next Steps

### Immediate
- [x] Centralized configuration
- [x] Master processor
- [x] Test suite
- [x] Bug fixes in validator

### Short-term (Q1 2025)
- [ ] Validators for 835, 270, 271, 276, 277, 278, 999
- [ ] JSON converters for all transaction types
- [ ] Enhanced logging to `output/logs/`
- [ ] Performance metrics

### Medium-term (Q2 2025)
- [ ] Web API for processing
- [ ] Real-time eligibility checking (270/271)
- [ ] Automated claim status tracking (276/277)
- [ ] Payment reconciliation (835)

## 📚 Documentation

- **INDEX.md**: Package overview and navigation
- **README_MULTI_TRANSACTION.md**: Complete integration guide
- **QUICK_REFERENCE.md**: Developer cheat sheet
- **VISUAL_OVERVIEW.md**: Architecture diagrams
- **PROJECT_SUMMARY.md**: Executive summary

## 🤝 Contributing

When adding new features:
1. Use `x12_config.py` for all path management
2. Add tests to `test_suite.sh`
3. Update documentation
4. Follow existing code patterns

## 📞 Support

For questions or issues:
1. Check documentation in `docs/`
2. Run `python3 x12_config.py validate`
3. Review test suite output
4. Check error logs in `output/logs/`

---

**Version**: 2.1  
**Updated**: December 2024  
**Status**: All core components tested and operational
