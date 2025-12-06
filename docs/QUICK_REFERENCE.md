# X12 Healthcare Transaction Types - Quick Reference

## Transaction Type Cheat Sheet

| Code | Name | Direction | Purpose | Key Use Cases |
|------|------|-----------|---------|---------------|
| 837P | Professional Claim | Provider → Payer | Bill for professional services | Office visits, procedures, consultations |
| 837I | Institutional Claim | Provider → Payer | Bill for institutional services | Hospital stays, ER visits, skilled nursing |
| 835 | Remittance Advice | Payer → Provider | Explain claim payments | Payment reconciliation, adjustments |
| 270 | Eligibility Inquiry | Provider → Payer | Check patient eligibility | Pre-service verification, benefits check |
| 271 | Eligibility Response | Payer → Provider | Return eligibility info | Coverage details, copays, deductibles |
| 276 | Status Inquiry | Provider → Payer | Check claim status | Track claim processing, identify delays |
| 277 | Status Response | Payer → Provider | Report claim status | Adjudication status, payment timeline |
| 278 | Authorization | Bidirectional | Request/respond prior auth | Pre-approve procedures, hospital stays |
| 999 | Acknowledgment | Receiver → Sender | Confirm receipt | Validate successful transmission |

## Critical Segments by Transaction Type

### 837P - Professional Claim
```
ISA - Interchange Control Header
GS  - Functional Group Header (HC)
ST  - Transaction Set Header (837)
BHT - Beginning of Hierarchical Transaction
HL  - Hierarchical Level (Billing Provider, Subscriber, Patient)
NM1 - Entity Name (Provider, Patient, Insurance)
CLM - Claim Information
HI  - Diagnosis Codes
SV1 - Professional Service Line
SE  - Transaction Set Trailer
GE  - Functional Group Trailer
IEA - Interchange Control Trailer
```

### 837I - Institutional Claim
```
ISA/GS/ST/BHT (same as 837P)
HL  - Hierarchical Level (Billing Provider, Subscriber, Patient)
CLM - Claim Information
CL1 - Claim Codes (Admission Type/Source)
HI  - Diagnosis Codes (multiple segments)
SV2 - Institutional Service Line
SE/GE/IEA (same as 837P)
```

### 835 - Payment/Remittance
```
ISA/GS/ST (Functional Group: HP)
BPR - Financial Information
TRN - Trace Number
LX  - Service Line Number
CLP - Claim Payment Information
SVC - Service Payment Information
CAS - Claim/Service Adjustment
SE/GE/IEA
```

### 270 - Eligibility Inquiry
```
ISA/GS/ST (Functional Group: HS)
BHT - Beginning of Hierarchical Transaction
HL  - Hierarchical Level (Information Source, Receiver, Subscriber)
NM1 - Entity Name
TRN - Trace Number
EQ  - Eligibility or Benefit Inquiry
SE/GE/IEA
```

### 271 - Eligibility Response
```
ISA/GS/ST (Functional Group: HB)
BHT - Beginning of Hierarchical Transaction
HL  - Hierarchical Level
TRN - Trace Number
NM1 - Entity Name
EB  - Eligibility or Benefit Information
DTP - Date or Time Period
SE/GE/IEA
```

### 276 - Claim Status Inquiry
```
ISA/GS/ST (Functional Group: HR)
BHT - Beginning of Hierarchical Transaction
HL  - Hierarchical Level
TRN - Trace Number
REF - Reference Information (Claim ID)
DTP - Service Date
SE/GE/IEA
```

### 277 - Claim Status Response
```
ISA/GS/ST (Functional Group: HN)
BHT - Beginning of Hierarchical Transaction
HL  - Hierarchical Level
TRN - Trace Number
STC - Status Information
REF - Reference Information
DTP - Date
SE/GE/IEA
```

### 278 - Authorization
```
ISA/GS/ST (Functional Group: HS)
BHT - Beginning of Hierarchical Transaction
HL  - Hierarchical Level
TRN - Trace Number
UM  - Utilization Management
HSD - Health Care Services Delivery
DTP - Service Date
SE/GE/IEA
```

