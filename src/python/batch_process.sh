#!/bin/bash
# Batch X12 Processor
# Process all X12 files in data directory

cd "$(dirname "$0")"
PROJECT_ROOT="$(cd ../.. && pwd)"
DATA_DIR="$PROJECT_ROOT/data"
OUTPUT_DIR="$PROJECT_ROOT/output"

echo "=========================================="
echo "X12 Batch Processor"
echo "=========================================="
echo ""
echo "Data Directory: $DATA_DIR"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Find all X12 files
x12_files=$(find "$DATA_DIR" -maxdepth 1 -name "*.x12" -type f ! -name "malformed*")

if [ -z "$x12_files" ]; then
    echo "No X12 files found in $DATA_DIR"
    exit 1
fi

echo "Found X12 files:"
echo "$x12_files" | while read file; do
    echo "  - $(basename "$file")"
done
echo ""

# Parse options
SKIP_VALIDATION=false
GENERATE_REPORT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --report)
            GENERATE_REPORT=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--skip-validation] [--report]"
            exit 1
            ;;
    esac
done

echo "Processing files..."
echo ""

# Process each file
echo "$x12_files" | while read file; do
    filename=$(basename "$file")
    
    # Skip malformed test files
    if [[ "$filename" == malformed* ]]; then
        echo -e "${BLUE}SKIP${NC} $filename (test file)"
        continue
    fi
    
    echo -e "${BLUE}Processing:${NC} $filename"
    
    # Build command
    cmd="python3 x12_process.py \"$file\""
    if [ "$SKIP_VALIDATION" = true ]; then
        cmd="$cmd --skip-validation"
    fi
    if [ "$GENERATE_REPORT" = true ]; then
        cmd="$cmd --report"
    fi
    
    # Execute
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ SUCCESS${NC}"
    else
        echo -e "  ${RED}✗ FAILED${NC}"
    fi
    echo ""
done

echo "=========================================="
echo "Batch Processing Complete"
echo "=========================================="
echo "Check $OUTPUT_DIR/json for results"
