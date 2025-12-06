#!/usr/bin/env python3
"""
X12 837P EDI Validator

This script validates X12 837P (Professional Claims) EDI files for:
- Structural integrity (segment format, delimiters, envelopes)
- Syntactical correctness (data types, lengths, code sets)
- Business rules (required segments, relationships, logic)

Usage:
    python x12_validator.py <path_to_x12_file>

Author: Healthcare Data Processing System
Date: 2025-11-27
"""

import sys
import re
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass, field
from enum import Enum

# Constants for validation
MIN_VALID_YEAR = 1900
MAX_VALID_YEAR = 2100
MIN_ISA_LENGTH = 106


class ValidationLevel(Enum):
    """Severity levels for validation issues"""
    ERROR = "ERROR"      # Fatal issues that prevent processing
    WARNING = "WARNING"  # Issues that may cause rejection by payer
    INFO = "INFO"        # Informational, data may still process


@dataclass
class ValidationIssue:
    """Represents a single validation issue found in the X12 data"""
    level: ValidationLevel
    segment_id: str
    segment_number: int
    element_position: Optional[int]
    message: str
    context: str = ""


@dataclass
class ValidationResult:
    """Contains all validation results for an X12 file"""
    is_valid: bool = True
    issues: List[ValidationIssue] = field(default_factory=list)
    segment_count: int = 0
    
    def add_issue(self, level: ValidationLevel, segment_id: str, segment_num: int,
                  element_pos: Optional[int], message: str, context: str = ""):
        """Add a validation issue to the result"""
        issue = ValidationIssue(level, segment_id, segment_num, element_pos, message, context)
        self.issues.append(issue)
        if level == ValidationLevel.ERROR:
            self.is_valid = False
    
    def get_summary(self) -> Dict[str, int]:
        """Get count of issues by level"""
        summary = {level.value: 0 for level in ValidationLevel}
        for issue in self.issues:
            summary[issue.level.value] += 1
        return summary