### 999 - Acknowledgment
```
ISA/GS/ST (Functional Group: FA)
AK1 - Functional Group Response Header
AK2 - Transaction Set Response Header
AK5 - Transaction Set Response Trailer
AK9 - Functional Group Response Trailer
SE/GE/IEA
```

## Implementation Guide Quick Lookup

| Transaction | Implementation Guide | Version |
|-------------|---------------------|---------|
| 837P | 005010X222A1 | 5010 |
| 837I | 005010X223A2 | 5010 |
| 835 | 005010X221A1 | 5010 |
| 270/271 | 005010X279A1 | 5010 |
| 276/277 | 005010X212 | 5010 |
| 278 | 005010X217 | 5010 |
| 999 | 005010 | 5010 |

## Common Code Sets

### Entity Type Qualifier (NM108)
- `IL` - Insured/Subscriber
- `QC` - Patient
- `85` - Billing Provider
- `PR` - Payer
- `82` - Rendering Provider
- `77` - Attending Physician

### Service Place Codes (CLM05-1)
- `11` - Office
- `21` - Inpatient Hospital
- `22` - Outpatient Hospital
- `23` - Emergency Room
- `31` - Skilled Nursing Facility
- `81` - Independent Laboratory

### Claim Adjustment Group Codes (CAS01)
- `CO` - Contractual Obligation
- `CR` - Correction/Reversal
- `OA` - Other Adjustment
- `PI` - Payer Initiated Reduction
- `PR` - Patient Responsibility

### Claim Adjustment Reason Codes (CAS02)
- `1` - Deductible Amount
- `2` - Coinsurance Amount
- `3` - Copayment Amount
- `45` - Charge exceeds fee schedule/maximum allowable
- `97` - Payment adjusted because service was provided outside policy limits

### Eligibility or Benefit Service Type Codes (EB01)
- `30` - Health Benefit Plan Coverage
- `1` - Medical Care
- `2` - Surgical
- `3` - Consultation
- `4` - Diagnostic X-Ray
- `5` - Diagnostic Lab
- `6` - Radiation Therapy
- `7` - Anesthesia
- `8` - Surgical Assistance

### Claim Status Category Codes (STC01-1)
- `A1` - Acknowledgment/Forwarded/Received
- `A2` - Acknowledgment/Acceptance
- `A3` - Acknowledgment/Returned
- `A4` - Acknowledgment/Not Found
- `A5` - Acknowledgment/Split Claim

### Claim Status Codes (STC01-2)
- `20` - Accepted for Processing
- `21` - Missing Information
- `22` - Processed According to Contract Provisions
- `23` - Unable to Respond

## Typical Data Flow Scenarios

### Scenario 1: New Patient Visit
1. **270** - Check patient eligibility
2. **271** - Receive coverage confirmation
3. *[Patient receives service]*
4. **837P** - Submit professional claim
5. **999** - Receive acknowledgment
6. **277** - Check claim status (optional)
7. **835** - Receive payment

### Scenario 2: Hospital Admission
1. **278** - Request authorization for admission
2. **278** - Receive authorization approval
3. **270** - Verify current eligibility
4. **271** - Receive eligibility details
5. *[Patient admitted and treated]*
6. **837I** - Submit institutional claim
7. **999** - Receive acknowledgment
8. **835** - Receive payment

### Scenario 3: Claim Follow-up
1. **837P/I** - Original claim submitted
2. *[Waiting period]*
3. **276** - Request claim status
4. **277** - Receive status (e.g., "in process")
5. *[More waiting]*
6. **276** - Request status again
7. **277** - Receive status (e.g., "approved")
8. **835** - Receive payment

## Processing Priority

For production systems, process in this order:

1. **999** - Handle acknowledgments (immediate)
2. **271** - Update eligibility cache (high priority)
3. **277** - Update claim tracking (high priority)
4. **835** - Post payments (high priority)
5. **837P/I** - Submit new claims (normal priority)
6. **270** - Eligibility checks (normal priority)
7. **276** - Status inquiries (normal priority)
8. **278** - Authorization requests (normal priority)

## Validation Checklist

