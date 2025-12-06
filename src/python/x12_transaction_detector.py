#!/usr/bin/env python3
"""
X12 Transaction Type Detector

Identifies and validates X12 EDI transaction types for healthcare data processing.
Supports: 837P, 837I, 835, 270, 271, 276, 277, 278, 999

Author: Healthcare Data Processing System
Version: 2.0
"""

import sys
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum


class TransactionType(Enum):
    """Supported X12 transaction types"""
    T837P = "837P"  # Professional Claims
    T837I = "837I"  # Institutional Claims
    T835 = "835"    # Payment/Remittance Advice
    T270 = "270"    # Eligibility Inquiry
    T271 = "271"    # Eligibility Response
    T276 = "276"    # Claim Status Inquiry
    T277 = "277"    # Claim Status Response
    T278 = "278"    # Authorization Request/Response
    T999 = "999"    # Implementation Acknowledgment
    UNKNOWN = "UNKNOWN"


@dataclass
class TransactionInfo:
    """Information about detected X12 transaction"""
    transaction_type: TransactionType
    transaction_code: str
    implementation_guide: Optional[str]
    functional_group_code: str
    description: str
    is_valid: bool
    confidence: str  # HIGH, MEDIUM, LOW
    details: List[str]


class X12TransactionDetector:
    """Detects and identifies X12 transaction types"""
    
    # Transaction Set Identifier codes (ST segment)
    TRANSACTION_CODES = {
        "837": "Health Care Claim",
        "835": "Health Care Claim Payment/Advice",
        "270": "Eligibility, Coverage or Benefit Inquiry",
        "271": "Eligibility, Coverage or Benefit Information",
        "276": "Health Care Claim Status Request",
        "277": "Health Care Claim Status Response",
        "278": "Health Care Services Review Information",
        "999": "Implementation Acknowledgment"
    }
    
    # Functional Group codes (GS segment)
    FUNCTIONAL_GROUP_CODES = {
        "HC": "Health Care Claim",
        "HP": "Health Care Claim Payment",
        "HS": "Health Care Services Review",
        "HB": "Health Care Eligibility/Benefit Response",
        "HR": "Health Care Claim Status Request",
        "HN": "Health Care Claim Status Response",
        "FA": "Functional Acknowledgment"
    }
    
    # Implementation guides for 837 variants
    IMPL_GUIDES_837 = {
        "005010X222": "837P - Professional",
        "005010X222A1": "837P - Professional",
        "005010X223": "837I - Institutional",
        "005010X223A1": "837I - Institutional",
        "005010X223A2": "837I - Institutional",
        "005010X224": "837D - Dental",
        "005010X224A1": "837D - Dental",
        "005010X224A2": "837D - Dental"
    }
    
    # Implementation guides for other transactions
    IMPL_GUIDES = {
        "005010X221": "835 - Payment/Remittance",
        "005010X221A1": "835 - Payment/Remittance",
        "005010X279": "270/271 - Eligibility",
        "005010X279A1": "270/271 - Eligibility",
        "005010X212": "276/277 - Claim Status",
        "005010X217": "278 - Authorization",
        "005010": "999 - Acknowledgment"
    }
    
    def __init__(self):
        self.segments = []
        self.delimiters = {}
        
    def detect_file(self, file_path: str) -> TransactionInfo:
        """Detect transaction type from X12 file"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            return self.detect_content(content)
        except Exception as e:
            return TransactionInfo(
                transaction_type=TransactionType.UNKNOWN,
                transaction_code="",
                implementation_guide=None,
                functional_group_code="",
                description=f"Error reading file: {str(e)}",
                is_valid=False,
                confidence="LOW",
                details=[f"File read error: {str(e)}"]
            )
    
    def detect_content(self, content: str) -> TransactionInfo:
        """Detect transaction type from X12 content string"""
        details = []
        
        # Parse delimiters from ISA
        if not self._parse_delimiters(content):
            return TransactionInfo(
                transaction_type=TransactionType.UNKNOWN,
                transaction_code="",
                implementation_guide=None,
                functional_group_code="",
                description="Invalid X12 format: Cannot parse ISA segment",
                is_valid=False,
                confidence="LOW",
                details=["Unable to parse delimiters from ISA segment"]
            )
        
        details.append(f"Delimiters detected: Element='{self.delimiters['element']}', "
                      f"Segment='{self.delimiters['segment']}', "
                      f"Sub-element='{self.delimiters['sub_element']}'")
        
        # Split into segments
        self.segments = content.split(self.delimiters['segment'])
        self.segments = [s.strip() for s in self.segments if s.strip()]
        
        details.append(f"Total segments: {len(self.segments)}")
        
        # Extract key segments
        st_segment = self._find_segment("ST")
        gs_segment = self._find_segment("GS")
        
        if not st_segment:
            return TransactionInfo(
                transaction_type=TransactionType.UNKNOWN,
                transaction_code="",
                implementation_guide=None,
                functional_group_code="",
                description="Invalid X12: Missing ST segment",
                is_valid=False,
                confidence="LOW",
                details=details + ["ST segment not found"]
            )
        
        # Parse ST segment
        st_elements = st_segment.split(self.delimiters['element'])
        transaction_code = st_elements[1] if len(st_elements) > 1 else ""
        impl_guide = st_elements[3] if len(st_elements) > 3 else None
        
        details.append(f"Transaction code (ST02): {transaction_code}")
        details.append(f"Implementation guide (ST03): {impl_guide}")
        
        # Parse GS segment if available
        functional_group = ""
        if gs_segment:
            gs_elements = gs_segment.split(self.delimiters['element'])
            functional_group = gs_elements[1] if len(gs_elements) > 1 else ""
            details.append(f"Functional group (GS01): {functional_group}")
        
        # Determine transaction type
        trans_type, confidence = self._determine_transaction_type(
            transaction_code, impl_guide, functional_group, details
        )
        
        # Get description
        description = self._get_description(trans_type, transaction_code, impl_guide)
        
        # Validate consistency
        is_valid = self._validate_consistency(
            trans_type, transaction_code, functional_group, details
        )
        
        return TransactionInfo(
            transaction_type=trans_type,
            transaction_code=transaction_code,
            implementation_guide=impl_guide,
            functional_group_code=functional_group,
            description=description,
            is_valid=is_valid,
            confidence=confidence,
            details=details
        )
    
    def _parse_delimiters(self, content: str) -> bool:
        """Parse delimiters from ISA segment"""
        if not content.startswith("ISA"):
            return False
        
        if len(content) < 106:
            return False
        
        # Element separator is at position 3
        element_sep = content[3]
        # Sub-element separator is at position 104
        sub_element_sep = content[104]
        
        # Find segment terminator (after ISA segment, typically at position 105 or 106)
        segment_term = None
        for i in range(105, min(108, len(content))):
            if content[i] not in [element_sep, sub_element_sep, ' ', '\n', '\r']:
                segment_term = content[i]
                break
        
        if not segment_term:
            return False
        
        self.delimiters = {
            'element': element_sep,
            'segment': segment_term,
            'sub_element': sub_element_sep
        }
        return True
    
    def _find_segment(self, segment_id: str) -> Optional[str]:
        """Find first occurrence of a segment by ID"""
        for segment in self.segments:
            if segment.startswith(segment_id + self.delimiters['element']):
                return segment
        return None
    
    def _determine_transaction_type(
        self, 
        transaction_code: str, 
        impl_guide: Optional[str],
        functional_group: str,
        details: List[str]
    ) -> Tuple[TransactionType, str]:
        """Determine the specific transaction type with confidence level"""
        
        # Check for 999 Implementation Acknowledgment
        if transaction_code == "999":
            details.append("Identified as 999 Implementation Acknowledgment")
            return TransactionType.T999, "HIGH"
        
        # Check for 837 variants (need impl guide to distinguish)
        if transaction_code == "837":
            if impl_guide:
                impl_prefix = impl_guide[:12]  # e.g., "005010X222"
                if impl_prefix in self.IMPL_GUIDES_837:
                    guide_desc = self.IMPL_GUIDES_837[impl_prefix]
                    if "Professional" in guide_desc:
                        details.append(f"837P identified via implementation guide: {impl_guide}")
                        return TransactionType.T837P, "HIGH"
                    elif "Institutional" in guide_desc:
                        details.append(f"837I identified via implementation guide: {impl_guide}")
                        return TransactionType.T837I, "HIGH"
            
            # Fallback: Check functional group
            if functional_group == "HC":
                details.append("837 type unclear - defaulting to 837P (most common)")
                return TransactionType.T837P, "MEDIUM"
            
            details.append("837 variant cannot be determined with confidence")
            return TransactionType.UNKNOWN, "LOW"
        
        # Check for 835 Payment/Remittance
        if transaction_code == "835":
            details.append("Identified as 835 Payment/Remittance Advice")
            return TransactionType.T835, "HIGH"
        
        # Check for 270 Eligibility Inquiry
        if transaction_code == "270":
            details.append("Identified as 270 Eligibility Inquiry")
            return TransactionType.T270, "HIGH"
        
        # Check for 271 Eligibility Response
        if transaction_code == "271":
            details.append("Identified as 271 Eligibility Response")
            return TransactionType.T271, "HIGH"
        
        # Check for 276 Claim Status Inquiry
        if transaction_code == "276":
            details.append("Identified as 276 Claim Status Inquiry")
            return TransactionType.T276, "HIGH"
        
        # Check for 277 Claim Status Response
        if transaction_code == "277":
            details.append("Identified as 277 Claim Status Response")
            return TransactionType.T277, "HIGH"
        
        # Check for 278 Authorization
        if transaction_code == "278":
            details.append("Identified as 278 Authorization Request/Response")
            return TransactionType.T278, "HIGH"
        
        details.append(f"Unknown transaction code: {transaction_code}")
        return TransactionType.UNKNOWN, "LOW"
    
    def _get_description(
        self, 
        trans_type: TransactionType,
        transaction_code: str,
        impl_guide: Optional[str]
    ) -> str:
        """Get human-readable description of transaction type"""
        
        if trans_type == TransactionType.T837P:
            return "837P - Professional Health Care Claim"
        elif trans_type == TransactionType.T837I:
            return "837I - Institutional Health Care Claim"
        elif trans_type == TransactionType.T835:
            return "835 - Health Care Claim Payment/Remittance Advice"
        elif trans_type == TransactionType.T270:
            return "270 - Health Care Eligibility/Benefit Inquiry"
        elif trans_type == TransactionType.T271:
            return "271 - Health Care Eligibility/Benefit Response"
        elif trans_type == TransactionType.T276:
            return "276 - Health Care Claim Status Request"
        elif trans_type == TransactionType.T277:
            return "277 - Health Care Claim Status Response"
        elif trans_type == TransactionType.T278:
            return "278 - Health Care Services Review (Authorization)"
        elif trans_type == TransactionType.T999:
            return "999 - Implementation Acknowledgment for Health Care"
        else:
            base_desc = self.TRANSACTION_CODES.get(transaction_code, "Unknown Transaction")
            return f"{transaction_code} - {base_desc}"
    
    def _validate_consistency(
        self,
        trans_type: TransactionType,
        transaction_code: str,
        functional_group: str,
        details: List[str]
    ) -> bool:
        """Validate that functional group matches transaction type"""
        
        # Expected mappings
        expected_fg = {
            TransactionType.T837P: "HC",
            TransactionType.T837I: "HC",
            TransactionType.T835: "HP",
            TransactionType.T270: "HS",
            TransactionType.T271: "HB",
            TransactionType.T276: "HR",
            TransactionType.T277: "HN",
            TransactionType.T278: "HS",
            TransactionType.T999: "FA"
        }
        
        if trans_type in expected_fg:
            expected = expected_fg[trans_type]
            if functional_group and functional_group != expected:
                details.append(
                    f"WARNING: Functional group '{functional_group}' does not match "
                    f"expected '{expected}' for {trans_type.value}"
                )
                return False
        
        return True


def format_transaction_report(info: TransactionInfo) -> str:
    """Format transaction detection results as a readable report"""
    
    report = []
    report.append("=" * 70)
    report.append("X12 TRANSACTION TYPE DETECTION REPORT")
    report.append("=" * 70)
    report.append("")
    
    # Status indicator
    status_symbol = "✓" if info.is_valid else "✗"
    report.append(f"Status: {status_symbol} {'VALID' if info.is_valid else 'INVALID'}")
    report.append(f"Confidence: {info.confidence}")
    report.append("")
    
    # Transaction Information
    report.append("TRANSACTION INFORMATION")
    report.append("-" * 70)
    report.append(f"Type: {info.transaction_type.value}")
    report.append(f"Description: {info.description}")
    report.append(f"Transaction Code: {info.transaction_code}")
    
    if info.implementation_guide:
        report.append(f"Implementation Guide: {info.implementation_guide}")
    
    if info.functional_group_code:
        fg_desc = X12TransactionDetector.FUNCTIONAL_GROUP_CODES.get(
            info.functional_group_code, "Unknown"
        )
        report.append(f"Functional Group: {info.functional_group_code} ({fg_desc})")
    
    report.append("")
    
    # Details
    if info.details:
        report.append("DETECTION DETAILS")
        report.append("-" * 70)
        for detail in info.details:
            report.append(f"  • {detail}")
        report.append("")
    
    # Usage recommendations
    report.append("RECOMMENDED PROCESSING")
    report.append("-" * 70)
    
    processing_notes = {
        TransactionType.T837P: [
            "Process as professional healthcare claim",
            "Extract: Provider, Patient, Claim, Service Lines",
            "Validate: NPI numbers, diagnosis codes, procedure codes"
        ],
        TransactionType.T837I: [
            "Process as institutional healthcare claim",
            "Extract: Facility, Patient, Claim, Revenue Codes",
            "Validate: NPI numbers, diagnosis codes, revenue codes"
        ],
        TransactionType.T835: [
            "Process as payment/remittance advice",
            "Extract: Payment info, Claim adjustments, Service payments",
            "Match to original claims for reconciliation"
        ],
        TransactionType.T270: [
            "Process as eligibility inquiry",
            "Extract: Patient info, Coverage dates, Service types",
            "Route to payer eligibility system"
        ],
        TransactionType.T271: [
            "Process as eligibility response",
            "Extract: Coverage details, Benefits, Copay/Deductible info",
            "Update patient eligibility records"
        ],
        TransactionType.T276: [
            "Process as claim status inquiry",
            "Extract: Claim identifiers, Service dates",
            "Query claim tracking system"
        ],
        TransactionType.T277: [
            "Process as claim status response",
            "Extract: Claim status codes, Processing dates",
            "Update claim tracking records"
        ],
        TransactionType.T278: [
            "Process as authorization request/response",
            "Extract: Service details, Authorization numbers, Approval dates",
            "Update authorization management system"
        ],
        TransactionType.T999: [
            "Process as implementation acknowledgment",
            "Extract: Acceptance/rejection status, Error details",
            "Log for transaction tracking and error handling"
        ]
    }
    
    notes = processing_notes.get(info.transaction_type, 
                                 ["Unknown transaction type - manual review required"])
    for note in notes:
        report.append(f"  • {note}")
    
    report.append("")
    report.append("=" * 70)
    
    return "\n".join(report)


def main():
    """Command-line interface for transaction detection"""
    
    if len(sys.argv) < 2:
        print("Usage: python x12_transaction_detector.py <path_to_x12_file>")
        print("\nDetects and identifies X12 healthcare transaction types:")
        print("  • 837P - Professional Claims")
        print("  • 837I - Institutional Claims")
        print("  • 835  - Payment/Remittance Advice")
        print("  • 270  - Eligibility Inquiry")
        print("  • 271  - Eligibility Response")
        print("  • 276  - Claim Status Inquiry")
        print("  • 277  - Claim Status Response")
        print("  • 278  - Authorization Request/Response")
        print("  • 999  - Implementation Acknowledgment")
        sys.exit(1)
    
    file_path = sys.argv[1]
    
    detector = X12TransactionDetector()
    result = detector.detect_file(file_path)
    
    print(format_transaction_report(result))
    
    # Exit code: 0 for valid/recognized, 1 for invalid/unknown
    sys.exit(0 if result.is_valid and result.transaction_type != TransactionType.UNKNOWN else 1)


if __name__ == "__main__":
    main()