class X12Validator:
    """Validates X12 837P EDI data for structural, syntactical, and business rule compliance"""
    
    # X12 837P required segments in order (simplified)
    REQUIRED_SEGMENTS = ['ISA', 'GS', 'ST', 'BHT', 'NM1', 'HL', 'CLM', 'SE', 'GE', 'IEA']
    
    # Valid segment identifiers for 837P
    VALID_SEGMENTS_837P = {
        'ISA', 'GS', 'ST', 'BHT', 'REF', 'NM1', 'N3', 'N4', 'PER', 'HL', 
        'PRV', 'SBR', 'PAT', 'CLM', 'DTP', 'CL1', 'HI', 'LX', 'SV1', 'SE', 'GE', 'IEA'
    }
    
    # Code sets for common elements
    ENTITY_TYPE_CODES = {'1': 'Person', '2': 'Non-Person Entity'}
    ENTITY_ID_CODES = {
        '1P': 'Provider', '2B': 'Third-Party Administrator', 
        '36': 'Employer', '40': 'Receiver', '41': 'Submitter',
        '85': 'Billing Provider', '87': 'Pay-to Provider',
        'IL': 'Insured', 'PR': 'Payer', 'QC': 'Patient'
    }
    RELATIONSHIP_CODES = {
        '01': 'Spouse', '18': 'Self', '19': 'Child', '20': 'Employee',
        '21': 'Unknown', '39': 'Organ Donor', '40': 'Cadaver Donor',
        '53': 'Life Partner', 'G8': 'Other Relationship'
    }
    
    def __init__(self):
        self.result = ValidationResult()
        self.segment_terminator = '~'
        self.element_separator = '*'
        self.sub_element_separator = ':'
        
    def validate_file(self, filepath: str) -> ValidationResult:
        """
        Validate an X12 837P file
        
        Args:
            filepath: Path to the X12 file
            
        Returns:
            ValidationResult object containing all validation issues
        """
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
        except FileNotFoundError:
            self.result.add_issue(
                ValidationLevel.ERROR, 'FILE', 0, None,
                f"File not found: {filepath}"
            )
            return self.result
        except Exception as e:
            self.result.add_issue(
                ValidationLevel.ERROR, 'FILE', 0, None,
                f"Error reading file: {str(e)}"
            )
            return self.result
        
        # Parse delimiters from ISA segment
        if not self._parse_delimiters(content):
            return self.result
        
        # Split into segments
        segments = self._split_segments(content)
        self.result.segment_count = len(segments)
        
        if len(segments) == 0:
            self.result.add_issue(
                ValidationLevel.ERROR, 'FILE', 0, None,
                "No segments found in file"
            )
            return self.result
        
        # Run validation layers
        self._validate_structure(segments)
        self._validate_envelopes(segments)
        self._validate_segments(segments)
        self._validate_business_rules(segments)
        
        return self.result
    
    def _parse_delimiters(self, content: str) -> bool:
        """
        Parse delimiters from ISA segment

        The ISA segment has fixed positions:
        - Position 3: Element separator
        - Position 105: Sub-element separator
        - Last character: Segment terminator
        """
        if len(content) < MIN_ISA_LENGTH:
            self.result.add_issue(
                ValidationLevel.ERROR, 'ISA', 0, None,
                "File too short to contain valid ISA segment"
            )
            return False
        
        if not content.startswith('ISA'):
            self.result.add_issue(
                ValidationLevel.ERROR, 'ISA', 0, None,
                "File must start with ISA segment"
            )
            return False
        
        # Parse delimiters
        self.element_separator = content[3]
        self.sub_element_separator = content[104]
        
        # Find segment terminator (first occurrence after ISA)
        isa_end = content.find('\n', 106)
        if isa_end == -1:
            isa_end = len(content)
        
        # Segment terminator is typically the last char before newline
        isa_segment = content[:isa_end].strip()
        if len(isa_segment) > 0:
            self.segment_terminator = isa_segment[-1]
        
        return True
    
    def _split_segments(self, content: str) -> List[List[str]]:
        """Split content into segments and elements

        Returns:
            List of segments, where each segment is a list of elements
        """
        segments = []
        raw_segments = content.split(self.segment_terminator)

        for raw_seg in raw_segments:
            raw_seg = raw_seg.strip()
            if raw_seg:
                elements = raw_seg.split(self.element_separator)
                segments.append(elements)

        return segments
    
    def _validate_structure(self, segments: List[List[str]]) -> None:
        """Validate basic structural requirements"""
        for idx, segment in enumerate(segments, 1):
            segment_id = segment[0] if segment else ""
            
            # Check segment identifier
            if not segment_id:
                self.result.add_issue(
                    ValidationLevel.ERROR, 'UNKNOWN', idx, None,
                    "Segment has no identifier"
                )
                continue
            
            # Check if segment ID is valid for 837P
            if segment_id not in self.VALID_SEGMENTS_837P:
                self.result.add_issue(
                    ValidationLevel.WARNING, segment_id, idx, None,
                    f"Segment ID '{segment_id}' not recognized for 837P transaction"
                )
            
            # Check minimum elements
            if len(segment) < 2:
                self.result.add_issue(
                    ValidationLevel.ERROR, segment_id, idx, None,
                    f"Segment has insufficient elements (found {len(segment)})"
                )
    
    def _validate_envelopes(self, segments: List[List[str]]) -> None:
        """Validate ISA/IEA, GS/GE, ST/SE envelope structure"""

        # Track envelope state
        isa_count = 0
        gs_count = 0
        st_count = 0
        isa_control = None
        gs_control = None
        st_control = None
        
        for idx, segment in enumerate(segments, 1):
            segment_id = segment[0] if segment else ""
            
            # ISA envelope
            if segment_id == 'ISA':
                isa_count += 1
                if isa_count > 1:
                    self.result.add_issue(
                        ValidationLevel.ERROR, 'ISA', idx, None,
                        "Multiple ISA segments found (should be exactly one)"
                    )
                if len(segment) >= 14:
                    isa_control = segment[13]
                else:
                    self.result.add_issue(
                        ValidationLevel.ERROR, 'ISA', idx, 13,
                        "ISA segment missing control number"
                    )
            
            elif segment_id == 'IEA':
                if len(segment) >= 3:
                    iea_control = segment[2]
                    if isa_control and iea_control != isa_control:
                        self.result.add_issue(
                            ValidationLevel.ERROR, 'IEA', idx, 2,
                            f"IEA control number '{iea_control}' does not match ISA '{isa_control}'"
                        )
                    
                    # Validate functional group count
                    expected_gs = segment[1]
                    if expected_gs != str(gs_count):
                        self.result.add_issue(
                            ValidationLevel.ERROR, 'IEA', idx, 1,
                            f"IEA reports {expected_gs} functional groups but found {gs_count}"
                        )
            
            # GS envelope
            elif segment_id == 'GS':
                gs_count += 1
                if len(segment) >= 9:
                    gs_control = segment[6]
                else:
                    self.result.add_issue(
                        ValidationLevel.ERROR, 'GS', idx, 6,
                        "GS segment missing control number"
                    )
            
            elif segment_id == 'GE':
                if len(segment) >= 3:
                    ge_control = segment[2]
                    if gs_control and ge_control != gs_control:
                        self.result.add_issue(
                            ValidationLevel.ERROR, 'GE', idx, 2,
                            f"GE control number '{ge_control}' does not match GS '{gs_control}'"
                        )
                    
                    # Validate transaction set count
                    expected_st = segment[1]
                    if expected_st != str(st_count):
                        self.result.add_issue(
                            ValidationLevel.ERROR, 'GE', idx, 1,
                            f"GE reports {expected_st} transaction sets but found {st_count}"
                        )
            
            # ST envelope
            elif segment_id == 'ST':
                st_count += 1
                if len(segment) >= 3:
                    st_control = segment[2]
                    # Verify transaction set identifier is 837
                    if segment[1] != '837':
                        self.result.add_issue(
                            ValidationLevel.ERROR, 'ST', idx, 1,
                            f"Expected transaction set '837' but found '{segment[1]}'"
                        )
                else:
                    self.result.add_issue(
                        ValidationLevel.ERROR, 'ST', idx, 2,
                        "ST segment missing control number"
                    )
            
            elif segment_id == 'SE':
                if len(segment) >= 3:
                    se_control = segment[2]
                    if st_control and se_control != st_control:
                        self.result.add_issue(
                            ValidationLevel.ERROR, 'SE', idx, 2,
                            f"SE control number '{se_control}' does not match ST '{st_control}'"
                        )
        
        # Verify we have required envelopes
        if isa_count == 0:
            self.result.add_issue(
                ValidationLevel.ERROR, 'ISA', 0, None,
                "Missing ISA segment (required)"
            )
        
        if gs_count == 0:
            self.result.add_issue(
                ValidationLevel.ERROR, 'GS', 0, None,
                "Missing GS segment (required)"
            )
        
        if st_count == 0:
            self.result.add_issue(
                ValidationLevel.ERROR, 'ST', 0, None,
                "Missing ST segment (required)"
            )
    
    def _validate_segments(self, segments: List[List[str]]) -> None:
        """Validate individual segment content"""
        for idx, segment in enumerate(segments, 1):
            segment_id = segment[0] if segment else ""
            
            if segment_id == 'NM1':
                self._validate_nm1(segment, idx)
            elif segment_id == 'CLM':
                self._validate_clm(segment, idx)
            elif segment_id == 'DTP':
                self._validate_dtp(segment, idx)
            elif segment_id == 'HI':
                self._validate_hi(segment, idx)
            elif segment_id == 'SV1':
                self._validate_sv1(segment, idx)
    
    def _validate_nm1(self, segment: List[str], idx: int) -> None:
        """Validate NM1 (Entity Name) segment"""
        if len(segment) < 4:
            self.result.add_issue(
                ValidationLevel.ERROR, 'NM1', idx, None,
                f"NM1 segment has insufficient elements (found {len(segment)}, need at least 4)"
            )
            return
        
        # Validate entity identifier code (NM101)
        entity_code = segment[1]
        if entity_code not in self.ENTITY_ID_CODES:
            self.result.add_issue(
                ValidationLevel.WARNING, 'NM1', idx, 1,
                f"Entity identifier code '{entity_code}' not recognized",
                f"Valid codes: {', '.join(list(self.ENTITY_ID_CODES.keys())[:5])}..."
            )
        
        # Validate entity type qualifier (NM102)
        if len(segment) > 2:
            entity_type = segment[2]
            if entity_type not in self.ENTITY_TYPE_CODES:
                self.result.add_issue(
                    ValidationLevel.ERROR, 'NM1', idx, 2,
                    f"Invalid entity type qualifier '{entity_type}' (must be 1 or 2)"
                )
        
        # Validate name is present (NM103)
        if len(segment) > 3 and not segment[3].strip():
            self.result.add_issue(
                ValidationLevel.ERROR, 'NM1', idx, 3,
                "Entity name is required but empty"
            )
    
    def _validate_clm(self, segment: List[str], idx: int) -> None:
        """Validate CLM (Claim Information) segment"""
        if len(segment) < 6:
            self.result.add_issue(
                ValidationLevel.ERROR, 'CLM', idx, None,
                f"CLM segment has insufficient elements (found {len(segment)}, need at least 6)"
            )
            return
        
        # Validate claim amount (CLM02) is numeric
        claim_amount = segment[2]
        try:
            amount = float(claim_amount)
            if amount <= 0:
                self.result.add_issue(
                    ValidationLevel.WARNING, 'CLM', idx, 2,
                    f"Claim amount is {amount} (should be positive)"
                )
        except ValueError:
            self.result.add_issue(
                ValidationLevel.ERROR, 'CLM', idx, 2,
                f"Claim amount '{claim_amount}' is not a valid number"
            )
        
        # Validate facility code (CLM05) format
        if len(segment) > 5:
            facility_info = segment[5]
            parts = facility_info.split(self.sub_element_separator)
            if len(parts) >= 3:
                facility_code = parts[0]
                facility_qualifier = parts[1]
                frequency_code = parts[2]
                
                # Check facility code is numeric and 2 digits
                if not re.match(r'^\d{2}$', facility_code):
                    self.result.add_issue(
                        ValidationLevel.WARNING, 'CLM', idx, 5,
                        f"Facility code '{facility_code}' should be 2 digits"
                    )
    
    def _validate_dtp(self, segment: List[str], idx: int) -> None:
        """Validate DTP (Date or Time Period) segment"""
        if len(segment) < 4:
            self.result.add_issue(
                ValidationLevel.ERROR, 'DTP', idx, None,
                f"DTP segment has insufficient elements (found {len(segment)}, need 4)"
            )
            return
        
        # Validate date format qualifier (DTP02)
        date_format = segment[2]
        valid_formats = ['D8', 'RD8']  # CCYYMMDD, Range
        if date_format not in valid_formats:
            self.result.add_issue(
                ValidationLevel.WARNING, 'DTP', idx, 2,
                f"Date format qualifier '{date_format}' not standard (expected D8 or RD8)"
            )
        
        # Validate date value (DTP03)
        date_value = segment[3]
        if date_format == 'D8':
            if not re.match(r'^\d{8}$', date_value):
                self.result.add_issue(
                    ValidationLevel.ERROR, 'DTP', idx, 3,
                    f"Date '{date_value}' not in CCYYMMDD format"
                )
            else:
                # Validate date is logical
                year = int(date_value[0:4])
                month = int(date_value[4:6])
                day = int(date_value[6:8])

                if year < MIN_VALID_YEAR or year > MAX_VALID_YEAR:
                    self.result.add_issue(
                        ValidationLevel.WARNING, 'DTP', idx, 3,
                        f"Date year {year} seems unusual"
                    )
                if month < 1 or month > 12:
                    self.result.add_issue(
                        ValidationLevel.ERROR, 'DTP', idx, 3,
                        f"Date month {month} is invalid"
                    )
                if day < 1 or day > 31:
                    self.result.add_issue(
                        ValidationLevel.ERROR, 'DTP', idx, 3,
                        f"Date day {day} is invalid"
                    )
    
    def _validate_hi(self, segment: List[str], idx: int) -> None:
        """Validate HI (Health Care Diagnosis Code) segment"""
        if len(segment) < 2:
            self.result.add_issue(
                ValidationLevel.ERROR, 'HI', idx, None,
                "HI segment must contain at least one diagnosis code"
            )
            return
        
        # Each element after HI01 should be in format: qualifier:code
        for i, element in enumerate(segment[1:], 1):
            if self.sub_element_separator in element:
                parts = element.split(self.sub_element_separator)
                if len(parts) >= 2:
                    qualifier = parts[0]
                    code = parts[1]
                    
                    # Validate qualifier
                    valid_qualifiers = ['ABK', 'BK']  # ICD-10, ICD-9
                    if qualifier not in valid_qualifiers:
                        self.result.add_issue(
                            ValidationLevel.WARNING, 'HI', idx, i,
                            f"Diagnosis code qualifier '{qualifier}' not standard"
                        )
                    
                    # Validate code is not empty
                    if not code.strip():
                        self.result.add_issue(
                            ValidationLevel.ERROR, 'HI', idx, i,
                            "Diagnosis code is empty"
                        )
    
    def _validate_sv1(self, segment: List[str], idx: int) -> None:
        """Validate SV1 (Professional Service) segment"""
        if len(segment) < 3:
            self.result.add_issue(
                ValidationLevel.ERROR, 'SV1', idx, None,
                f"SV1 segment has insufficient elements (found {len(segment)})"
            )
            return
        
        # Validate line item charge (SV102) is numeric
        line_charge = segment[2]
        try:
            amount = float(line_charge)
            if amount < 0:
                self.result.add_issue(
                    ValidationLevel.WARNING, 'SV1', idx, 2,
                    f"Line item charge is negative: {amount}"
                )
        except ValueError:
            self.result.add_issue(
                ValidationLevel.ERROR, 'SV1', idx, 2,
                f"Line item charge '{line_charge}' is not a valid number"
            )
        
        # Validate units (SV104) is numeric
        if len(segment) > 4:
            units = segment[4]
            try:
                unit_count = float(units)
                if unit_count <= 0:
                    self.result.add_issue(
                        ValidationLevel.WARNING, 'SV1', idx, 4,
                        f"Service units should be positive (found {unit_count})"
                    )
            except ValueError:
                self.result.add_issue(
                    ValidationLevel.ERROR, 'SV1', idx, 4,
                    f"Service units '{units}' is not a valid number"
                )
    
    def _check_required_entities(
        self,
        has_billing_provider: bool,
        has_subscriber: bool,
        has_claim: bool
    ) -> None:
        """Check that all required entities are present"""
        if not has_billing_provider:
            self.result.add_issue(
                ValidationLevel.ERROR, 'NM1', 0, None,
                "Missing required Billing Provider (NM1*85)"
            )

        if not has_subscriber:
            self.result.add_issue(
                ValidationLevel.ERROR, 'NM1', 0, None,
                "Missing required Subscriber/Insured (NM1*IL)"
            )

        if not has_claim:
            self.result.add_issue(
                ValidationLevel.ERROR, 'CLM', 0, None,
                "Missing required CLM (Claim Information) segment"
            )

    def _check_claim_totals(self, claim_amount: float, service_line_total: float) -> None:
        """Validate claim amount matches service line total"""
        if claim_amount > 0 and service_line_total > 0:
            difference = abs(claim_amount - service_line_total)
            if difference > 0.01:  # Allow for small rounding differences
                self.result.add_issue(
                    ValidationLevel.WARNING, 'CLM', 0, 2,
                    f"Claim amount (${claim_amount:.2f}) does not match service line total (${service_line_total:.2f})"
                )

    def _validate_business_rules(self, segments: List[List[str]]) -> None:
        """Validate business logic and relationships"""

        # Extract key segments for validation
        has_billing_provider = False
        has_subscriber = False
        has_patient = False
        has_claim = False
        claim_amount = 0.0
        service_line_total = 0.0

        for idx, segment in enumerate(segments, 1):
            segment_id = segment[0] if segment else ""

            # Check for required entities
            if segment_id == 'NM1' and len(segment) > 1:
                entity_code = segment[1]
                if entity_code == '85':  # Billing Provider
                    has_billing_provider = True
                elif entity_code == 'IL':  # Insured/Subscriber
                    has_subscriber = True
                elif entity_code == 'QC':  # Patient
                    has_patient = True

            # Track claim amount
            elif segment_id == 'CLM':
                has_claim = True
                if len(segment) > 2:
                    try:
                        claim_amount = float(segment[2])
                    except ValueError:
                        pass

            # Track service line amounts
            elif segment_id == 'SV1':
                if len(segment) > 2:
                    try:
                        service_line_total += float(segment[2])
                    except ValueError:
                        pass

        # Business rule validations
        self._check_required_entities(has_billing_provider, has_subscriber, has_claim)
        self._check_claim_totals(claim_amount, service_line_total)