### All Transactions
- [ ] ISA segment exactly 106 characters
- [ ] Matching control numbers (ISA13=IEA02, GS06=GE02, ST02=SE02)
- [ ] Correct segment counts
- [ ] Valid delimiters
- [ ] Proper segment terminator

### 837 (Claims)
- [ ] Valid NPI numbers (10 digits)
- [ ] Valid diagnosis codes (ICD-10)
- [ ] Service dates within valid range
- [ ] Claim amount matches service line totals
- [ ] Required entities present (Billing Provider, Subscriber)

### 835 (Payment)
- [ ] Payment amount matches claim total
- [ ] Adjustments sum correctly
- [ ] Valid adjustment codes
- [ ] Claim references match submitted claims

### 270/271 (Eligibility)
- [ ] Valid member ID
- [ ] Date formats correct (CCYYMMDD)
- [ ] Service type codes valid
- [ ] Trace numbers present

### 276/277 (Status)
- [ ] Valid claim reference numbers
- [ ] Status codes valid
- [ ] Matching inquiry/response trace numbers

### 278 (Authorization)
- [ ] Valid service type codes
- [ ] Date ranges logical
- [ ] Authorization numbers present (responses)

## Error Handling

### Common Errors

| Error Type | Description | Resolution |
|------------|-------------|------------|
| Invalid segment ID | Unrecognized segment | Check implementation guide |
| Missing required segment | Required segment absent | Add missing segment |
| Invalid element value | Value not in code set | Use valid code from list |
| Control number mismatch | Envelope numbers don't match | Regenerate with correct numbers |
| Invalid date | Date format incorrect | Use CCYYMMDD format |
| Segment count error | Count doesn't match actual | Recount and update |

## Testing Commands

```bash
# Detect transaction type
python x12_transaction_detector.py sample_837p_claim.x12

# Validate 837P
python x12_validator.py sample_837p_claim.x12

# Batch detect all files
for f in sample_*.x12; do 
    python x12_transaction_detector.py "$f" | grep "Type:"
done

# Check for syntax errors with jq (if converted to JSON)
jq empty output.json && echo "Valid JSON" || echo "Invalid JSON"
```

## Python Code Snippets

### Detect Transaction Type
```python
from x12_transaction_detector import X12TransactionDetector

detector = X12TransactionDetector()
result = detector.detect_file("file.x12")
print(f"Type: {result.transaction_type.value}")
print(f"Valid: {result.is_valid}")
```

### Route by Transaction Type
```python
from x12_transaction_detector import TransactionType

def route_transaction(file_path):
    detector = X12TransactionDetector()
    result = detector.detect_file(file_path)
    
    handlers = {
        TransactionType.T837P: handle_professional_claim,
        TransactionType.T835: handle_payment,
        TransactionType.T270: handle_eligibility_inquiry,
    }
    
    if result.is_valid:
        handler = handlers.get(result.transaction_type)
        if handler:
            return handler(file_path)
    
    return handle_unknown(file_path, result)
```

## Elixir Code Snippets

### Pattern Match on Transaction Type
```elixir
defmodule X12.Router do
  def process(file_path) do
    case detect_type(file_path) do
      {:ok, "837P", details} -> 
        X12.Claims.Professional.process(file_path, details)
      {:ok, "835", details} -> 
        X12.Payments.process(file_path, details)
      {:ok, "270", details} -> 
        X12.Eligibility.Inquiry.process(file_path, details)
      {:error, reason} -> 
        {:error, reason}
    end
  end
end
```

### Transaction Type GenServer
```elixir
defmodule X12.TransactionRouter do
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def route(file_path) do
    GenServer.call(__MODULE__, {:route, file_path})
  end
  
  def handle_call({:route, file_path}, _from, state) do
    result = detect_and_route(file_path)
    {:reply, result, state}
  end
  
  defp detect_and_route(file_path) do
    # Implementation
  end
end
```

## Useful Resources

- **X12.org** - Official X12 standards organization
- **CMS.gov** - Medicare transaction standards
- **WEDI** - Workgroup for Electronic Data Interchange
- **CAQH CORE** - Industry operating rules
- **WPC EDI Guides** - Implementation guide reference

---

**Version**: 2.0
**Last Updated**: December 5, 2024
