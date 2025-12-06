#!/bin/bash
# X12 Processing System Test Suite
# Tests all components with new directory structure

cd "$(dirname "$0")"
PYTHON_DIR="$(pwd)"
PROJECT_ROOT="$(cd ../.. && pwd)"
DATA_DIR="$PROJECT_ROOT/data"
OUTPUT_DIR="$PROJECT_ROOT/output"

echo "=========================================="
echo "X12 Processing System Test Suite"
echo "=========================================="
echo ""
echo "Project Root: $PROJECT_ROOT"
echo "Data Dir:     $DATA_DIR"
echo "Output Dir:   $OUTPUT_DIR"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Test 1: Configuration validation
test_config() {
    echo -e "${BLUE}Test 1: Configuration Validation${NC}"
    python3 x12_config.py validate > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ PASS${NC} - Project structure valid"
        ((PASS_COUNT++))
    else
        echo -e "  ${RED}✗ FAIL${NC} - Project structure invalid"
        ((FAIL_COUNT++))
    fi
    echo ""
}

# Test 2: Transaction detection on each sample file
test_detection() {
    echo -e "${BLUE}Test 2: Transaction Type Detection${NC}"
    
    local test_files=(
        "sample_837p_claim.x12:837P"
        "sample_837i_claim.x12:837I"
        "sample_835_payment.x12:835"
        "sample_270_eligibility.x12:270"
        "sample_271_eligibility_response.x12:271"
        "sample_276_claim_status.x12:276"
        "sample_277_claim_status_response.x12:277"
        "sample_278_auth_request.x12:278"
        "sample_999_acknowledgment.x12:999"
    )
    
    for test_case in "${test_files[@]}"; do
        IFS=':' read -r filename expected_type <<< "$test_case"
        file_path="$DATA_DIR/$filename"
        
        if [ -f "$file_path" ]; then
            output=$(python3 x12_transaction_detector.py "$file_path" 2>&1)
            exit_code=$?
            
            if [ $exit_code -eq 0 ] && echo "$output" | grep -q "Type: $expected_type"; then
                echo -e "  ${GREEN}✓ PASS${NC} - $filename ($expected_type)"
                ((PASS_COUNT++))
            else
                echo -e "  ${RED}✗ FAIL${NC} - $filename (expected $expected_type)"
                ((FAIL_COUNT++))
            fi
        else
            echo -e "  ${YELLOW}⚠ SKIP${NC} - $filename (file not found)"
        fi
    done
    echo ""
}

# Test 3: 837P validation
test_validation() {
    echo -e "${BLUE}Test 3: 837P Validation${NC}"
    
    # Test with valid file
    valid_file="$DATA_DIR/sample_837p_claim.x12"
    if [ -f "$valid_file" ]; then
        python3 x12_validator.py "$valid_file" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓ PASS${NC} - Valid file accepted"
            ((PASS_COUNT++))
        else
            echo -e "  ${RED}✗ FAIL${NC} - Valid file rejected"
            ((FAIL_COUNT++))
        fi
    else
        echo -e "  ${YELLOW}⚠ SKIP${NC} - Valid test file not found"
    fi
    
    # Test with malformed file
    malformed_file="$DATA_DIR/malformed_837p_claim.x12"
    if [ -f "$malformed_file" ]; then
        python3 x12_validator.py "$malformed_file" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "  ${GREEN}✓ PASS${NC} - Malformed file rejected"
            ((PASS_COUNT++))
        else
            echo -e "  ${RED}✗ FAIL${NC} - Malformed file accepted"
            ((FAIL_COUNT++))
        fi
    else
        echo -e "  ${YELLOW}⚠ SKIP${NC} - Malformed test file not found"
    fi
    echo ""
}

# Test 4: Master processor
test_master_processor() {
    echo -e "${BLUE}Test 4: Master Processor${NC}"
    
    test_file="$DATA_DIR/sample_837p_claim.x12"
    if [ -f "$test_file" ]; then
        output=$(python3 x12_process.py "$test_file" 2>&1)
        exit_code=$?
        
        # Check if processing succeeded
        if [ $exit_code -eq 0 ]; then
            echo -e "  ${GREEN}✓ PASS${NC} - Processing completed successfully"
            ((PASS_COUNT++))
        else
            echo -e "  ${RED}✗ FAIL${NC} - Processing failed"
            echo "    Output: $output"
            ((FAIL_COUNT++))
        fi
        
        # Check if JSON was created
        json_file="$OUTPUT_DIR/json/sample_837p_claim.json"
        if [ -f "$json_file" ]; then
            echo -e "  ${GREEN}✓ PASS${NC} - JSON output created"
            ((PASS_COUNT++))
        else
            echo -e "  ${RED}✗ FAIL${NC} - JSON output not found"
            ((FAIL_COUNT++))
        fi
    else
        echo -e "  ${YELLOW}⚠ SKIP${NC} - Test file not found"
    fi
    echo ""
}

# Test 5: Directory structure
test_directory_structure() {
    echo -e "${BLUE}Test 5: Directory Structure${NC}"
    
    required_dirs=(
        "$DATA_DIR"
        "$OUTPUT_DIR"
        "$OUTPUT_DIR/json"
        "$OUTPUT_DIR/reports"
        "$OUTPUT_DIR/logs"
        "$PROJECT_ROOT/src/python"
        "$PROJECT_ROOT/docs"
    )
    
    all_exist=true
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}✓${NC} $dir"
        else
            echo -e "  ${RED}✗${NC} $dir (missing)"
            all_exist=false
        fi
    done
    
    if [ "$all_exist" = true ]; then
        echo -e "  ${GREEN}✓ PASS${NC} - All directories present"
        ((PASS_COUNT++))
    else
        echo -e "  ${RED}✗ FAIL${NC} - Some directories missing"
        ((FAIL_COUNT++))
    fi
    echo ""
}

# Run all tests
echo "Running Tests..."
echo ""

test_config
test_directory_structure
test_detection
test_validation
test_master_processor

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo "Total:  $((PASS_COUNT + FAIL_COUNT))"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