def print_validation_report(result: ValidationResult):
    """Print a formatted validation report"""
    
    print("\n" + "="*80)
    print("X12 837P VALIDATION REPORT")
    print("="*80)
    
    print(f"\nTotal Segments Processed: {result.segment_count}")
    print(f"Overall Status: {'✓ VALID' if result.is_valid else '✗ INVALID'}")
    
    summary = result.get_summary()
    print(f"\nIssue Summary:")
    print(f"  Errors:   {summary['ERROR']}")
    print(f"  Warnings: {summary['WARNING']}")
    print(f"  Info:     {summary['INFO']}")
    
    if result.issues:
        print("\n" + "-"*80)
        print("VALIDATION ISSUES")
        print("-"*80)
        
        # Group by level
        for level in [ValidationLevel.ERROR, ValidationLevel.WARNING, ValidationLevel.INFO]:
            level_issues = [i for i in result.issues if i.level == level]
            if level_issues:
                print(f"\n{level.value}S ({len(level_issues)}):")
                print("-" * 80)
                for issue in level_issues:
                    element_info = f", Element {issue.element_position}" if issue.element_position else ""
                    print(f"  [{issue.segment_id}] Segment {issue.segment_number}{element_info}")
                    print(f"    {issue.message}")
                    if issue.context:
                        print(f"    Context: {issue.context}")
                    print()
    else:
        print("\n✓ No validation issues found!")
    
    print("="*80 + "\n")


def main():
    """Main entry point for the validation script"""
    
    if len(sys.argv) != 2:
        print("Usage: python x12_validator.py <path_to_x12_file>")
        print("\nExample:")
        print("  python x12_validator.py sample_837p_claim.x12")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    print(f"Validating X12 file: {filepath}")
    
    validator = X12Validator()
    result = validator.validate_file(filepath)
    
    print_validation_report(result)
    
    # Exit with appropriate code
    sys.exit(0 if result.is_valid else 1)


if __name__ == "__main__":
    main()
