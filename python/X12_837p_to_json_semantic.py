#!/usr/bin/env python3
"""
X12 837P to JSON Converter
Converts X12 EDI Professional Claims (837P) to semantic JSON format
"""

import json
import sys
from datetime import datetime
from typing import Dict, List, Optional, Any

# Constants for segment parsing
MAX_RELATED_SEGMENTS = 5  # Maximum segments to search after a primary segment
MAX_PROVIDER_SEGMENTS = 20  # Maximum segments in provider loop
MAX_SUBSCRIBER_SEGMENTS = 30  # Maximum segments in subscriber loop
MAX_CLAIM_SEGMENTS = 50  # Maximum segments in claim loop


class X12Parser:
    """Parser for X12 EDI format files"""
    
    def __init__(self, content: str):
        self.content = content
        self.segment_terminator = '~'
        self.element_separator = '*'
        self.subelement_separator = ':'
        self.segments = []
        self.current_position = 0
        
    def parse(self) -> List[List[str]]:
        """Parse X12 content into segments and elements"""
        # Remove newlines and split by segment terminator
        clean_content = self.content.replace('\n', '').replace('\r', '')
        raw_segments = clean_content.strip().split(self.segment_terminator)
        
        for raw_segment in raw_segments:
            if raw_segment.strip():
                # Split by element separator
                elements = raw_segment.split(self.element_separator)
                self.segments.append(elements)
        
        return self.segments
    
    def get_segment(self, segment_id: str, start_index: int = 0) -> Optional[List[str]]:
        """Find the first segment with given ID starting from index"""
        for i in range(start_index, len(self.segments)):
            if self.segments[i][0] == segment_id:
                return self.segments[i]
        return None
    
    def get_all_segments(self, segment_id: str) -> List[List[str]]:
        """Get all segments with given ID"""
        return [seg for seg in self.segments if seg[0] == segment_id]
    
    def find_segment_index(self, segment_id: str, start_index: int = 0) -> int:
        """Find index of first segment with given ID starting from start_index"""
        for i in range(start_index, len(self.segments)):
            if self.segments[i][0] == segment_id:
                return i
        return -1


class X12_837P_Converter:
    """Converts X12 837P claims to semantic JSON"""
    
    def __init__(self, parser: X12Parser):
        self.parser = parser
        self.result = {}
        
    def convert(self) -> Dict[str, Any]:
        """Main conversion method"""
        self.result = {
            "metadata": self._parse_metadata(),
            "interchange": self._parse_isa(),
            "functionalGroup": self._parse_gs(),
            "transactionSet": self._parse_st(),
            "beginningOfHierarchicalTransaction": self._parse_bht(),
            "submitter": self._parse_submitter(),
            "receiver": self._parse_receiver(),
            "providers": self._parse_providers(),
            "subscribers": self._parse_subscribers(),
            "claims": self._parse_claims(),
            "controlTotals": self._parse_control_totals()
        }
        return self.result
    
    def _parse_metadata(self) -> Dict[str, Any]:
        """Parse metadata information"""
        st_segment = self.parser.get_segment('ST')
        return {
            "transactionSet": st_segment[1] if st_segment and len(st_segment) > 1 else None,
            "transactionType": "Professional Claim",
            "version": st_segment[3] if st_segment and len(st_segment) > 3 else None,
            "conversionTimestamp": datetime.now().isoformat(),
            "sourceFile": "X12 EDI Stream"
        }
    
    def _parse_isa(self) -> Dict[str, Any]:
        """Parse ISA (Interchange Control Header) segment"""
        isa = self.parser.get_segment('ISA')
        if not isa:
            return {}
        
        return {
            "senderId": isa[6].strip() if len(isa) > 6 else None,
            "senderQualifier": isa[5].strip() if len(isa) > 5 else None,
            "receiverId": isa[8].strip() if len(isa) > 8 else None,
            "receiverQualifier": isa[7].strip() if len(isa) > 7 else None,
            "date": self._format_date(isa[9]) if len(isa) > 9 else None,
            "time": self._format_time(isa[10]) if len(isa) > 10 else None,
            "controlNumber": isa[13].strip() if len(isa) > 13 else None,
            "versionNumber": isa[12].strip() if len(isa) > 12 else None,
            "testIndicator": isa[15].strip() if len(isa) > 15 else None
        }
    
    def _parse_gs(self) -> Dict[str, Any]:
        """Parse GS (Functional Group Header) segment"""
        gs = self.parser.get_segment('GS')
        if not gs:
            return {}
        
        return {
            "functionalCode": gs[1] if len(gs) > 1 else None,
            "applicationSender": gs[2] if len(gs) > 2 else None,
            "applicationReceiver": gs[3] if len(gs) > 3 else None,
            "date": self._format_date(gs[4]) if len(gs) > 4 else None,
            "time": self._format_time(gs[5]) if len(gs) > 5 else None,
            "controlNumber": gs[6] if len(gs) > 6 else None,
            "responsibleAgency": gs[7] if len(gs) > 7 else None,
            "version": gs[8] if len(gs) > 8 else None
        }
    
    def _parse_st(self) -> Dict[str, Any]:
        """Parse ST (Transaction Set Header) segment"""
        st = self.parser.get_segment('ST')
        if not st:
            return {}
        
        return {
            "controlNumber": st[2] if len(st) > 2 else None,
            "implementationGuide": st[3] if len(st) > 3 else None
        }
    
    def _parse_bht(self) -> Dict[str, Any]:
        """Parse BHT (Beginning of Hierarchical Transaction) segment"""
        bht = self.parser.get_segment('BHT')
        if not bht:
            return {}
        
        return {
            "structureCode": bht[1] if len(bht) > 1 else None,
            "purposeCode": bht[2] if len(bht) > 2 else None,
            "referenceId": bht[3] if len(bht) > 3 else None,
            "date": self._format_date(bht[4]) if len(bht) > 4 else None,
            "time": self._format_time(bht[5]) if len(bht) > 5 else None,
            "transactionTypeCode": bht[6] if len(bht) > 6 else None
        }
    
    def _parse_submitter(self) -> Dict[str, Any]:
        """Parse submitter information (NM1*41)"""
        # Find NM1 segment with qualifier 41 (Submitter)
        for segment in self.parser.segments:
            if segment[0] == 'NM1' and len(segment) > 1 and segment[1] == '41':
                nm1 = segment
                submitter = {
                    "organizationName": nm1[3] if len(nm1) > 3 else None,
                    "identifierCode": nm1[9] if len(nm1) > 9 else None,
                    "identifierQualifier": nm1[8] if len(nm1) > 8 else None
                }
                
                # Look for PER segment (contact info) after NM1*41
                nm1_index = self.parser.segments.index(nm1)
                per_index = self.parser.find_segment_index('PER', nm1_index)
                if per_index > nm1_index and per_index < nm1_index + MAX_RELATED_SEGMENTS:
                    per = self.parser.segments[per_index]
                    submitter["contact"] = {
                        "name": per[2] if len(per) > 2 else None,
                        "phone": per[4] if len(per) > 4 else None,
                        "extension": per[6] if len(per) > 6 else None
                    }
                
                return submitter
        
        return {}
    
    def _parse_receiver(self) -> Dict[str, Any]:
        """Parse receiver information (NM1*40)"""
        for segment in self.parser.segments:
            if segment[0] == 'NM1' and len(segment) > 1 and segment[1] == '40':
                nm1 = segment
                return {
                    "organizationName": nm1[3] if len(nm1) > 3 else None,
                    "identifierCode": nm1[9] if len(nm1) > 9 else None,
                    "identifierQualifier": nm1[8] if len(nm1) > 8 else None
                }
        
        return {}
    
    def _parse_providers(self) -> List[Dict[str, Any]]:
        """Parse provider information (HL*20 loop)"""
        providers = []
        
        # Find HL segments with level code 20 (Billing Provider)
        for i, segment in enumerate(self.parser.segments):
            if segment[0] == 'HL' and len(segment) > 3 and segment[3] == '20':
                provider = {
                    "hierarchicalLevel": segment[1] if len(segment) > 1 else None,
                    "levelCode": segment[3] if len(segment) > 3 else None,
                    "hasChildren": segment[4] == '1' if len(segment) > 4 else False,
                    "providerType": "billing"
                }
                
                # Find NM1*85 (Billing Provider) after this HL
                for j in range(i + 1, min(i + MAX_PROVIDER_SEGMENTS, len(self.parser.segments))):
                    seg = self.parser.segments[j]
                    
                    if seg[0] == 'HL':  # Stop at next HL
                        break
                    
                    if seg[0] == 'NM1' and len(seg) > 1 and seg[1] == '85':
                        provider["organization"] = {
                            "name": seg[3] if len(seg) > 3 else None,
                            "npi": seg[9] if len(seg) > 9 else None
                        }
                    
                    elif seg[0] == 'N3':
                        if "address" not in provider:
                            provider["address"] = {}
                        provider["address"]["street"] = seg[1] if len(seg) > 1 else None
                    
                    elif seg[0] == 'N4':
                        if "address" not in provider:
                            provider["address"] = {}
                        provider["address"]["city"] = seg[1] if len(seg) > 1 else None
                        provider["address"]["state"] = seg[2] if len(seg) > 2 else None
                        provider["address"]["zip"] = seg[3] if len(seg) > 3 else None
                    
                    elif seg[0] == 'REF' and len(seg) > 1 and seg[1] == 'EI':
                        if "organization" not in provider:
                            provider["organization"] = {}
                        provider["organization"]["taxId"] = seg[2] if len(seg) > 2 else None
                
                providers.append(provider)
        
        return providers
    
    def _parse_subscribers(self) -> List[Dict[str, Any]]:
        """Parse subscriber information (HL*22 loop)"""
        subscribers = []
        
        # Find HL segments with level code 22 (Subscriber)
        for i, segment in enumerate(self.parser.segments):
            if segment[0] == 'HL' and len(segment) > 3 and segment[3] == '22':
                subscriber = {
                    "hierarchicalLevel": segment[1] if len(segment) > 1 else None,
                    "parentLevel": segment[2] if len(segment) > 2 else None,
                    "levelCode": segment[3] if len(segment) > 3 else None,
                    "hasChildren": segment[4] == '1' if len(segment) > 4 else False
                }
                
                # Parse segments in this loop
                for j in range(i + 1, min(i + MAX_SUBSCRIBER_SEGMENTS, len(self.parser.segments))):
                    seg = self.parser.segments[j]
                    
                    if seg[0] == 'HL' or seg[0] == 'CLM':  # Stop at next HL or CLM
                        break
                    
                    if seg[0] == 'SBR':
                        subscriber["payerResponsibility"] = self._decode_payer_responsibility(seg[1]) if len(seg) > 1 else None
                        subscriber["relationshipCode"] = seg[2] if len(seg) > 2 else None
                        subscriber["claimFilingIndicator"] = seg[9] if len(seg) > 9 else None
                    
                    elif seg[0] == 'NM1' and len(seg) > 1 and seg[1] == 'IL':
                        if "patient" not in subscriber:
                            subscriber["patient"] = {}
                        subscriber["patient"]["lastName"] = seg[3] if len(seg) > 3 else None
                        subscriber["patient"]["firstName"] = seg[4] if len(seg) > 4 else None
                        subscriber["patient"]["middleName"] = seg[5] if len(seg) > 5 else None
                        subscriber["patient"]["memberId"] = seg[9] if len(seg) > 9 else None
                    
                    elif seg[0] == 'NM1' and len(seg) > 1 and seg[1] == 'PR':
                        subscriber["payer"] = {
                            "name": seg[3] if len(seg) > 3 else None,
                            "payerId": seg[9] if len(seg) > 9 else None,
                            "identifierQualifier": seg[8] if len(seg) > 8 else None
                        }
                    
                    elif seg[0] == 'N3':
                        if "patient" not in subscriber:
                            subscriber["patient"] = {}
                        if "address" not in subscriber["patient"]:
                            subscriber["patient"]["address"] = {}
                        subscriber["patient"]["address"]["street"] = seg[1] if len(seg) > 1 else None
                    
                    elif seg[0] == 'N4':
                        if "patient" not in subscriber:
                            subscriber["patient"] = {}
                        if "address" not in subscriber["patient"]:
                            subscriber["patient"]["address"] = {}
                        subscriber["patient"]["address"]["city"] = seg[1] if len(seg) > 1 else None
                        subscriber["patient"]["address"]["state"] = seg[2] if len(seg) > 2 else None
                        subscriber["patient"]["address"]["zip"] = seg[3] if len(seg) > 3 else None
                    
                    elif seg[0] == 'DMG':
                        if "patient" not in subscriber:
                            subscriber["patient"] = {}
                        if "demographics" not in subscriber["patient"]:
                            subscriber["patient"]["demographics"] = {}
                        if len(seg) > 2:
                            subscriber["patient"]["demographics"]["dateOfBirth"] = self._format_date(seg[2])
                        if len(seg) > 3:
                            subscriber["patient"]["demographics"]["gender"] = seg[3]
                
                subscribers.append(subscriber)
        
        return subscribers
    
    def _parse_claims(self) -> List[Dict[str, Any]]:
        """Parse claim information (CLM segment and service lines)"""
        claims = []

        # Find all CLM segments
        for i, segment in enumerate(self.parser.segments):
            if segment[0] == 'CLM':
                claim = {
                    "claimId": segment[1] if len(segment) > 1 else None,
                    "totalChargeAmount": self._safe_float(segment[2]) if len(segment) > 2 else 0.0
                }
                
                # Parse claim-level information
                if len(segment) > 5:
                    claim_info = segment[5].split(':')
                    claim["placeOfService"] = claim_info[0] if len(claim_info) > 0 else None
                    claim["claimFrequency"] = claim_info[2] if len(claim_info) > 2 else None
                
                if len(segment) > 6:
                    claim["providerSignature"] = segment[6]
                if len(segment) > 7:
                    claim["assignmentOfBenefits"] = segment[7]
                if len(segment) > 8:
                    claim["releaseOfInformation"] = segment[8]
                if len(segment) > 9:
                    claim["patientSignature"] = segment[9]
                
                # Look for related segments
                for j in range(i + 1, min(i + MAX_CLAIM_SEGMENTS, len(self.parser.segments))):
                    seg = self.parser.segments[j]
                    
                    if seg[0] == 'CLM' or seg[0] == 'SE':  # Stop at next claim or transaction end
                        break
                    
                    if seg[0] == 'DTP':
                        if "dates" not in claim:
                            claim["dates"] = {}
                        
                        if len(seg) > 1 and seg[1] == '431':
                            claim["dates"]["admissionDate"] = self._format_date(seg[3]) if len(seg) > 3 else None
                        elif len(seg) > 1 and seg[1] == '434':
                            date_range = seg[3].split('-') if len(seg) > 3 else []
                            if len(date_range) == 2:
                                claim["dates"]["admissionDate"] = self._format_date(date_range[0])
                                claim["dates"]["dischargeDate"] = self._format_date(date_range[1])
                    
                    elif seg[0] == 'CL1':
                        claim["admissionType"] = seg[1] if len(seg) > 1 else None
                        claim["admissionSource"] = seg[2] if len(seg) > 2 else None
                        claim["patientStatus"] = seg[3] if len(seg) > 3 else None
                    
                    elif seg[0] == 'HI':
                        if "diagnoses" not in claim:
                            claim["diagnoses"] = {"additional": []}
                        
                        for k in range(1, len(seg)):
                            diag_parts = seg[k].split(':')
                            if len(diag_parts) >= 2:
                                diag = {
                                    "code": diag_parts[1],
                                    "codeType": diag_parts[0]
                                }
                                
                                if "principal" not in claim["diagnoses"]:
                                    claim["diagnoses"]["principal"] = diag
                                else:
                                    claim["diagnoses"]["additional"].append(diag)
                
                # Parse service lines (LX loop)
                claim["serviceLines"] = self._parse_service_lines(i)
                
                claims.append(claim)
        
        return claims
    
    def _parse_service_lines(self, claim_start_index: int) -> List[Dict[str, Any]]:
        """Parse service line information (LX/SV1 segments)"""
        service_lines = []
        
        for i in range(claim_start_index, min(claim_start_index + 50, len(self.parser.segments))):
            seg = self.parser.segments[i]
            
            if seg[0] == 'CLM' and i != claim_start_index:  # Stop at next claim
                break
            
            if seg[0] == 'LX':
                service_line = {
                    "lineNumber": int(seg[1]) if len(seg) > 1 else None
                }
                
                # Look for SV1 segment after LX
                for j in range(i + 1, min(i + 5, len(self.parser.segments))):
                    sv_seg = self.parser.segments[j]
                    
                    if sv_seg[0] == 'LX':  # Stop at next line
                        break
                    
                    if sv_seg[0] == 'SV1':
                        if len(sv_seg) > 1:
                            proc_parts = sv_seg[1].split(':')
                            service_line["procedure"] = {
                                "code": proc_parts[1] if len(proc_parts) > 1 else None,
                                "codeType": proc_parts[0] if len(proc_parts) > 0 else None,
                                "description": self._get_procedure_description(proc_parts[1] if len(proc_parts) > 1 else None)
                            }
                        
                        service_line["chargeAmount"] = self._safe_float(sv_seg[2]) if len(sv_seg) > 2 else 0.0
                        service_line["unit"] = sv_seg[3] if len(sv_seg) > 3 else None
                        service_line["quantity"] = self._safe_float(sv_seg[4]) if len(sv_seg) > 4 else 0.0
                        service_line["placeOfService"] = sv_seg[6] if len(sv_seg) > 6 else None
                    
                    elif sv_seg[0] == 'DTP' and len(sv_seg) > 1 and sv_seg[1] == '472':
                        service_line["serviceDate"] = self._format_date(sv_seg[3]) if len(sv_seg) > 3 else None
                
                service_lines.append(service_line)
        
        return service_lines
    
    def _parse_control_totals(self) -> Dict[str, Any]:
        """Parse control totals (SE, GE, IEA segments)"""
        se = self.parser.get_segment('SE')
        ge = self.parser.get_segment('GE')
        iea = self.parser.get_segment('IEA')
        
        return {
            "transactionSegmentCount": int(se[1]) if se and len(se) > 1 else None,
            "functionalGroupCount": int(ge[1]) if ge and len(ge) > 1 else None,
            "interchangeControlNumber": iea[2] if iea and len(iea) > 2 else None
        }
    
    # Helper methods
    
    def _format_date(self, date_str: str) -> Optional[str]:
        """Convert YYYYMMDD to YYYY-MM-DD"""
        if not date_str or len(date_str) < 8:
            return None

        try:
            return f"{date_str[0:4]}-{date_str[4:6]}-{date_str[6:8]}"
        except (ValueError, IndexError, TypeError):
            return date_str
    
    def _format_time(self, time_str: str) -> Optional[str]:
        """Convert HHMM to HH:MM"""
        if not time_str or len(time_str) < 4:
            return None

        try:
            return f"{time_str[0:2]}:{time_str[2:4]}"
        except (ValueError, IndexError, TypeError):
            return time_str
    
    def _safe_float(self, value: str) -> float:
        """Safely convert string to float, returning 0.0 on error"""
        try:
            return float(value)
        except (ValueError, TypeError):
            return 0.0

    def _decode_payer_responsibility(self, code: str) -> str:
        """Decode payer responsibility code"""
        codes = {
            'P': 'Primary',
            'S': 'Secondary',
            'T': 'Tertiary'
        }
        return codes.get(code, code)
    
    def _get_procedure_description(self, code: str) -> str:
        """Get procedure description (simplified lookup)"""
        descriptions = {
            '99213': 'Office/outpatient visit, established patient',
            '80053': 'Comprehensive metabolic panel',
            '85025': 'Complete blood count'
        }
        return descriptions.get(code, '')


def main():
    """Main execution function"""
    if len(sys.argv) < 2:
        print("Usage: python3 x12_to_json_parser.py <input_file.x12> [output_file.json]")
        print("\nExample:")
        print("  python3 x12_to_json_parser.py sample_837p_claim.x12")
        print("  python3 x12_to_json_parser.py sample_837p_claim.x12 output.json")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Read X12 file
    try:
        with open(input_file, 'r') as f:
            x12_content = f.read()
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)
    
    # Parse X12
    parser = X12Parser(x12_content)
    parser.parse()
    
    # Convert to JSON
    converter = X12_837P_Converter(parser)
    result = converter.convert()
    
    # Output JSON
    json_output = json.dumps(result, indent=2)
    
    if output_file:
        try:
            with open(output_file, 'w') as f:
                f.write(json_output)
            print(f"Successfully converted {input_file} to {output_file}")
        except Exception as e:
            print(f"Error writing output file: {e}")
            sys.exit(1)
    else:
        print(json_output)


if __name__ == "__main__":
    main()